extends SceneTree
## Headless check: the service benches — one hidden on every island, standing on
## dry ground, opening the Frame screen through the pause menu (so ESC keeps its one
## owner), closing straight back into the game, and — the decision under test —
## **recorded nowhere**: no Pedia entry, no saved flag, no marker.

const Notes := preload("res://ui/pedia_notes.gd")


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: CharacterBody3D = main.get_node("Player")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var editor: Control = menu.get_node("Editor")
	for i in 10:
		await physics_frame
	var fails: PackedStringArray = []

	# 1. One bench per island, and all four islands are covered.
	var benches: Array = get_nodes_in_group("bench")
	if benches.size() != 4:
		fails.append("bench_count=%d (want 4: one per island)" % benches.size())
	var seen: Dictionary = {}
	for b in benches:
		seen[str(b.island)] = true
	for island in ["Ezo", "Honshu", "Shikoku", "Kyushu"]:
		if not seen.has(island):
			fails.append("%s has no bench" % island)

	# 2. Each stands on dry, walkable ground — not in the sea, not on a summit.
	var positions: Array = []
	for b in benches:
		positions.append(Vector2(b.global_position.x, b.global_position.z))
		var h := Ezo.height_at(b.global_position.x, b.global_position.z)
		if not Ezo.is_land(b.global_position.x, b.global_position.z):
			fails.append("%s's bench is not on land" % b.island)
		if h < 1.0 or h > 9.0:
			fails.append("%s's bench sits at %.2f (want 1.0..9.0)" % [b.island, h])
		# The bench must actually rest on the terrain, not float or sink.
		if absf(b.global_position.y - h) > 0.05:
			fails.append("%s's bench is %.2f off the ground" % [b.island, b.global_position.y - h])
		if b.get_node_or_null("Body") == null:
			fails.append("%s's bench has no mesh" % b.island)
		var lamp: MeshInstance3D = b.get_node_or_null("Lamp")
		var lamp_mat: StandardMaterial3D = null if lamp == null \
				else lamp.material_override as StandardMaterial3D
		if lamp_mat == null or not lamp_mat.emission_enabled:
			fails.append("%s's bench has no lit lamp" % b.island)
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			if positions[i].distance_to(positions[j]) < 50.0:
				fails.append("benches %d and %d are on the same beach" % [i, j])

	# 3. Reach: only inside USE_RADIUS, and nothing opens while out of range.
	var bench: StaticBody3D = benches[0]
	var before_menu: bool = menu.visible
	player.global_position = bench.global_position + Vector3(20.0, 0.0, 0.0)
	await physics_frame
	if bench.can_be_used_by(player):
		fails.append("a bench is usable from 20 m away")
	if bench.use_for_test(player):
		fails.append("a bench opened the frame screen from out of range")
	if before_menu != menu.visible:
		fails.append("the pause menu appeared on its own")

	# 4. In range, it opens the Frame screen — through the pause menu, which pauses
	#    and takes the mouse, and names the island it stands on.
	player.global_position = bench.global_position + Vector3(0.0, 0.0, 2.0)
	for i in 2:
		await physics_frame
	if not bench.can_be_used_by(player):
		fails.append("a bench is not usable from 2 m away")
	if not bench.use_for_test(player):
		fails.append("standing at a bench did not open the frame screen")
	for i in 2:
		await process_frame
	if not editor.visible:
		fails.append("the frame screen is not visible")
	if not paused:
		fails.append("the frame screen did not pause the game")
	if str(editor.island) != str(bench.island):
		fails.append("the frame screen says '%s', the bench is on '%s'"
				% [editor.island, bench.island])
	if str(editor.island) == "":
		fails.append("the frame screen does not name its bench's island")

	# 5. ESC closes it and drops the player back into the game — not into the menu,
	#    because a bench is used while playing.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	for i in 5:
		await process_frame
	if editor.visible:
		fails.append("ESC did not close the frame screen")
	if menu.visible:
		fails.append("closing the frame screen left the pause menu up")
	if paused:
		fails.append("closing the frame screen did not resume the game")

	# 6. Standing at a bench prompts the player, so the mechanic is discoverable at
	#    all. The label itself exists regardless; the prompt only *shows* while the
	#    world holds the mouse, so the visibility half is skipped where headless
	#    refuses to capture it.
	if bench._hint == null or bench._hint.name != "BenchHint":
		fails.append("the bench built no prompt label")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 2:
		await physics_frame
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if bench._hint == null or not bench._hint.visible:
			fails.append("standing at a bench shows no prompt")
		elif not str(bench._hint.text).contains("service"):
			fails.append("the bench prompt says '%s'" % bench._hint.text)
		player.global_position = bench.global_position + Vector3(20.0, 0.0, 0.0)
		for i in 2:
			await physics_frame
		if bench._hint.visible:
			fails.append("the bench prompt is still up from 20 m away")
	else:
		print("  (idle-prompt check skipped: headless did not capture the mouse)")

	# 7. The decision: a bench is a place you remember, not a record. Nothing about
	#    benches is written into the notebook, and the pause menu has no button for
	#    the frame screen — the bench in the world is the only way in.
	for key in Notes.drawn():
		if "bench" in key or "station" in key or "frame" in key:
			fails.append("a bench was recorded in the notebook: %s" % key)
	var buttons: PackedStringArray = []
	for child in menu.get_node("Center/Padding/Panel/VBox").get_children():
		if child is Button:
			buttons.append(child.text)
	if buttons != PackedStringArray(["Continue", "Saves…", "Pedia", "Quit to Menu"]):
		fails.append("the pause menu's buttons changed: %s" % ", ".join(buttons))

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)