extends SceneTree
## Terrain builder — bakes scenes/terrain.tscn and scenes/water.tscn from the
## island.gd height field (WORLD_SPEC.md worker: Terrain).
## Run: cd project && snap run godot-4 --headless --script res://tools/build_terrain.gd

const STEP := 2.5
const MARGIN := 15.0
const X_MIN := -210.0
const X_MAX := 410.0
const Z_MIN := -150.0
const Z_MAX := 760.0

const COL_SAND := Color(0.76, 0.7, 0.5)
const COL_GRASS := Color(0.3, 0.45, 0.22)
const COL_WET := Color(0.25, 0.38, 0.28)
const COL_ROCK := Color(0.45, 0.44, 0.42)
const COL_CAP := Color(0.72, 0.74, 0.78)


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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	# Procedural detail texture: vertex colors multiply with a noise-ish albedo
	# so the ground isn't a flat blob of color up close. Triplanar, so no UVs
	# are needed and the texture tiles in world space.
	var tex := _make_detail_texture()
	mat.albedo_texture = tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.08, 0.08, 0.08)   # tile every ~12.5 world units
	mi.material_override = mat
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


func _make_detail_texture() -> ImageTexture:
	## 128x128 grayscale mottle, tileable, generated with value noise so the
	## ground has up-close texture without any external asset files.
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Deterministic RNG so the texture is identical on every rebuild.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# Random value grid at 3 octaves, bilinear-sampled and summed.
	var grids: Array = []
	for oct in [4, 8, 16]:
		var g: Array = []
		for i in (oct + 1) * (oct + 1):
			g.append(rng.randf())
		grids.append([oct, g])
	for py in size:
		for px in size:
			var v := 0.0
			for gi in grids.size():
				var oct: int = grids[gi][0]
				var g: Array = grids[gi][1]
				var fx := float(px) / size * oct
				var fy := float(py) / size * oct
				var x0 := int(fx)
				var y0 := int(fy)
				var tx := fx - x0
				var ty := fy - y0
				# Smooth (smoothstep) bilinear for softer blobs.
				var sx := tx * tx * (3.0 - 2.0 * tx)
				var sy := ty * ty * (3.0 - 2.0 * ty)
				var a: float = g[y0 * (oct + 1) + x0]
				var b: float = g[y0 * (oct + 1) + x0 + 1]
				var c: float = g[(y0 + 1) * (oct + 1) + x0]
				var d: float = g[(y0 + 1) * (oct + 1) + x0 + 1]
				var val := lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)
				v += val * [1.0, 0.5, 0.25][gi]
			# Normalize 0..1.75 to ~0.75..1.25 grayscale (subtle mottle).
			var g8 := int(clampf(0.75 + v / 1.75 * 0.5, 0.0, 1.0) * 255.0)
			img.set_pixel(px, py, Color8(g8, g8, g8))
	return ImageTexture.create_from_image(img)


func _color_for(x: float, z: float, h: float, island: GDScript) -> Color:
	var c: Color
	if h < island.WATER_LEVEL + 0.6:
		c = COL_SAND
	else:
		c = COL_GRASS
		# Wetlands bog tint around the Kushiro analog.
		var dw := Vector2(x, z).distance_to(Vector2(75.0, 5.0))
		if dw < 28.0:
			var t := 1.0 - clampf((dw - 16.0) / 12.0, 0.0, 1.0)
			c = c.lerp(COL_WET, t)
		# Highland rock, then frost cap.
		if h > 6.5:
			c = c.lerp(COL_ROCK, clampf((h - 6.5) / 3.0, 0.0, 1.0))
		if h > 9.5:
			c = c.lerp(COL_CAP, clampf((h - 9.5) / 2.0, 0.0, 1.0))
	# Subtle per-vertex variation from the terrain noise itself.
	var n: float = island.height_at(x + 31.7, z - 17.3) - island.height_at(x, z)
	c = c.lightened(clampf(n * 0.02, -0.04, 0.04))
	return c


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
