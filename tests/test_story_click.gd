extends SceneTree
## Headless check: a left mouse click on the story screen starts the game,
## just like ESC — including while the text is still typing.

func _init() -> void:
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame

	# Click in the middle of the screen while the text is still typing.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(root.size.x * 0.5, root.size.y * 0.5)
	Input.parse_input_event(ev)
	for i in 30:
		await process_frame

	var in_game: bool = current_scene != null and current_scene.name == "Main"
	var hint_ok: bool = not is_instance_valid(story) or true
	print("RESULT click_started=%s in_game=%s scene=%s"
			% [in_game, in_game, "" if current_scene == null else current_scene.name])
	quit(0 if in_game else 1)
