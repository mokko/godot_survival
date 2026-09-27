extends SceneTree
## Headless check: death stops the world. Time does not pass any more (the sun keeps its
## place instead of sailing on towards sundown), and keys and clicks stop meaning
## anything — walking, jumping, the left-click jab and the zoom wheel included.
##
## ESC is the one key still answered: it starts the run again, and the clock with it. A
## respawned drone standing in a halted sky would be the same bug wearing a different hat,
## so that half is checked here too — as is movement coming back, because "nothing moves
## any more" must not quietly become "nothing moves ever again".

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame   # let fade-in finish so input unlocks
	var player: CharacterBody3D = main.get_node("Player")
	var cycle: Node = main.get_node("DayCycle")
	var fails: Array = []

	# 1. Die the way the game kills you: damage that empties the meter. Three hits, because
	#    a hit buys a moment of invulnerability against the next one.
	for i in 3:
		player.damage(999.0)
		await physics_frame
	if not player._game_over:
		fails.append("999 damage three times over did not end the run")
	if player.life > 0.0:
		fails.append("the meter still reads %.1f energy after death" % player.life)

	# 2. Time stops where it was. Sixty physics frames is a full second of world time — at
	#    DAY_LENGTH 1200 that is 0.08% of a day, far too small for an approximate compare to
	#    catch honestly, so this compares exactly: either something advanced the clock, or
	#    nothing did.
	var t0: float = cycle.time_of_day
	for i in 60:
		await physics_frame
	if not cycle.halted:
		fails.append("the day cycle was not told to halt")
	if cycle.time_of_day != t0:
		fails.append("time passed while dead: %.6f -> %.6f" % [t0, cycle.time_of_day])

	# 3. Movement keys do nothing: hold every direction and jump, and the drone does not
	#    move. Forty frames is two thirds of a second of held keys.
	var was: Vector3 = player.global_position
	Input.action_press("move_forward")
	Input.action_press("move_back")
	Input.action_press("move_left")
	Input.action_press("move_right")
	Input.action_press("jump")
	for i in 40:
		await physics_frame
	var moved: float = was.distance_to(player.global_position)
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	if moved > 0.01:
		fails.append("movement keys moved the dead drone %.3f m" % moved)

	# 4. A left click does not jab. The jab's own cooldown is the read rather than a flag
	#    added for the test: `combat.try_punch()` starts it, and so it can only have risen
	#    if a jab was thrown. The wheel is checked with it, because "no clicks" means the
	#    whole mouse, not just the button that used to punch.
	var cd: float = player.combat._punch_cd
	var fov: float = player.camera.fov
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	for i in 5:
		await physics_frame
	if player.combat._punch_cd > cd:
		fails.append("the left click jabbed after death")
	if player.camera.fov != fov:
		fails.append("the wheel zoomed after death: %.1f -> %.1f"
				% [fov, player.camera.fov])

	# 5. ESC is the one key still answered: it starts the run again, and the clock with it.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	Input.flush_buffered_events()
	for i in 5:
		await physics_frame
	if player._game_over:
		fails.append("ESC did not restart the run")
	if player.life <= 0.0:
		fails.append("the restart did not refill the meter")
	if cycle.halted:
		fails.append("the clock stayed halted after the restart")
	var t1: float = cycle.time_of_day
	for i in 30:
		await physics_frame
	if cycle.time_of_day == t1:
		fails.append("time did not start again after the restart")

	# 6. ...and the world answers again: the same keys that did nothing a moment ago walk
	#    the drone away from its spawn.
	var back: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in 40:
		await physics_frame
	Input.action_release("move_forward")
	var walked: float = back.distance_to(player.global_position)
	if walked < 0.1:
		fails.append("movement did not come back after the restart (%.3f m)" % walked)

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
