extends SceneTree
## Real-input check: an actual ESC key event (through the input pipeline,
## not a hand-emitted signal) opens the pause menu while playing. Regression
## test: the old code gated pause on MOUSE_MODE_CAPTURED, which silently
## blocks ESC whenever capture fails (window focus loss, Wayland quirks).

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 120:
		await physics_frame   # let fade-in finish so input unlocks
	var player: CharacterBody3D = main.get_node("Player")
	var menu: Control = main.get_node("HUD/PauseMenu")

	# Headless can't capture the mouse (mouse_mode stays 0) — that's exactly
	# the condition that used to swallow ESC, so DON'T force captured here.

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()   # headless: deliver buffered input now
	for i in 5:
		await process_frame

	var opened: bool = menu.visible and paused

	# Second ESC closes it again (pause menu handles ESC while paused).
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_ESCAPE
	ev2.physical_keycode = KEY_ESCAPE
	ev2.pressed = true
	Input.parse_input_event(ev2)
	Input.flush_buffered_events()
	for i in 5:
		await process_frame
	var closed: bool = not menu.visible and not paused

	print("RESULT esc_opens=%s esc_closes=%s" % [opened, closed])
	quit(0 if (opened and closed) else 1)
