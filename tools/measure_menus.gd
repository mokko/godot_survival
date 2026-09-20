extends SceneTree
## Diagnostic (not a pass/fail test): prints the pause menu panel size and the
## font sizes of its title/buttons, so the panel width can be compared against
## the main menu's OptionsPanel.

func _init() -> void:
	var root_vp: Window = root
	root_vp.size = Vector2i(1280, 720)

	var pause = load("res://ui/pause_menu.tscn").instantiate()
	root_vp.add_child(pause)
	current_scene = pause
	for i in 3:
		await process_frame
	pause.open()
	for i in 3:
		await process_frame

	var panel: PanelContainer = pause.get_node("Center/Padding/Panel")
	var vbox: VBoxContainer = pause.get_node("Center/Padding/Panel/VBox")
	print("PAUSE panel=%s vbox=%s" % [panel.size, vbox.size])
	print("PAUSE title_font=%d button_font=%d" % [
		vbox.get_node("Title").get_theme_font_size("font_size"),
		vbox.get_node("Continue").get_theme_font_size("font_size")])

	var splash = load("res://ui/splash.tscn").instantiate()
	root_vp.add_child(splash)
	current_scene = splash
	for i in 3:
		await process_frame
	var svbox: VBoxContainer = splash.get_node("Center/VBox")
	var spanel: PanelContainer = splash.get_node("OptionsPanel")
	print("SPLASH vbox=%s optionspanel_min=%s title_font=%d button_font=%d title_w=%.0f" % [
		svbox.size, spanel.custom_minimum_size,
		svbox.get_node("Title").get_theme_font_size("font_size"),
		svbox.get_node("Start").get_theme_font_size("font_size"),
		splash.title_width()])
	# Button widths, one by one: the main menu's buttons are a third of the
	# title's width (ui/splash.gd BUTTON_WIDTH_RATIO), so this is where to check
	# that the column did not go back to stretching them.
	var widths: PackedStringArray = []
	for button_name in splash.MENU_BUTTONS:
		var button: Button = svbox.get_node(button_name)
		widths.append("%s=%.0f@%.0f" % [button_name, button.size.x, button.position.x])
	print("SPLASH buttons: ", ", ".join(widths))
	quit(0)