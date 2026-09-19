extends SceneTree
## Headless check: the boats — one moored off the south coast of every island on
## the route except the last, each knowing its next island, reachable from dry
## land, boardable, steerable, and refusing to strand the player at sea.


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: CharacterBody3D = main.get_node("Player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 10:
		await physics_frame
	var fails: PackedStringArray = []

	var boats: Array = get_nodes_in_group("boat")
	if boats.size() != 3:
		fails.append("boat_count=%d (want 3: every island but the last)" % boats.size())

	# 1. Route: Ezo -> Honshu -> Shikoku -> Kyushu, and Kyushu (last) has no boat.
	var seen: Dictionary = {}
	for b in boats:
		seen[b.island] = b.destination
	for pair in [["Ezo", "Honshu"], ["Honshu", "Shikoku"], ["Shikoku", "Kyushu"]]:
		if seen.get(pair[0], "") != pair[1]:
			fails.append("leg %s->%s missing (got %s)" % [pair[0], pair[1], seen.get(pair[0], "-")])
	if seen.has("Kyushu"):
		fails.append("Kyushu is the last island but has a boat")

	# 2. Each boat floats in shallow water beside dry land the player can walk to.
	var positions: Array = []
	for b in boats:
		positions.append(Vector2(b.global_position.x, b.global_position.z))
		if not Ezo.is_water(b.global_position.x, b.global_position.z):
			fails.append("%s is not in water" % b.island)
		var land: Vector3 = Ezo.nearest_land_point(
				Vector2(b.global_position.x, b.global_position.z), 5.0)
		if land == Vector3.INF:
			fails.append("%s has no shore within boarding range" % b.island)
		if b.has_node("Hull") == false:
			fails.append("%s has no hull mesh" % b.island)
		var lantern: MeshInstance3D = b.get_node_or_null("Lantern")
		var lamp_mat: StandardMaterial3D = null if lantern == null \
				else lantern.material_override as StandardMaterial3D
		if lamp_mat == null or not lamp_mat.emission_enabled:
			fails.append("%s has no lit lantern" % b.island)
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			if positions[i].distance_to(positions[j]) < 50.0:
				fails.append("boats %d and %d are on the same beach" % [i, j])

	# 3. Board the first boat: the player must end up pinned to its deck.
	var boat: StaticBody3D = boats[0]
	player.global_position = Ezo.nearest_land_point(
			Vector2(boat.global_position.x, boat.global_position.z), 8.0)
	for i in 3:
		await physics_frame
	boat.board_for_test(player)
	if not player.in_boat() or boat.driver() != player:
		fails.append("boarding did not seat the player")
	for i in 5:
		await physics_frame
	var deck_gap: float = absf(player.global_position.y - (boat.global_position.y + boat.RIDE_HEIGHT))
	if deck_gap > 0.2:
		fails.append("player is not on the deck (gap %.2f)" % deck_gap)
	var before := boat.global_position
	var yaw_before := boat.rotation.y

	# 4. Steering: W sails, A turns.
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	var sailed := before.distance_to(boat.global_position)
	if sailed < 2.0:
		fails.append("W did not move the boat (%.2f units)" % sailed)
	if player.global_position.distance_to(boat.global_position) > 3.0:
		fails.append("the player came off the deck while sailing")
	Input.action_press("move_left")
	for i in 20:
		await physics_frame
	Input.action_release("move_left")
	if absf(angle_difference(boat.rotation.y, yaw_before)) < 0.1:
		fails.append("A did not steer the boat")

	# 5. Stepping off mid-strait must be refused — the world has no collision down
	#    there, so it would drop the player into the fall-death.
	boat.global_position = Vector3(-120.0, 0.0, 300.0)   # open water between islands
	for i in 3:
		await physics_frame
	if boat._go_ashore():
		fails.append("boat let the player off in open water")
	if not player.in_boat():
		fails.append("player was unseated by a refused landing")

	# 6. Ashore on land: the player ends up standing on dry ground.
	var mooring: Vector3 = boats[0].mooring()
	boat.global_position = Vector3(mooring.x, 0.0, mooring.z)
	for i in 3:
		await physics_frame
	if not boat._go_ashore():
		fails.append("boat refused to land beside its own mooring")
	if player.in_boat() or boat.driver() != null:
		fails.append("player stayed aboard after going ashore")
	if not Ezo.is_land(player.global_position.x, player.global_position.z):
		fails.append("player was set down off land")
	if player.global_position.y < 0.0:
		fails.append("player was set down under water")
	for i in 5:
		await physics_frame
	if player.global_position.y < -1.0:
		fails.append("player fell through the shore after landing")

	# 7. The bow points out to sea: pressing W must not sail the player into the
	#    beach the boat is moored beside (the new-style boats are yawed south).
	for b in boats:
		var bow: Vector3 = b.global_position - b.global_transform.basis.z * 8.0
		if Ezo.is_land(bow.x, bow.z):
			fails.append("%s bows inland" % b.island)

	# 8. A save written at sea must not drop the player into the water on load:
	#    coastal water snaps to the nearest shore, open sea falls back to spawn.
	var coastal := Vector3(33.0, 0.0, 120.0)   # just off the Ezo mooring
	if Ezo.nearest_land_point(Vector2(coastal.x, coastal.z), 40.0) == Vector3.INF:
		fails.append("test setup: coastal probe is not near land any more")
	player.load_state({"pos": [coastal.x, coastal.y, coastal.z]})
	for i in 3:
		await physics_frame
	if not Ezo.is_land(player.global_position.x, player.global_position.z):
		fails.append("coastal save did not put the player ashore")
	var open_sea := Vector3(-120.0, 0.0, 300.0)
	if Ezo.nearest_land_point(Vector2(open_sea.x, open_sea.z), 40.0) != Vector3.INF:
		fails.append("test setup: open-sea probe is within 40 of land now")
	player.load_state({"pos": [open_sea.x, open_sea.y, open_sea.z]})
	for i in 3:
		await physics_frame
	var spawn: Vector3 = Ezo.spawn_point()
	if player.global_position.distance_to(spawn) > 2.0:
		fails.append("open-sea save did not fall back to the spawn point")

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
