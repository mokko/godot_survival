extends SceneTree
## Headless check: real input (synthetic ESC key + left mouse click through
## the input pipeline, not hand-called handlers) skips the story screen and
## enters the game immediately, even while the typewriter is still typing.

func _esc_press() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _left_click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(100, 100)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _init() -> void:
	# --- Click walks the pages, then enters the game ---
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame
	# One press moves one step, so it takes as many presses as the intro has pages.
	var pages: int = story.page_count()
	for i in pages:
		_left_click()
	var click_ok: bool = await _await_game()

	# --- ESC walks the pages too (fresh story) ---
	var main = current_scene
	root.remove_child(main)
	main.free()
	story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame
	for i in pages:
		_esc_press()
	var esc_ok: bool = await _await_game()

	print("RESULT pages=%d click_skips=%s esc_skips=%s" % [pages, click_ok, esc_ok])
	quit(0 if (click_ok and esc_ok) else 1)


func _await_game(max_frames := 900) -> bool:
	## The swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are far shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false
