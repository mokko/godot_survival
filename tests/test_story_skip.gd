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
	# --- Click skips while typing ---
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame
	_left_click()
	var click_ok: bool = await _await_game()

	# --- ESC skips while typing (fresh story) ---
	var main = current_scene
	root.remove_child(main)
	main.free()
	story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	current_scene = story
	for i in 10:
		await process_frame
	_esc_press()
	var esc_ok: bool = await _await_game()

	print("RESULT click_skips=%s esc_skips=%s" % [click_ok, esc_ok])
	quit(0 if (click_ok and esc_ok) else 1)


func _await_game(max_frames := 900) -> bool:
	## The swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are far shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false
