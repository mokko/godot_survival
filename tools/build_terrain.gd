extends SceneTree
## Terrain builder — bakes world/terrain.tscn and world/water.tscn from the
## island.gd height field (WORLD_SPEC.md worker: Terrain).
## Run: cd project && snap run godot-4 --headless --script res://tools/build_terrain.gd

const STEP := 2.5
const X_MIN := -210.0
const X_MAX := 410.0
const Z_MIN := -150.0
const Z_MAX := 760.0

const COL_SAND := Color(0.76, 0.7, 0.5)
const COL_GRASS := Color(0.3, 0.45, 0.22)
const COL_WET := Color(0.25, 0.38, 0.28)
const COL_ROCK := Color(0.45, 0.44, 0.42)
const COL_CAP := Color(0.72, 0.74, 0.78)

# --- ground detail maps ------------------------------------------------------
# Two triplanar scales, both generated in code (art canon: no external assets).
# Macro (uv1) tiles once per 1 / UV1_SCALE = 2.5 world units, the micro detail
# layer (uv2) once per 1 / UV2_SCALE = 0.5 world units.
const UV1_SCALE := 0.4
const UV2_SCALE := 2.0
## BaseMaterial3D.detail_blend_mode has no named constant on this build (only
## the DetailUV enum is exposed as a constant), so this is the int from its
## hint order: Mix, Add, Subtract, Multiply.
const DETAIL_BLEND_MULTIPLY := 3
## Averaged bump tilt the generated normal map aims for, as a tangent-space
## slope (0.22 is about 12 degrees). The height differences are scaled to hit
## it, so the strength needs no retuning when the octave set changes.
const TARGET_MEAN_SLOPE := 0.22
## Albedo range per scale. Both maps are RGBA8, so 1.0 is the ceiling and they
## can only darken; the height field is stretched to its own min/max first,
## because mapping the raw field onto a wide range piles most of the map up
## against that ceiling (the first attempt left 58% of it clamped at pure white).
const MACRO_ALBEDO := [0.72, 1.0]
const MICRO_ALBEDO := [0.9, 1.0]
## Both albedo maps multiply the biome vertex colours, so the ground would come
## out ~18% darker than before they existed. This lifts the vertex colours to
## match the brightness of the single map they replace (its mean was 0.94).
const ALBEDO_COMPENSATION := 1.15
const OCTAVE_AMPLITUDES := [1.0, 0.5, 0.25]
const MACRO_OCTAVES := [8, 16, 32]
const MACRO_SEED := 1337
const MACRO_SIZE := 256
const MICRO_OCTAVES := [16, 32, 64]
const MICRO_SEED := 2024
const MICRO_SIZE := 128
## Shore band: the sand/grass change is blended over this much height instead of
## being thresholded, and the boundary height wobbles by SHORE_JITTER either way
## along a coherent ~24-unit field, so it reads as a curve and not a contour.
const SHORE_BAND := 0.4
const SHORE_JITTER := 0.35


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.open("res://").make_dir_recursive("scenes")
	var island := load("res://world/island.gd")
	_build_terrain(island)
	_build_water()
	print("build_terrain: done in %d ms" % (Time.get_ticks_msec() - t0))
	quit(0)


func _build_terrain(island: GDScript) -> void:
	var nx := int((X_MAX - X_MIN) / STEP) + 1
	var nz := int((Z_MAX - Z_MIN) / STEP) + 1
	print("grid: %d x %d = %d verts" % [nx, nz, nx * nz])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in nz - 1:
		for ix in nx - 1:
			var x0 := X_MIN + ix * STEP
			var z0 := Z_MIN + iz * STEP
			var x1 := x0 + STEP
			var z1 := z0 + STEP
			var h00: float = island.height_at(x0, z0)
			var h01: float = island.height_at(x0, z1)
			var h10: float = island.height_at(x1, z0)
			var h11: float = island.height_at(x1, z1)
			# Skip fully-underwater quads far offshore (keeps the mesh small);
			# near-shore quads stay so beaches render.
			if h00 < -1.5 and h01 < -1.5 and h10 < -1.5 and h11 < -1.5:
				continue
			# Two upward-facing triangles: Godot's front faces use CLOCKWISE
			# winding, so order the verts clockwise when viewed from above.
			_v(st, x0, h00, z0, island)
			_v(st, x1, h11, z1, island)
			_v(st, x0, h01, z1, island)
			_v(st, x0, h00, z0, island)
			_v(st, x1, h10, z0, island)
			_v(st, x1, h11, z1, island)

	st.generate_normals()
	var mesh := st.commit()

	var terrain_root := StaticBody3D.new()
	terrain_root.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	terrain_root.add_child(mi)
	mi.owner = terrain_root

	var shape := mesh.create_trimesh_shape()
	var cs := CollisionShape3D.new()
	cs.name = "TerrainCollision"
	cs.shape = shape
	terrain_root.add_child(cs)
	cs.owner = terrain_root

	var packed := PackedScene.new()
	var err := packed.pack(terrain_root)
	if err != OK:
		push_error("pack terrain failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://world/terrain.tscn")
	print("terrain.tscn saved: %s (faces ~%d)" % [err, mesh.get_faces().size() / 3])
	terrain_root.free()


func _v(st: SurfaceTool, x: float, h: float, z: float, island: GDScript) -> void:
	st.set_color(_color_for(x, z, h, island))
	st.add_vertex(Vector3(x, h, z))


func _terrain_material() -> StandardMaterial3D:
	## Vertex colours carry the biome; two code-generated triplanar scales carry
	## the texture. The micro scale rides in StandardMaterial3D's detail slot,
	## which is how close-up grain gets added here: Compatibility has no decal
	## support, and one UV scale cannot serve both a 2.5-unit and a half-metre
	## feature size.
	var macro := _make_detail_maps(
			MACRO_OCTAVES, MACRO_SEED, MACRO_SIZE, MACRO_ALBEDO)
	var micro := _make_detail_maps(
			MICRO_OCTAVES, MICRO_SEED, MICRO_SIZE, MICRO_ALBEDO)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.albedo_texture = macro[0]
	mat.normal_enabled = true
	mat.normal_texture = macro[1]
	mat.normal_scale = 0.6
	# The generated roughness map holds the same value in R, G and B, so
	# whichever channel the material samples gives the same answer.
	mat.roughness_texture = macro[2]
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(UV1_SCALE, UV1_SCALE, UV1_SCALE)
	mat.detail_enabled = true
	mat.detail_albedo = micro[0]
	mat.detail_normal = micro[1]
	mat.detail_blend_mode = DETAIL_BLEND_MULTIPLY
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.uv2_triplanar = true
	mat.uv2_scale = Vector3(UV2_SCALE, UV2_SCALE, UV2_SCALE)
	return mat


func _make_detail_maps(octaves: Array, seed_value: int, size: int,
		albedo_range: Array) -> Array:
	## [albedo, normal, roughness] textures generated from one tileable fractal
	## value-noise height field — no external asset files, per the art canon.
	##
	## Tileability: the lattice wraps (indices modulo each octave's grid size), so
	## the field is exactly periodic over one tile and the maps tile seamlessly —
	## the normal too, since it is differentiated with the same wrap. The previous
	## version used oct + 1 independent random rows and columns, which left a
	## brightness step at every tile edge: on the baked map that measured as a
	## mean step of 4.4/255 across the boundary against 0.45/255 between
	## neighbouring interior columns, i.e. a visible grid of seams.
	##
	## Mipmaps are generated so the ground settles with distance instead of
	## shimmering.
	var grids := _noise_grids(octaves, seed_value)
	var speck_grids := _noise_grids(octaves, seed_value + 7)
	var n := size
	var heights := PackedFloat32Array()
	var speck := PackedFloat32Array()
	heights.resize(n * n)
	speck.resize(n * n)
	var lo := INF
	var hi := -INF
	var speck_lo := INF
	var speck_hi := -INF
	for py in n:
		for px in n:
			var u := float(px) / float(n)
			var v := float(py) / float(n)
			var h := _noise(grids, u, v)
			var s := _noise(speck_grids, u, v)
			heights[py * n + px] = h
			speck[py * n + px] = s
			lo = minf(lo, h)
			hi = maxf(hi, h)
			speck_lo = minf(speck_lo, s)
			speck_hi = maxf(speck_hi, s)
	# The field fills only part of 0..1 and clusters around the middle, so stretch
	# both fields to their own range before mapping them onto anything.
	var span := maxf(hi - lo, 0.0001)
	var speck_span := maxf(speck_hi - speck_lo, 0.0001)
	# Derive the bump strength from the field rather than guessing it per octave
	# set: scale the central differences so the average tilt hits the target.
	var mean_slope := 0.0
	for i in n * n:
		mean_slope += absf(_slope_x(heights, n, i))
	mean_slope /= float(n * n)
	var strength := TARGET_MEAN_SLOPE / maxf(mean_slope, 0.0001)

	var albedo_lo: float = albedo_range[0]
	var albedo_hi: float = albedo_range[1]
	var albedo_img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var normal_img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rough_img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var albedo_sum := 0.0
	for py in n:
		for px in n:
			var i := py * n + px
			var hn := (heights[i] - lo) / span
			var sn := (speck[i] - speck_lo) / speck_span
			# Albedo: mottling across the full range the RGBA8 map can hold, plus
			# a warm/cool speck so the ground is not pure grey. That is ~28%
			# contrast where the old single map had 12% (224..255).
			var bright := albedo_lo + hn * (albedo_hi - albedo_lo)
			albedo_sum += bright
			var warm := sn - 0.5
			albedo_img.set_pixel(px, py, Color(
					clampf(bright * (1.0 + 0.10 * warm), 0.0, 1.0),
					clampf(bright * (1.0 + 0.02 * warm), 0.0, 1.0),
					clampf(bright * (1.0 - 0.08 * warm), 0.0, 1.0)))
			# Tangent-space normal from the same height field.
			var nrm := Vector3(-_slope_x(heights, n, i) * strength,
					-_slope_y(heights, n, i) * strength, 1.0).normalized()
			normal_img.set_pixel(px, py, Color(
					nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5))
			# Roughness: drier crests a touch rougher than sheltered hollows,
			# decorrelated from the height by the second field and spread wide
			# enough to read (0.66..1.0).
			var r := clampf(0.66 + 0.24 * hn + 0.10 * sn, 0.0, 1.0)
			rough_img.set_pixel(px, py, Color(r, r, r))
	albedo_img.generate_mipmaps()
	normal_img.generate_mipmaps()
	rough_img.generate_mipmaps()
	print("detail maps: %d px, albedo %.2f..%.2f (mean %.3f), normal strength %.1f"
			% [n, albedo_lo, albedo_hi, albedo_sum / float(n * n), strength])
	return [ImageTexture.create_from_image(albedo_img),
			ImageTexture.create_from_image(normal_img),
			ImageTexture.create_from_image(rough_img)]


func _noise_grids(octaves: Array, seed_value: int) -> Array:
	## One square lattice of random values per octave. Seeded, so every rebuild
	## bakes identical maps.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grids: Array = []
	for oct in octaves:
		var g := PackedFloat32Array()
		g.resize(oct * oct)
		for i in oct * oct:
			g[i] = rng.randf()
		grids.append(g)
	return grids


func _noise(grids: Array, u: float, v: float) -> float:
	## Fractal value noise over the octave lattices, normalised to 0..1. Periodic
	## in u and v: the lattice index wraps modulo each octave's grid size, so
	## sampling at u + 1.0 gives the same value as at u.
	u = fposmod(u, 1.0)
	v = fposmod(v, 1.0)
	var total := 0.0
	var norm := 0.0
	for gi in grids.size():
		var g: PackedFloat32Array = grids[gi]
		var oct := int(round(sqrt(float(g.size()))))
		var amp: float = OCTAVE_AMPLITUDES[gi]
		norm += amp
		var fx := u * oct
		var fy := v * oct
		var x0 := int(floorf(fx))
		var y0 := int(floorf(fy))
		var tx := fx - x0
		var ty := fy - y0
		# Smooth (smoothstep) bilinear for softer blobs.
		var sx := tx * tx * (3.0 - 2.0 * tx)
		var sy := ty * ty * (3.0 - 2.0 * ty)
		var xa := x0 % oct
		var ya := y0 % oct
		var xb := (x0 + 1) % oct
		var yb := (y0 + 1) % oct
		var a := g[ya * oct + xa]
		var b := g[ya * oct + xb]
		var c := g[yb * oct + xa]
		var d := g[yb * oct + xb]
		total += lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy) * amp
	return total / norm


func _slope_x(h: PackedFloat32Array, n: int, i: int) -> float:
	## Central difference across one texel, wrapped, so tile edges stay smooth.
	var x := i % n
	var y := i / n
	return h[y * n + (x + 1) % n] - h[y * n + (x + n - 1) % n]


func _slope_y(h: PackedFloat32Array, n: int, i: int) -> float:
	var x := i % n
	var y := i / n
	return h[((y + 1) % n) * n + x] - h[((y + n - 1) % n) * n + x]


func _color_for(x: float, z: float, h: float, island: GDScript) -> Color:
	## Biome colour for one terrain vertex. The shore is a jittered, blended band
	## rather than a height threshold: vertex colours are interpolated across each
	## quad, so a soft boundary stops the 2.5-unit vertex grid showing up as a
	## clean jagged polygon edge.
	var shore: float = island.WATER_LEVEL + 0.6 + _jitter(x, z) * SHORE_JITTER
	var sand := clampf((shore + SHORE_BAND * 0.5 - h) / SHORE_BAND, 0.0, 1.0)
	var land := 1.0 - sand
	var c := COL_GRASS.lerp(COL_SAND, sand)
	# Wetlands bog tint around the Kushiro analog.
	var dw := Vector2(x, z).distance_to(Vector2(75.0, 5.0))
	if dw < 28.0:
		var t := 1.0 - clampf((dw - 16.0) / 12.0, 0.0, 1.0)
		c = c.lerp(COL_WET, t * land)
	# Highland rock, then frost cap.
	if h > 6.5:
		c = c.lerp(COL_ROCK, clampf((h - 6.5) / 3.0, 0.0, 1.0) * land)
	if h > 9.5:
		c = c.lerp(COL_CAP, clampf((h - 9.5) / 2.0, 0.0, 1.0) * land)
	# Subtle per-vertex variation from the terrain noise itself.
	var n: float = island.height_at(x + 31.7, z - 17.3) - island.height_at(x, z)
	c = c.lightened(clampf(n * 0.02, -0.04, 0.04))
	# Both albedo detail maps multiply this colour and their means sit below 1,
	# so lift the vertex colours to keep the island as bright as it was when a
	# single map multiplied it (that map's mean was 0.94, these two give 0.82).
	return c * ALBEDO_COMPENSATION


func _jitter(x: float, z: float) -> float:
	## Coherent -1..1 pseudo-random field, smooth on a ~24 world-unit scale, used
	## to wobble the shoreline so it reads as a curve instead of a contour line.
	## Two hash taps per axis rather than a noise class, to keep the builder
	## self-contained and deterministic.
	var s := 24.0
	var fx := x / s
	var fz := z / s
	var x0 := floorf(fx)
	var z0 := floorf(fz)
	var tx := fx - x0
	var tz := fz - z0
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sz := tz * tz * (3.0 - 2.0 * tz)
	var a := _hash01(x0, z0)
	var b := _hash01(x0 + 1.0, z0)
	var c := _hash01(x0, z0 + 1.0)
	var d := _hash01(x0 + 1.0, z0 + 1.0)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sz) * 2.0 - 1.0


func _hash01(x: float, z: float) -> float:
	## Deterministic 0..1 hash — no RNG state, identical on every rebuild.
	var v := sin(x * 127.1 + z * 311.7) * 43758.5453
	return v - floorf(v)


func _build_water() -> void:
	var water := Node3D.new()
	water.name = "Water"

	var sea_mi := MeshInstance3D.new()
	sea_mi.name = "Sea"
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(1700.0, 1700.0)
	sea_mi.mesh = sea_mesh
	sea_mi.material_override = _water_mat(Color(0.1, 0.3, 0.45, 0.72))
	water.add_child(sea_mi)
	sea_mi.owner = water

	var lake_mi := MeshInstance3D.new()
	lake_mi.name = "CalderaLake"
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 14.0
	lake_mesh.bottom_radius = 14.0
	lake_mesh.height = 0.1
	lake_mi.mesh = lake_mesh
	lake_mi.material_override = _water_mat(Color(0.08, 0.28, 0.4, 0.8))
	lake_mi.position = Vector3(island_caldera_x(), island_lake_level(), island_caldera_z())
	water.add_child(lake_mi)
	lake_mi.owner = water

	var packed := PackedScene.new()
	var err := packed.pack(water)
	if err != OK:
		push_error("pack water failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://world/water.tscn")
	print("water.tscn saved: %s" % err)
	water.free()


func _water_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.roughness = 0.1
	m.metallic = 0.2
	return m


# island.gd constants are accessed through a tiny helper to keep _init clean.
func island_caldera_x() -> float:
	return load("res://world/island.gd").CALDERA_CENTER.x


func island_caldera_z() -> float:
	return load("res://world/island.gd").CALDERA_CENTER.y


func island_lake_level() -> float:
	return load("res://world/island.gd").LAKE_LEVEL
