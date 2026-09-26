extends SceneTree
## Headless check: a left mouse click on the story screen starts the game,
## just like ESC — including while the text is still typing.

func _init() -> void:
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame

	# Click in the middle of the screen while the text is still typing. One click moves
	# the story on by exactly one step, so getting through takes as many clicks as the
	# intro has pages — the last one enters the game.
	var pages: int = story.page_count()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(root.size.x * 0.5, root.size.y * 0.5)
	var advanced := 0
	for i in pages:
		Input.parse_input_event(ev)
		await process_frame
		await process_frame
		if i < pages - 1:
			# Still in the story, one page further on.
			if story.page_index() != i + 1:
				break
			advanced += 1
	# The last click must show "Loading..." straight away: the world scene takes
	# seconds to instantiate and the window would otherwise look frozen.
	var hint: Label = story.get_node("Center/VBox/Hint")
	var loading_shown: bool = hint.text == "Loading..." and hint.visible
	var in_game: bool = await _await_game()

	print("RESULT pages=%d advanced=%d loading_hint=%s in_game=%s scene=%s"
			% [pages, advanced, loading_shown, in_game,
			"" if current_scene == null else current_scene.name])
	quit(0 if (in_game and loading_shown and advanced == pages - 1) else 1)


func _await_game(max_frames := 900) -> bool:
	## The scene swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are much shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false
