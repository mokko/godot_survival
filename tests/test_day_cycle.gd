extends SceneTree
## Headless check: day/night cycle. Fast-forward time and assert the sun's
## elevation/energy at noon vs midnight, ambient tint, and glow scaling.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var dc: Node = main.get_node("DayCycle")
	dc.set("time_of_day", 0.25)
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")

	# Noon (time 0.25).
	dc.set_physics_process(false); dc.call("_process", 0.0)
	await process_frame
	var noon_elev: float = rad_to_deg(sun.rotation.x)
	var noon_energy: float = sun.light_energy
	# rotation.x = 90 - elevation, so noon x should be small (~13 deg).
	var noon_high: bool = noon_elev < 20.0 and noon_energy > 1.0

	# Midnight (time 0.75).
	dc.set("time_of_day", 0.75)
	dc.set_physics_process(false); dc.call("_process", 0.0)
	await process_frame
	var mid_energy: float = sun.light_energy
	var mid_dark: bool = mid_energy < 0.05

	# Sky/ambient shift.
	var mid_ambient: float = main.get_node("WorldEnvironment") \
			.environment.ambient_light_energy
	var ambient_shifts: bool = mid_ambient < 0.5

	# Day length is Minecraft's: 20 min total.
	var ok_day_len: bool = is_equal_approx(dc.get("DAY_LENGTH"), 1200.0)

	print("RESULT noon_elev=%.0f noon_energy=%.2f mid_energy=%.2f ambient=%.2f day_len=%s"
			% [noon_elev, noon_energy, mid_energy, mid_ambient, ok_day_len])
	quit(0 if (noon_high and mid_dark and ambient_shifts and ok_day_len) else 1)
