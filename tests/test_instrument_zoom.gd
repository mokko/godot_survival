extends SceneTree
## Headless check: the glasses magnify, and the player's own zoom survives being
## magnified.
##
## The claim under test is the one `ui/instrument_view.gd` used to forbid — a raised
## instrument pulls the camera's field of view in. Half of what a glass does is the mask
## (`ui/instrument_view.gd`), half is the field of view (`player/player.gd::_fov_target`,
## asked for every frame by `player/study.gd::_pull_glass`), and the two must agree.
##
##  - the pull eases to the tool's target and **stops** there, past the wheel's own
##    FOV_MIN on purpose: a glass narrows the view further than the player can scroll;
##  - lowering the glass hands the view back to that player's zoom, not to FOV_DEFAULT;
##  - a zoom made with a glass raised is that player's to keep: the wheel moves the
##    **base**, so releasing the glass comes back to the new base and not the old one;
##  - the wheel still clamps inside FOV_MIN..FOV_MAX while all of that is going on;
##  - and the wiring is real — **a live study session is what asks for the pull**, so a
##    drone carrying the binoculars across an empty hillside narrows nothing, and losing
##    the subject eases the view straight back.
##
## The mechanism half runs with `study.set_process(false)`: that loop is exactly what
## asks for `-1.0` when no session is running, which is the behaviour of steps 7-9, so
## leaving it on would erase the manual request being measured.

const StudyScript := preload("res://player/study.gd")
const PlayerScript := preload("res://player/player.gd")
const SaveGame := preload("res://world/savegame.gd")

const GLASS_FOV: float = StudyScript.MAGNIFIER_FOV
const BINOC_FOV: float = StudyScript.BINOCULAR_FOV
const FOV_DEFAULT: float = PlayerScript.FOV_DEFAULT
const FOV_MIN: float = PlayerScript.FOV_MIN
const FOV_MAX: float = PlayerScript.FOV_MAX
const ZOOM_STEP: float = PlayerScript.ZOOM_SPEED


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _wait_fov(player: Node, want: float, timeout: float) -> bool:
	## The pull is an ease in `_physics_process` (FOV_PULL_SPEED), so every "is it there
	## yet" is a predicate with a wall-clock escape rather than a fixed sleep.
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if is_equal_approx(player.camera.fov, want):
			return true
		await physics_frame
	return is_equal_approx(player.camera.fov, want)


func _wait_until(condition: Callable, timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _wheel(up: bool) -> void:
	## A real wheel event through the ordinary pipeline: the handler in
	## `player/player.gd::_unhandled_input` is part of what is being tested.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _equip(player: Node, item_id: String) -> bool:
	## Equip by slot, the way the number keys do.
	var inv = player.inventory
	if inv == null:
		return false
	for i in inv.SLOTS:
		if inv.slots[i] == item_id:
			inv.equip(i)
			return true
	return false


func _close_story(main: Node) -> void:
	## Opening the satchel puts a milestone page up over a paused world (ui/story.md), and
	## nothing in the world ticks until it is closed — including this test's waits.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story != null and story.is_playing():
		story._advance()


func _init() -> void:
	var fails: PackedStringArray = []

	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: Node = main.get_node("Player")
	var study: Node = player.get_node("Study")
	await _wait(0.4)

	# 1. The survey comes out of the satchel, as it does in a run.
	var home: Vector3 = player.global_position
	var kit: Node3D = main.get_node("ExplorerKit")
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	if not kit.use_for_test(player):
		fails.append("kit_did_not_open")
	_close_story(main)
	await _wait(0.2)
	player.global_position = home

	# 2. Nothing raised: the camera sits at the player's own zoom.
	if not is_equal_approx(player.camera.fov, FOV_DEFAULT):
		fails.append("camera_starts_at_%.1f" % player.camera.fov)
	if not is_equal_approx(player.base_fov, FOV_DEFAULT):
		fails.append("base_starts_at_%.1f" % player.base_fov)
	if player.instrument_fov() > 0.0:
		fails.append("asked_for_a_pull_at_start")

	# The mechanism half: the study's own frame loop is what asks for -1.0 with no
	# session running (steps 7-9), so it is off while a request is placed by hand.
	study.set_process(false)

	# 3. The pull eases to the glass's target and stops there — and it goes *past* the
	#    wheel's own FOV_MIN, which is the point of a glass.
	player.set_instrument_fov(BINOC_FOV)
	if not await _wait_fov(player, BINOC_FOV, 3.0):
		fails.append("binoculars_pull_%.1f" % player.camera.fov)
	if not is_equal_approx(player.camera.fov, BINOC_FOV):
		fails.append("pull_overshot_%.1f" % player.camera.fov)
	if player.camera.fov >= FOV_MIN:
		fails.append("pull_stopped_at_the_wheel_clamp_%.1f" % player.camera.fov)

	# 4. Lowering the glass hands the view back to the player's own zoom, not FOV_DEFAULT.
	player.set_instrument_fov(-1.0)
	if not await _wait_fov(player, FOV_DEFAULT, 3.0):
		fails.append("release_did_not_restore_%.1f" % player.camera.fov)

	# 5. A zoom chosen with the glass up belongs to the player: the wheel moves the base
	#    while the pull holds the camera, and the release comes back to the new base.
	player.set_instrument_fov(GLASS_FOV)
	if not await _wait_fov(player, GLASS_FOV, 3.0):
		fails.append("loupe_pull_%.1f" % player.camera.fov)
	_wheel(true)
	_wheel(true)
	await _wait(0.1)
	if not is_equal_approx(player.base_fov, FOV_DEFAULT - ZOOM_STEP * 2.0):
		fails.append("wheel_did_not_move_the_base_%.1f" % player.base_fov)
	if not is_equal_approx(player.camera.fov, GLASS_FOV):
		fails.append("wheel_moved_the_camera_under_the_pull_%.1f" % player.camera.fov)
	player.set_instrument_fov(-1.0)
	if not await _wait_fov(player, FOV_DEFAULT - ZOOM_STEP * 2.0, 3.0):
		fails.append("kept_zoom_lost_%.1f" % player.camera.fov)

	# 6. The wheel still clamps at both ends, pull or no pull.
	for i in 40:
		_wheel(false)
	await _wait(0.1)
	if not is_equal_approx(player.base_fov, FOV_MAX):
		fails.append("wheel_past_max_%.1f" % player.base_fov)
	if not is_equal_approx(player.camera.fov, FOV_MAX):
		fails.append("camera_past_max_%.1f" % player.camera.fov)
	for i in 40:
		_wheel(true)
	await _wait(0.1)
	if not is_equal_approx(player.base_fov, FOV_MIN):
		fails.append("wheel_past_min_%.1f" % player.base_fov)
	# Back to an ordinary zoom for the session below (FOV_MIN + 5 * ZOOM_STEP).
	for i in 5:
		_wheel(false)
	await _wait(0.1)

	study.set_process(true)
	await _wait(0.1)

	# 7. Carrying the glass asks for nothing: no session, no pull, no movement.
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable")
	await _wait(0.2)
	if study.instrument() != "magnifying_glass":
		fails.append("glass_not_held:%s" % study.instrument())
	if player.instrument_fov() > 0.0:
		fails.append("glass_up_asked_for_a_pull_with_nothing_in_view")
	if not is_equal_approx(player.camera.fov, player.base_fov):
		fails.append("camera_moved_with_no_subject_%.1f" % player.camera.fov)

	# 8. Hold a plant in the loupe: now there is a subject, and the pull arrives with it.
	var plant: Node3D = (load("res://flora/frostneedle.tscn") as PackedScene).instantiate()
	main.add_child(plant)
	var forward: Vector3 = -player.global_transform.basis.z
	var ahead: Vector3 = player.global_position + Vector3(forward.x, 0.0, forward.z) * 4.0
	plant.global_position = Vector3(ahead.x, player.global_position.y, ahead.z)
	await _wait(0.2)
	player.camera.look_at(plant.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("plant_not_studyable")
	await _wait(0.2)
	if not study.is_studying():
		fails.append("session_did_not_start")
	if not is_equal_approx(player.instrument_fov(), GLASS_FOV):
		fails.append("session_asked_for_%.1f" % player.instrument_fov())
	if not await _wait_fov(player, GLASS_FOV, 3.0):
		fails.append("session_pull_%.1f" % player.camera.fov)

	# 9. Lose the subject (out of the glass's reach) and the view eases straight back —
	#    the same signal the meter gives. The node stays valid on purpose: freeing a
	#    subject under a running session is not what a player does.
	plant.global_position = player.global_position + Vector3(0.0, 0.0, 60.0)
	if not await _wait_until(func() -> bool: return not study.is_studying(), 5.0):
		fails.append("session_never_ended")
	await _wait(0.2)
	if player.instrument_fov() > 0.0:
		fails.append("pull_survived_the_session_%.1f" % player.instrument_fov())
	if not await _wait_fov(player, player.base_fov, 3.0):
		fails.append("view_did_not_release_%.1f" % player.camera.fov)

	if fails.is_empty():
		print("RESULT ALL PASS default=%.1f binoculars=%.1f loupe=%.1f min=%.1f max=%.1f"
				% [FOV_DEFAULT, BINOC_FOV, GLASS_FOV, FOV_MIN, FOV_MAX])
	else:
		print("RESULT FAIL %s" % ", ".join(fails))
	quit(0 if fails.is_empty() else 1)
