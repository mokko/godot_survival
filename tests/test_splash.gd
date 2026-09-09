extends SceneTree
## Headless check: splash Start button hands off to the story scene.

func _init() -> void:
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	for i in 5:
		await process_frame
	var start: Button = splash.get_node("Center/VBox/Start")
	var ok_title: bool = splash.get_node("Center/VBox/Title").text == "Survival"
	splash._on_start_pressed()
	for i in 10:
		await process_frame
	# change_scene_to_file replaces current_scene; verify it's the Story.
	var scene = current_scene
	var ok_story: bool = scene != null and scene.name == "Story"
	print("RESULT title=%s start=%s story_scene=%s" % [ok_title, start != null, ok_story])
	quit(0 if (ok_title and start != null and ok_story) else 1)
