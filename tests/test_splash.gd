extends SceneTree
## Headless check: splash Start button hands off to the story scene, and the
## main menu offers an Exit button wired to the exit handler.

func _init() -> void:
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	for i in 5:
		await process_frame
	var start: Button = splash.get_node("Center/VBox/Start")
	## The menu must show the project's own name: comparing against
	## ProjectSettings means a rename cannot leave one of the two behind.
	var ok_title: bool = splash.get_node("Center/VBox/Title").text \
			== str(ProjectSettings.get_setting("application/config/name"))
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
	splash._on_start_pressed()
	for i in 10:
		await process_frame
	# change_scene_to_file replaces current_scene; verify it's the Story.
	var scene = current_scene
	var ok_story: bool = scene != null and scene.name == "Story"
	# Start is a fresh run: it must ask the player for the starting loadout.
	var ok_new_run: bool = SaveGame.pending_new_run and not SaveGame.pending_load
	print("RESULT title=%s start=%s quit=%s story_scene=%s new_run=%s"
			% [ok_title, start != null, quit_ok, ok_story, ok_new_run])
	quit(0 if (ok_title and start != null and quit_ok and ok_story and ok_new_run) else 1)
