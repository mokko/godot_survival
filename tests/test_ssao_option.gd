extends SceneTree
## Headless check: SSAO option — on by default, applied to the world scene's
## environment, persisted across a restart, and toggled from the splash options
## panel.


func _init() -> void:
	DirAccess.open("user://").remove("options.json")
	var Options: GDScript = load("res://ui/options.gd")
	var fails: PackedStringArray = []

	# 1. Default on, and the world scene's environment turns it on.
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var env: Environment = main.get_node("WorldEnvironment").environment
	if not Options.get_option("ssao"):
		fails.append("default_off")
	if not env.ssao_enabled:
		fails.append("not_enabled_in_world")

	# 2. Switching it off persists and is honoured by a fresh world scene.
	#    (The scene's Environment sub-resource is shared between instances, so
	#    this only passes if the world actually re-reads the option.)
	Options.set_option("ssao", false)
	if not FileAccess.file_exists(Options.PATH):
		fails.append("not_saved")
	main.queue_free()
	await process_frame
	var main2 = load("res://world/main.tscn").instantiate()
	root.add_child(main2)
	current_scene = main2
	for i in 5:
		await process_frame
	if main2.get_node("WorldEnvironment").environment.ssao_enabled:
		fails.append("off_not_persisted")

	# 3. Splash options panel reflects and writes the setting.
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	var panel: PanelContainer = splash.get_node("OptionsPanel")
	var btn: CheckButton = splash.get_node("OptionsPanel/VBox/SSAO")
	splash._on_options_pressed()
	if not panel.visible or btn.button_pressed:
		fails.append("panel_state")   # panel open, checkbox reads off
	btn.button_pressed = true
	splash._on_options_back_pressed()
	if panel.is_visible_in_tree() or not Options.get_option("ssao"):
		fails.append("panel_write")
	splash.queue_free()

	# 4. Restore the default for the user (option on, file removed).
	DirAccess.open("user://").remove("options.json")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
