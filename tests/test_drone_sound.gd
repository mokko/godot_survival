extends SceneTree
## Headless check: the drone's **treads** — one loop that fades in with ground speed, not a
## sound fired per step. Standing still is silence; rolling is audible; a sprint is louder and
## higher pitched; and it falls silent while dead or aboard a boat.
##
## The WAV is generated (`tools/make_sounds.py::tread_loop`), and a `load()` that got no
## `.import` yields a **null stream that plays silence** — so this checks the stream resolved
## and has length rather than trusting the player's existence, and it checks the loop is
## switched on, because a loop is the whole difference between treads rolling and a thump
## repeating.

const SaveGame := preload("res://world/savegame.gd")
const PlayerScript := preload("res://player/player.gd")

## What the levels are, read off the player's own constants so this cannot drift.
const IDLE_DB: float = PlayerScript.TREAD_IDLE_DB
const FULL_SPEED: float = PlayerScript.TREAD_SPEED_FULL


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _settle(player: Node, seconds: float) -> void:
	## Step the treads by hand, as if that much time had passed: the ease is per second, and
	## waiting it out for real would make this test slower than the thing it checks.
	for i in int(seconds / 0.05):
		player._update_tread(0.05)


func _init() -> void:
	var fails: PackedStringArray = []
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: CharacterBody3D = main.get_node("Player")
	for i in 90:
		await physics_frame

	var tread: AudioStreamPlayer = player._tread
	if tread == null or tread.stream == null:
		fails.append("no_tread_player")
	else:
		if tread.stream.get_length() <= 0.0:
			fails.append("tread_stream_is_silent")
		if not (tread.stream is AudioStreamWAV) \
				or tread.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			fails.append("tread_stream_does_not_loop")

	# 1. Standing still: silent, and not left running.
	_settle(player, 1.0)
	var idle_db: float = tread.volume_db
	if absf(idle_db - IDLE_DB) > 0.5 or tread.playing:
		fails.append("still_is_not_silent:%.1f playing=%s" % [idle_db, str(tread.playing)])

	# 2. Walking: audible, and the pitch moved off its floor.
	Input.action_press("move_forward")
	await _wait(0.9)
	var walk_db: float = tread.volume_db
	var walk_pitch: float = tread.pitch_scale
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	if not tread.playing:
		fails.append("walking_does_not_play:%.1f" % walk_speed)
	if walk_db <= IDLE_DB + 6.0:
		fails.append("walking_is_silent:%.1f speed=%.1f" % [walk_db, walk_speed])
	if walk_pitch <= PlayerScript.TREAD_PITCH_MIN:
		fails.append("pitch_did_not_move:%.2f" % walk_pitch)

	# 3. A sprint reads as louder and higher — the same loop, scaled by speed.
	player.velocity = Vector3(FULL_SPEED, 0.0, 0.0)
	_settle(player, 0.4)
	var fast_db: float = tread.volume_db
	var fast_pitch: float = tread.pitch_scale
	if fast_db <= walk_db + 1.0 or fast_pitch <= walk_pitch:
		fails.append("sprint_not_louder_or_higher:%.1f/%.2f vs %.1f/%.2f"
				% [fast_db, fast_pitch, walk_db, walk_pitch])

	# 4. Stopping again fades it out and stops the loop.
	player.velocity = Vector3.ZERO
	_settle(player, 1.0)
	if tread.playing or tread.volume_db > IDLE_DB + 0.5:
		fails.append("still_running_after_stopping:%.1f" % tread.volume_db)

	# 5. Dead: silent even with the body still sliding.
	player.velocity = Vector3(FULL_SPEED, 0.0, 0.0)
	player._game_over = true
	_settle(player, 1.0)
	if tread.playing or tread.volume_db > IDLE_DB + 0.5:
		fails.append("dead_drone_still_rolls:%.1f" % tread.volume_db)
	player._game_over = false
	player.velocity = Vector3.ZERO

	# 6. Aboard a boat: the treads are not what carries the drone across a strait.
	var boat: Node3D = get_nodes_in_group("boat")[0]
	boat.call("board_for_test", player)
	player.velocity = Vector3(FULL_SPEED, 0.0, 0.0)
	_settle(player, 1.0)
	if tread.playing:
		fails.append("treads_roll_on_a_boat_deck")
	boat.call("_go_ashore")
	player.velocity = Vector3.ZERO

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS idle=%.1f walk=%.1f/%.2f sprint=%.1f/%.2f"
				% [idle_db, walk_db, walk_pitch, fast_db, fast_pitch])
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
