extends SceneTree
## Headless check: FPS counter — default on, updates, toggle via options
## persists, and splash options panel toggles the setting.

func _init() -> void:
	# Clean slate: no options file.
	DirAccess.open("user://").remove("options.json")
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var fps: Label = main.get_node("HUD/FPSLabel")
	var fails: PackedStringArray = []

	# 1. Default on and visible, shows a number after a second.
	if not fps.visible:
		fails.append("default_hidden")
	for i in 80:
		await physics_frame
	if not fps.text.begins_with("FPS: ") or fps.text.ends_with("--"):
		fails.append("no_value")

	# 2. Toggle off -> hidden, persisted to options file.
	var Options: GDScript = load("res://ui/options.gd")
	Options.set_option("show_fps", false)
	for i in 5:
		await process_frame
	if fps.visible:
		fails.append("toggle_off_visible")
	if not FileAccess.file_exists(Options.PATH):
		fails.append("not_saved")

	# 3. Fresh main scene picks up the stored off state.
	main.queue_free()
	await process_frame
	var main2 = load("res://world/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	for i in 10:
		await physics_frame
	var fps2: Label = main2.get_node("HUD/FPSLabel")
	if fps2.visible:
		fails.append("off_not_persisted")

	# 4. Splash options panel reflects and writes the setting.
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	var panel: PanelContainer = splash.get_node("OptionsPanel")
	var btn: CheckButton = splash.get_node("OptionsPanel/VBox/ShowFPS")
	splash._on_options_pressed()
	if not panel.visible or btn.button_pressed:
		fails.append("panel_state")   # panel must open, checkbox shows off
	btn.button_pressed = true
	splash._on_options_back_pressed()
	if panel.is_visible_in_tree() or not Options.get_option("show_fps"):
		fails.append("panel_write")
	splash.queue_free()

	# 5. Restore default for the user (option on, file removed).
	DirAccess.open("user://").remove("options.json")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
