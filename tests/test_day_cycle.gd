extends SceneTree
## Headless check: day/night cycle. Fast-forward time and assert the sun's
## elevation/energy at noon vs midnight, ambient tint, day length, and that
## the bioluminescent flora actually brighten after dark.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var dc: Node = main.get_node("DayCycle")
	dc.set("time_of_day", 0.25)
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")

	# Glow targets: flora/fauna tagged by day_cycle._ready. Read the authored
	# emission it recorded, so we can prove the night boost scales that value
	# rather than flattening every species to one brightness.
	var glow_nodes := get_nodes_in_group("glow_plants")
	var glow_mesh: MeshInstance3D = glow_nodes[0] if not glow_nodes.is_empty() else null
	var glow_mat: StandardMaterial3D = null
	var glow_base := -1.0
	if glow_mesh != null:
		glow_mat = glow_mesh.material_override as StandardMaterial3D
		glow_base = float(glow_mesh.get_meta("glow_base_energy", -1.0))

	# Noon (time 0.25).
	dc.set_physics_process(false); dc.call("_process", 0.0)
	await process_frame
	var noon_elev: float = rad_to_deg(sun.rotation.x)
	var noon_energy: float = sun.light_energy
	# rotation.x = 90 - elevation, so noon x should be small (~13 deg).
	var noon_high: bool = noon_elev < 20.0 and noon_energy > 1.0
	var noon_glow: float = glow_mat.emission_energy_multiplier if glow_mat else -1.0

	# Midnight (time 0.75).
	dc.set("time_of_day", 0.75)
	dc.set_physics_process(false); dc.call("_process", 0.0)
	await process_frame
	var mid_energy: float = sun.light_energy
	var mid_dark: bool = mid_energy < 0.05
	var night_glow: float = glow_mat.emission_energy_multiplier if glow_mat else -1.0

	# Regression: the glow used to be a silent no-op — it called
	# set_instance_shader_parameter, which only reaches ShaderMaterials and
	# this project has none. It must now actually raise emission after dark,
	# while noon still matches the authored brightness exactly.
	var glow_ok: bool = glow_mesh != null and glow_mat != null \
			and glow_base > 0.0 \
			and absf(noon_glow - glow_base) < 0.001 \
			and night_glow > noon_glow + 0.001

	# Sky/ambient shift.
	var mid_ambient: float = main.get_node("WorldEnvironment") \
			.environment.ambient_light_energy
	var ambient_shifts: bool = mid_ambient < 0.5

	# Day length is Minecraft's: 20 min total.
	var ok_day_len: bool = is_equal_approx(dc.get("DAY_LENGTH"), 1200.0)

	print("RESULT noon_elev=%.0f noon_energy=%.2f mid_energy=%.2f ambient=%.2f day_len=%s glow_n=%d base=%.3f noon_glow=%.3f night_glow=%.3f glow_ok=%s"
			% [noon_elev, noon_energy, mid_energy, mid_ambient, ok_day_len,
			glow_nodes.size(), glow_base, noon_glow, night_glow, glow_ok])
	quit(0 if (noon_high and mid_dark and ambient_shifts and ok_day_len and glow_ok) else 1)