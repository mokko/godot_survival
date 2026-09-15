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
	await process_frame
	await process_frame
	# The click must show "Loading..." straight away: the world scene takes
	# seconds to instantiate and the window would otherwise look frozen.
	var hint: Label = story.get_node("Center/VBox/Hint")
	var loading_shown: bool = hint.text == "Loading..." and hint.visible
	var in_game: bool = await _await_game()

	print("RESULT click_started=%s loading_hint=%s in_game=%s scene=%s"
			% [loading_shown or in_game, loading_shown, in_game,
			"" if current_scene == null else current_scene.name])
	quit(0 if (in_game and loading_shown) else 1)


func _await_game(max_frames := 900) -> bool:
	## The scene swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are much shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false
