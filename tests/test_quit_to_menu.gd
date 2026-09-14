extends SceneTree
## Headless check: Quit in the pause menu actually returns to the main menu.
## Regression: it used to emit quit_to_menu that nothing was connected to,
## so the button did nothing.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var menu: Control = main.get_node("HUD/PauseMenu")
	var label: Button = menu.get_node("Center/Padding/Panel/VBox/Quit")
	var text_ok: bool = label.text == "Quit"

	# Open the menu (paused state), then press Quit.
	menu.open()
	for i in 3:
		await process_frame
	var was_paused: bool = paused

	menu._on_quit()
	for i in 10:
		await process_frame

	var scene := current_scene
	var back_at_menu: bool = scene != null and scene.name == "Splash"
	var unpaused: bool = not paused

	print("RESULT text=%s was_paused=%s back_at_menu=%s unpaused=%s" % [
			text_ok, was_paused, back_at_menu, unpaused])
	quit(0 if (text_ok and was_paused and back_at_menu and unpaused) else 1)
