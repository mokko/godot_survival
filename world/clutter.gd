extends Node3D
## Ground clutter — pebbles, twigs and grass tufts scattered on a grid that
## follows the player.
##
## Why this is not a baked scatter like the flora: the island is ~57 km² of grid,
## so a bake dense enough to read at walking distance would be tens of thousands
## of instances, which is not a good trade on the Mali GPU. Instead a
## fixed-capacity MultiMesh window is refilled around the player each time they
## move REFILL_STEP, holding a few hundred instances in three draw calls.
##
## Two things keep the refill off the frame budget:
##  * A per-cell cache. A cell's terrain height and its placement never change,
##    so each cell is sampled once per session and then reused as the window
##    slides over it. Ezo.height_at() is not cheap (it walks the island outlines
##    in GDScript — around 90 µs a call, measured), so this is the difference
##    between a ~220 ms stall every few metres and a fraction of a millisecond.
##  * Capped work per frame. New cells are cached under a per-frame time budget
##    (CACHE_BUDGET_US); the plan is written only once the window is complete.
##
## Every item is decided by a hash of its own world cell (no RNG state), so an
## item sits exactly where it was as the window slides — nothing pops, shuffles
## or re-randomises under the player's feet — and items scale in over FADE_BAND
## at the window edge instead of appearing at full size.
##
## Decoration only: no collision (walk-through, matching the passable ground
## cover rule) and no shadow casting — SSAO already darkens the contact patch,
## and a 10 cm object is not worth shadow-map cost.

const CELL := 2.0          # metres between scatter cells
const RADIUS := 22.0       # refill window radius around the player
const REFILL_STEP := 8.0   # refill once the player has moved this far
const FADE_BAND := 7.0     # metres at the window edge over which items scale in
const CACHE_BUDGET_US := 2000   # per-frame cap while sampling new cells
const SHORE_BAND := 1.2    # height above sea level that reads as beach
const ROCK_HEIGHT := 6.0   # above this only stone, no plants
## Matches Ezo.is_land()'s threshold on purpose: clutter must land exactly where
## the world calls terra firma, or items end up in the surf line.
const DRY_LAND := 0.25

## Per-layer capacity. A window holds (RADIUS/CELL * 2 + 1)² = 529 cells, of
## which ~π/4 are inside the circle and ~84% of those hold an item, so these
## leave comfortable headroom; visible_instance_count draws only what was filled.
const CAPACITY := [220, 150, 220]
## Cumulative hash cuts per cell: pebble, pebble|twig, pebble|twig|tuft, and
## above that an empty cell (deliberate gaps in the scatter).
const CUT_PEBBLE := 0.34
const CUT_TWIG := 0.50
const CUT_TUFT := 0.84

const TINT_SAND := Color(0.8, 0.74, 0.6)
const TINT_ROCK := Color(0.52, 0.51, 0.49)
const TINT_WOOD := Color(0.44, 0.34, 0.22)
const TINT_GRASS := Color(0.34, 0.48, 0.22)
const TINT_MOSS := Color(0.44, 0.54, 0.3)

const PEBBLE := 0
const TWIG := 1
const TUFT := 2

var _layers: Array[MultiMeshInstance3D] = []
var _player: Node3D
var _centre := Vector2(INF, INF)
## Vector2i(cell_x, cell_z) -> {x, z, h, layer, yaw, lean, size, tint}.
## Content depends only on the cell, never on the window, so it stays valid as
## the window slides and the refill is deterministic.
var _cache: Dictionary = {}
var _pending: Array[Vector2i] = []
var _dirty := false
var _window_ready := true
var _reports := 0


func _ready() -> void:
	_layers = [
		_add_layer("Pebbles", _pebble_mesh(), CAPACITY[PEBBLE]),
		_add_layer("Twigs", _twig_mesh(), CAPACITY[TWIG]),
		_add_layer("Tufts", _tuft_mesh(), CAPACITY[TUFT]),
	]
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("clutter: no node in group 'player' — clutter stays empty")


func _process(_delta: float) -> void:
	if _player == null:
		return
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	if _centre.x == INF or p.distance_to(_centre) >= REFILL_STEP:
		_begin_window(p)
	if not _pending.is_empty():
		# Sample new cells within this frame's budget; items at the window edge
		# are scaled in by the fade, so a staggered window build is invisible.
		var t0 := Time.get_ticks_usec()
		while not _pending.is_empty() \
				and Time.get_ticks_usec() - t0 < CACHE_BUDGET_US:
			_cache_cell(_pending.pop_back())
		_window_ready = _pending.is_empty()
	if _window_ready and _dirty:
		_refill_now()


func plan_fill(centre: Vector2) -> Dictionary:
	## Synchronous fill: completes the cache for this window and returns the
	## scatter as {transforms: [[..],[..],[..]], colours: [[..],[..],[..]]}.
	## _process() uses the budgeted path; the headless tests use this (under
	## --headless the dummy renderer keeps no instance buffers, so reading a
	## MultiMesh back returns nothing useful).
	_begin_window(centre)
	while not _pending.is_empty():
		_cache_cell(_pending.pop_back())
	return _refill_now()


# --- windowing ---------------------------------------------------------------

func _begin_window(centre: Vector2) -> void:
	## Queue every cell of the new window that is not cached yet, then drop the
	## cells the window has left. The extra ring gives _ground_up() neighbour
	## heights for the outermost placed cells.
	_centre = centre
	var cells := int(ceil(RADIUS / CELL))
	var cx0 := int(floor(centre.x / CELL))
	var cz0 := int(floor(centre.y / CELL))
	_pending.clear()
	for gz in range(-cells - 1, cells + 2):
		for gx in range(-cells - 1, cells + 2):
			var key := Vector2i(cx0 + gx, cz0 + gz)
			if not _cache.has(key):
				_pending.append(key)
	_prune(cx0, cz0, cells + 2)
	_dirty = true
	_window_ready = _pending.is_empty()


func _prune(cx0: int, cz0: int, keep: int) -> void:
	## Drop cached cells the window has left, so a long walk does not grow the
	## cache without bound.
	for key in _cache.keys():
		var k: Vector2i = key
		if absi(k.x - cx0) > keep or absi(k.y - cz0) > keep:
			_cache.erase(key)


func _cache_cell(key: Vector2i) -> void:
	## Everything about one cell that does not depend on the window centre: where
	## its item stands, how high the ground is, and what it is. One height_at().
	var x := (float(key.x) + 0.15 + 0.7 * _hash(key.x, key.y, 1)) * CELL
	var z := (float(key.y) + 0.15 + 0.7 * _hash(key.x, key.y, 2)) * CELL
	var h := Ezo.height_at(x, z)
	var entry := {
		"x": x, "z": z, "h": h, "layer": -1,
		"yaw": _hash(key.x, key.y, 4) * TAU,
		"lean": (_hash(key.x, key.y, 5) - 0.5) * 0.5,
		"size": lerpf(0.75, 1.3, _hash(key.x, key.y, 6)),
		"tint": Color.WHITE,
	}
	# Water and the surf line hold nothing.
	if h >= Ezo.WATER_LEVEL + DRY_LAND:
		var shore := h < Ezo.WATER_LEVEL + SHORE_BAND
		var rock := h > ROCK_HEIGHT
		var roll := _hash(key.x, key.y, 3)
		if roll < CUT_PEBBLE:
			entry["layer"] = PEBBLE
		elif roll < CUT_TWIG:
			entry["layer"] = TWIG
		elif roll < CUT_TUFT and not shore and not rock:
			# Plants only where they can hold: no tufts on beach sand or on bare
			# highland rock.
			entry["layer"] = TUFT
		if entry["layer"] != -1:
			entry["tint"] = _tint(entry["layer"], shore, rock, key.x, key.y)
	_cache[key] = entry


func _refill_now() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var plan := _plan(_centre)
	var t1 := Time.get_ticks_usec()
	for layer in 3:
		_write_layer(layer, plan["transforms"][layer], plan["colours"][layer])
	_dirty = false
	if _reports < 2:
		_reports += 1
		print("clutter: window at %s — %d pebbles, %d twigs, %d tufts; %d cells cached; plan %d us, write %d us"
				% [_centre, plan["transforms"][PEBBLE].size(),
				plan["transforms"][TWIG].size(), plan["transforms"][TUFT].size(),
				_cache.size(), t1 - t0, Time.get_ticks_usec() - t1])
	return plan


func _plan(centre: Vector2) -> Dictionary:
	## Turn the cached cells into instance transforms for this window. The only
	## per-refresh work is the edge fade, the ground tilt and the basis — no
	## terrain sampling, which is what made the first version stall.
	var transforms: Array = [[], [], []]
	var colours: Array = [[], [], []]
	for key in _cache:
		var e: Dictionary = _cache[key]
		if e["layer"] == -1:
			continue
		var p := Vector2(e["x"], e["z"])
		var d := p.distance_to(centre)
		if d > RADIUS:
			continue
		var layer: int = e["layer"]
		var fade := clampf((RADIUS - d) / FADE_BAND, 0.0, 1.0)
		var scale: float = e["size"] * fade
		var up := _ground_up(key)
		var basis := _basis(up, e["yaw"], e["lean"]) \
				.scaled(Vector3(scale, scale, scale))
		var sink: float = _sink(layer) * scale
		transforms[layer].append(Transform3D(basis, Vector3(e["x"], e["h"] - sink, e["z"])))
		colours[layer].append(e["tint"])
	return {"transforms": transforms, "colours": colours}


func _write_layer(layer: int, transforms: Array, colours: Array) -> void:
	var mm: MultiMesh = _layers[layer].multimesh
	var n := transforms.size()
	mm.visible_instance_count = n
	for i in n:
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colours[i])


# --- layers ------------------------------------------------------------------

func _add_layer(layer_name: String, mesh: Mesh, capacity: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = layer_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true      # per-instance tint, so neighbours never match
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	node.multimesh = mm
	node.material_override = _clutter_material()
	# Keep the frustum culling box over the whole island: instances carry world
	# positions, and a box that followed the window would cull wrongly while the
	# transforms are being rewritten.
	node.custom_aabb = AABB(
			Vector3(Ezo.GRID_MIN.x, -6.0, Ezo.GRID_MIN.y),
			Vector3(Ezo.GRID_MAX.x - Ezo.GRID_MIN.x, 24.0,
			Ezo.GRID_MAX.y - Ezo.GRID_MIN.y))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _clutter_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true   # instance colour is the albedo
	m.roughness = 0.95
	m.metallic = 0.0
	return m


func _pebble_mesh() -> Mesh:
	## A squashed five-sided ball reads as a small stone from any angle.
	var m := SphereMesh.new()
	m.radial_segments = 5
	m.rings = 3
	m.radius = 0.11
	m.height = 0.09
	return m


func _twig_mesh() -> Mesh:
	## A short tapered stick, laid on its side in mesh space so instances only
	## need a yaw (plus the ground tilt) rather than an extra spin.
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.024
	stick.height = 0.46
	stick.radial_segments = 4
	return _merge([[stick, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]])


func _tuft_mesh() -> Mesh:
	## Three thin blades leaning apart, merged into one mesh — 24 triangles.
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.018
	blade.height = 0.22
	blade.radial_segments = 4
	var parts: Array = []
	for i in 3:
		var yaw := TAU * float(i) / 3.0
		var lean := Transform3D(Basis(Vector3.BACK, 0.3), Vector3(0, 0.1, 0))
		parts.append([blade, Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * lean])
	return _merge(parts)


func _merge(parts: Array) -> Mesh:
	## parts: [[Mesh, Transform3D], ...] merged into a single surface. Normals
	## come from the source primitives (smooth cones, proper caps) — recomputing
	## them here would fan the collapsed cone tips.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		st.append_from(part[0], 0, part[1])
	return st.commit()


# --- per-item values ---------------------------------------------------------

func _sink(layer: int) -> float:
	## How far an item is pushed into the ground, so nothing floats: stones sit
	## slightly buried, a lying twig by its own radius, a tuft at its root.
	return [0.03, 0.012, 0.015][layer]


func _tint(layer: int, shore: bool, rock: bool, cx: int, cz: int) -> Color:
	var t := _hash(cx, cz, 7)
	var shade := 0.12 * (_hash(cx, cz, 8) - 0.5)
	if layer == PEBBLE:
		var base := TINT_SAND
		if rock:
			base = TINT_ROCK
		elif not shore:
			base = TINT_SAND.lerp(TINT_ROCK, t)
		return base.lightened(shade)
	if layer == TWIG:
		return TINT_WOOD.lightened(0.16 * (t - 0.5))
	return TINT_GRASS.lerp(TINT_MOSS, t).lightened(shade)


# --- placement maths ---------------------------------------------------------

func _ground_up(key: Vector2i) -> Vector3:
	## Terrain normal from the neighbouring cells' cached heights, so the tilt is
	## free of terrain sampling. Falls back to straight up at the window edge,
	## where a neighbour is not cached.
	var l := _neighbour_height(key.x - 1, key.y)
	var r := _neighbour_height(key.x + 1, key.y)
	var d := _neighbour_height(key.x, key.y - 1)
	var u := _neighbour_height(key.x, key.y + 1)
	if is_inf(l) or is_inf(r) or is_inf(d) or is_inf(u):
		return Vector3.UP
	# Central differences span two cells, hence 2 * CELL metres.
	return Vector3(-(r - l) / (2.0 * CELL), 1.0, -(u - d) / (2.0 * CELL)).normalized()


func _neighbour_height(cx: int, cz: int) -> float:
	var e: Variant = _cache.get(Vector2i(cx, cz), null)
	if e == null:
		return INF
	return e["h"]


func _basis(up: Vector3, yaw: float, lean: float) -> Basis:
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var r := up.cross(f)
	if r.length_squared() < 0.0001:
		r = Vector3.RIGHT
	r = r.normalized()
	f = r.cross(up).normalized()
	return Basis(r, up, f).rotated(f, lean)


func _hash(cx: int, cz: int, salt: int) -> float:
	## Deterministic 0..1 hash of a world cell — stable across refills and runs,
	## which is what keeps items from shuffling as the window slides.
	var v := sin(float(cx) * 127.1 + float(cz) * 311.7 + float(salt) * 74.7) * 43758.5453
	return v - floorf(v)
