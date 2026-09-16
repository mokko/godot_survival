extends SceneTree
## Headless check: the baked terrain keeps its ground detail maps — a seamless
## mipmapped albedo, a normal map, a roughness map and a finer detail layer.
## Guards against a rebuild silently dropping them back to a flat grey mottle.

func _init() -> void:
	var fails: PackedStringArray = []
	var terrain = load("res://world/terrain.tscn").instantiate()
	root.add_child(terrain)
	var mi: MeshInstance3D = terrain.get_node("TerrainMesh")
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		fails.append("no_material")
	else:
		if not mat.vertex_color_use_as_albedo:
			fails.append("no_vertex_color")
		if mat.albedo_texture == null:
			fails.append("no_albedo")
		else:
			_check_tiles(mat.albedo_texture, fails)
		if not mat.normal_enabled or mat.normal_texture == null:
			fails.append("no_normal")
		if mat.roughness_texture == null:
			fails.append("no_roughness")
		if not mat.detail_enabled or mat.detail_albedo == null \
				or mat.detail_normal == null:
			fails.append("no_detail_layer")
		if mat.uv1_scale.x <= 0.0 or mat.uv2_scale.x <= 0.0:
			fails.append("no_scales")
		elif mat.uv2_scale.x <= mat.uv1_scale.x:
			fails.append("detail_not_finer")
	terrain.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _check_tiles(tex: Texture2D, fails: PackedStringArray) -> void:
	## Seam check: the step across the wrap-around column pair is compared with
	## the step between neighbouring interior columns. On a wrapped noise lattice
	## the boundary is just another neighbouring pair; a non-periodic lattice
	## jumps there — the previous map measured ~10x the interior step.
	var img: Image = tex.get_image()
	if not img.has_mipmaps():
		fails.append("albedo_mipmaps")
	var n := img.get_width()
	var boundary := 0.0
	for y in n:
		boundary += absf(img.get_pixel(0, y).r - img.get_pixel(n - 1, y).r)
	boundary /= float(n)
	var interior := 0.0
	for x in n - 1:
		for y in n:
			interior += absf(img.get_pixel(x, y).r - img.get_pixel(x + 1, y).r)
	interior /= float(n * (n - 1))
	if interior > 0.0 and boundary > interior * 4.0:
		fails.append("albedo_seam %.4f vs %.4f" % [boundary, interior])
