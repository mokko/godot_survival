extends StaticBody3D
## A moored boat: press E next to it to board, then steer with WASD and press E
## again to go ashore. One boat sits off the south coast of each island except the
## last one on the route, so the way onward is always "sail from here".
##
## Riding works by seat-lock, not by platform physics: while the player is aboard,
## the boat drives itself and pins the player to the deck every physics frame (the
## same trick movable_block uses to hold a block to the camera). Physics-based
## riding on a Compatibility renderer with Jolt jitters badly at 12 units/s.
##
## Going ashore is refused over deep water: the world has no collision below ~1.5
## under the sea surface, so stepping off mid-strait would drop the player into the
## void and trigger the fall-death. The boat asks Ezo.is_land() before letting go.
##
## Sailing is confined to navigable water (Ezo.is_navigable, i.e. HULL_DEPTH or
## deeper). The boat is a StaticBody3D moved by hand, so the terrain collider
## never pushes it back: with no depth test, aiming the bow at a beach and holding
## W sailed the vessel straight *through* the island (measured 48 m inland on Ezo,
## hull at y=0.05 under 2.77 m of hill, the pinned player 1.6 m under the surface
## — "the boat can get under the island").
##
## The whole vessel is one merged, vertex-coloured mesh — one draw call per boat,
## for the same reason the benchmark flags the multi-mesh flora.

## Set per placed instance by tools/build_boats.gd.
@export var island: String = ""
@export var destination: String = ""
@export var destination_xz: Vector2 = Vector2.ZERO

const SPEED := 12.0            # faster than the player's 10 sprint: sailing should feel like progress
const REVERSE_SPEED := 4.0
const TURN_RATE := 1.1         # radians per second
const BOARD_RADIUS := 5.0      # metres from the hull the player can press E in
const ASHORE_RANGE := 7.0      # metres of search for land when leaving the boat
const BOW_PROBE := 2.2         # metres ahead of the hull centre the depth is tested
const BOB_HEIGHT := 0.06
const BOB_PERIOD := 3.2
const RIDE_HEIGHT := 1.15      # deck height the player is pinned to

const HULL := Color(0.46, 0.31, 0.19)
const DECK := Color(0.62, 0.47, 0.30)
const MAST := Color(0.30, 0.21, 0.12)
const SAIL := Color(0.90, 0.88, 0.80)
const LANTERN := Color(1.0, 0.72, 0.35)

var _driver: CharacterBody3D
var _time := 0.0
var _hint: Label
var _hint_timer := 0.0
var _hull_mesh: MeshInstance3D
var _lantern: MeshInstance3D
var _mooring := Vector3.INF


func _ready() -> void:
	_mooring = global_position
	add_to_group("boat")     # tests and the HUD find boats through this
	_build_visuals()
	_build_collision()
	_hint = _make_hint_label()


func mooring() -> Vector3:
	## Where tools/build_boats.gd moored this boat. Kept so a test can put it back,
	## and so the spot to return to is knowable later (quests, "sail home").
	return _mooring


func _physics_process(delta: float) -> void:
	_time += delta
	position.y = Ezo.WATER_LEVEL + BOB_HEIGHT * sin(_time * TAU / BOB_PERIOD)
	if _driver == null:
		# Parked: keep the deck level so the moored boat does not look broken.
		rotation.x = move_toward(rotation.x, 0.0, delta)
		rotation.z = move_toward(rotation.z, 0.0, delta)
		_tick_hint(delta)
		return
	var throttle := Input.get_action_strength("move_forward") \
			- Input.get_action_strength("move_back")
	var steer := Input.get_action_strength("move_left") \
			- Input.get_action_strength("move_right")
	rotate_y(steer * TURN_RATE * delta)
	var speed := SPEED if throttle > 0.0 else REVERSE_SPEED
	var forward := -global_transform.basis.z
	_sail(forward * throttle * speed * delta)
	# Lean into the turn and pitch with the throttle: cheap, sells motion.
	rotation.z = move_toward(rotation.z, -steer * 0.12, delta * 0.6)
	rotation.x = move_toward(rotation.x, throttle * 0.04, delta * 0.5)
	_seat_driver()
	_tick_hint(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return   # inventory or menu is up: E belongs to the UI
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _driver == null:
		if player.global_position.distance_to(global_position) <= BOARD_RADIUS:
			_board(player)
			get_viewport().set_input_as_handled()
	elif _driver == player:
		if not _go_ashore():
			_say("No land close enough to step off — sail nearer a shore")
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------- sailing

func _sail(step: Vector3) -> void:
	## Move the hull, but only through water deep enough to float it. The boat is a
	## StaticBody3D driven by hand, so the terrain never pushes it back — without
	## this test the bow can be aimed at a beach and W sails the whole vessel
	## through the island, standing the player under its hills.
	if step.length_squared() < 0.000001:
		return
	if _floats_at(global_position + step):
		global_position += step
		return
	# Shallow ahead: slide along the shore rather than dead-stopping, so a coast
	# glanced at an angle does not bring the boat to a halt, and W against a beach
	# still feels like a refusal instead of a freeze.
	var along_x := Vector3(step.x, 0.0, 0.0)
	if absf(step.x) > 0.000001 and _floats_at(global_position + along_x):
		global_position += along_x
		return
	var along_z := Vector3(0.0, 0.0, step.z)
	if absf(step.z) > 0.000001 and _floats_at(global_position + along_z):
		global_position += along_z
		return
	# Nowhere to go: say so, so a hull held against a beach reads as a refusal
	# rather than as a broken throttle.
	_say("Too shallow ahead — the shore is in the way")


func _floats_at(p: Vector3) -> bool:
	## Is there water to float the hull *here* — at the hull centre and at the bow
	## ahead of it? The centre is tested first because it is the cheap rejection
	## (height_at walks the island outlines and costs ~93 us a call, so a hull held
	## against a shore spends ~0.5 ms a frame on this, nothing beside a frame).
	var fwd := _forward_xz()
	if not Ezo.is_navigable(p.x, p.z):
		return false
	return Ezo.is_navigable(p.x + fwd.x * BOW_PROBE, p.z + fwd.z * BOW_PROBE)


func _forward_xz() -> Vector3:
	## The bow direction on the water plane: the hull pitches with the throttle and
	## rolls into turns, and a tilted forward would dip the bow probe underwater or
	## lift it over the beach.
	var f := -global_transform.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


# ------------------------------------------------------------------ boarding

func board_for_test(player: CharacterBody3D) -> void:
	## Test seam: the same path E takes, without synthesising input events.
	_board(player)


func is_driven() -> bool:
	return _driver != null


func driver() -> CharacterBody3D:
	return _driver


func _board(player: CharacterBody3D) -> void:
	_driver = player
	if player.has_method("board_boat"):
		player.board_boat(self)
	_seat_driver()
	_say("Aboard — W/S sail, A/D steer, E to go ashore")


func _seat_driver() -> void:
	if _driver == null:
		return
	_driver.global_position = global_position + Vector3(0.0, RIDE_HEIGHT, 0.0)
	_driver.velocity = Vector3.ZERO


func _go_ashore() -> bool:
	## Put the player on the nearest land and hand control back.
	var spot := _nearest_land()
	if spot == Vector3.INF:
		return false
	_driver.global_position = spot
	if _driver.has_method("leave_boat"):
		_driver.leave_boat()
	_driver = null
	_say("Ashore")
	return true


func _nearest_land() -> Vector3:
	## The search lives in island.gd (the single source of truth for placement
	## math) because load_state() needs the same thing for a save written at sea.
	return Ezo.nearest_land_point(Vector2(global_position.x, global_position.z),
			ASHORE_RANGE)


# ------------------------------------------------------------------- visuals

func _build_visuals() -> void:
	## Hull, deck, mast, sail, tiller and a stern lantern, merged into one surface
	## with per-part vertex colours (one draw call, and no material juggling).
	var hull := BoxMesh.new()
	hull.size = Vector3(1.5, 0.55, 3.4)
	var bow := BoxMesh.new()
	bow.size = Vector3(1.3, 0.45, 1.2)
	var deck := BoxMesh.new()
	deck.size = Vector3(1.2, 0.12, 3.0)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.05
	mast.bottom_radius = 0.07
	mast.height = 2.2
	mast.radial_segments = 6
	var boom := BoxMesh.new()
	boom.size = Vector3(1.05, 0.06, 0.06)
	var sail := BoxMesh.new()
	sail.size = Vector3(1.0, 1.15, 0.04)
	var tiller := BoxMesh.new()
	tiller.size = Vector3(0.08, 0.08, 0.7)
	var parts := [
		[hull, Transform3D(Basis(), Vector3(0, -0.15, 0)), HULL],
		[bow, Transform3D(Basis(), Vector3(0, -0.22, -2.05)), HULL],
		[deck, Transform3D(Basis(), Vector3(0, 0.14, 0)), DECK],
		[mast, Transform3D(Basis(), Vector3(0, 1.2, 0.4)), MAST],
		[boom, Transform3D(Basis(), Vector3(0, 0.6, 0.3)), MAST],
		[sail, Transform3D(Basis(), Vector3(0, 1.15, 0.5)), SAIL],
		[tiller, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.35, 1.5)), MAST],
	]
	_hull_mesh = MeshInstance3D.new()
	_hull_mesh.name = "Hull"
	_hull_mesh.mesh = _merged(parts)
	_hull_mesh.material_override = _paint()
	add_child(_hull_mesh)
	# A lit lantern at the bow, so a moored boat is findable from the water after
	# dark. Deliberately NOT in the "glow_plants" group: that group's contract is
	# "authored emission that the day cycle scales", and it is queried by index in
	# tests. A lamp is simply lit.
	_lantern = MeshInstance3D.new()
	_lantern.name = "Lantern"
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.16, 0.2, 0.16)
	_lantern.mesh = lamp
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = LANTERN
	lamp_mat.emission_enabled = true
	lamp_mat.emission = LANTERN
	lamp_mat.emission_energy_multiplier = 2.5
	_lantern.material_override = lamp_mat
	_lantern.position = Vector3(0, 0.75, -2.1)
	add_child(_lantern)


func _merged(parts: Array) -> Mesh:
	## parts: [[Mesh, Transform3D, Color], ...] -> one surface with vertex colours.
	##
	## Built vertex by vertex rather than with SurfaceTool.append_from(): append_from
	## copies the *source* mesh's own arrays and ignores a colour set with set_color(),
	## which left the whole boat with no vertex colours — and, with
	## vertex_color_use_as_albedo, a black boat. So each part's arrays are read out,
	## transformed and re-emitted with the part's colour (plus normals: a surface
	## with no NORMAL array renders black for the same reason).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var src: Mesh = part[0]
		var xform: Transform3D = part[1]
		var colour: Color = part[2]
		var arrays := src.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if indices.size() > 0 else verts.size()
		st.set_color(colour)
		for i in count:
			var vi: int = indices[i] if indices.size() > 0 else i
			st.set_normal(xform.basis * normals[vi])
			if uvs.size() > vi:
				st.set_uv(uvs[vi])
			st.add_vertex(xform * verts[vi])
	return st.commit()


func _paint() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	return m


func _build_collision() -> void:
	## A solid hull so the moored boat cannot be walked through. While driving, the
	## player is seat-locked instead of standing on it, so the moving collider is
	## never asked to carry anyone.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.9, 3.6)
	shape.shape = box
	shape.position = Vector3(0, 0.1, 0)
	add_child(shape)


# --------------------------------------------------------------------- hints

func _make_hint_label() -> Label:
	var scene := get_tree().current_scene
	var hud: CanvasLayer = scene.get_node_or_null("HUD") if scene != null else null
	if hud == null:
		return null
	var label := Label.new()
	label.name = "BoatHint"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-190, -70)
	label.custom_minimum_size = Vector2(380, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.visible = false
	hud.add_child(label)
	return label


func _say(text: String, seconds := 4.0) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = true
	_hint_timer = seconds


func _tick_hint(delta: float) -> void:
	if _hint == null:
		return
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint.visible = false
		return
	# Idle prompt, so the player knows the boat can be boarded at all.
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _driver != null:
		return
	if player.global_position.distance_to(global_position) <= BOARD_RADIUS:
		_hint.text = "E — board the boat for %s" % destination
		_hint.visible = true
	else:
		_hint.visible = false
