extends SceneTree
## Headless check: splash Start button hands off to the story scene, the main
## menu offers an Exit button wired to the exit handler, and the menu buttons are
## a third of the title's width, centred under it.

func _init() -> void:
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	for i in 5:
		await process_frame
	var start: Button = splash.get_node("Center/VBox/Start")
	var title: Label = splash.get_node("Center/VBox/Title")
	## The menu must show the project's own name: comparing against
	## ProjectSettings means a rename cannot leave one of the two behind.
	var ok_title: bool = title.text == str(ProjectSettings.get_setting("application/config/name"))
	# Exit must exist and be wired; we don't press it (that would quit the
	# test process before it can report).
	var quit_btn: Button = splash.get_node_or_null("Center/VBox/Exit")
	var quit_ok: bool = quit_btn != null and quit_btn.text == "Exit" \
			and not quit_btn.disabled
	if quit_ok:
		var wired := false
		for c in quit_btn.pressed.get_connections():
			if (c["callable"] as Callable).get_method() == "_on_exit_pressed":
				wired = true
		quit_ok = wired

	# Button size: a third of the title, every button the same, centred under it
	# and no longer as wide as the column. Measured here from the title's own
	# font metrics, so this does not just re-ask the code that sized them.
	var font: Font = title.get_theme_font("font")
	var title_w: float = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, title.get_theme_font_size("font_size")).x
	var want: float = ceilf(title_w / 3.0)
	var size_ok := title_w > 0.0
	var centre_ok := true
	var fit_ok := true
	for button_name in splash.MENU_BUTTONS:
		var b: Button = splash.get_node("Center/VBox/" + button_name)
		if absf(b.size.x - want) > 1.0 or b.size.x >= title_w * 0.5:
			size_ok = false
			print("  %s is %.0f wide, wanted %.0f of a %.0f title"
					% [button_name, b.size.x, want, title_w])
		if absf(b.position.x - (title_w - b.size.x) * 0.5) > 2.0:
			centre_ok = false
			print("  %s sits at x=%.0f, not centred in the %.0f column"
					% [button_name, b.position.x, title_w])
		# Narrower buttons must still hold their labels without clipping.
		var label_w: float = b.get_theme_font("font").get_string_size(b.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		if label_w > b.size.x:
			fit_ok = false
			print("  label %s (%.0f) does not fit a %.0f button"
					% [b.text, label_w, b.size.x])

	splash._on_start_pressed()
	for i in 10:
		await process_frame
	# change_scene_to_file replaces current_scene; verify it's the Story.
	var scene = current_scene
	var ok_story: bool = scene != null and scene.name == "Story"
	# Start is a fresh run: it must ask the player for the starting loadout.
	var ok_new_run: bool = SaveGame.pending_new_run and not SaveGame.pending_load
	print("RESULT title=%s start=%s quit=%s story_scene=%s new_run=%s buttons=%s centred=%s fits=%s"
			% [ok_title, start != null, quit_ok, ok_story, ok_new_run, size_ok, centre_ok, fit_ok])
	quit(0 if (ok_title and start != null and quit_ok and ok_story and ok_new_run
			and size_ok and centre_ok and fit_ok) else 1)
