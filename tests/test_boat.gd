extends SceneTree
## Headless check: the boats — one moored off the south coast of every island on
## the route except the last, each knowing its next island, reachable from dry
## land, boardable, steerable, refusing to strand the player at sea, and refusing
## to sail onto land.
##
## ...and the Islands chapter: a boat is what charts an island, by sailing right round it
## (section 10), so a run's notebook holds no island until one has been circled.

const Notes := preload("res://ui/pedia_notes.gd")
const StoryText := preload("res://ui/story_text.gd")


func _close_story(main: Node) -> void:
	## A milestone page goes up over a **paused** world, and every wait below is a physics
	## frame: a page left up would stall the whole test with a failure that looks like a
	## dozen broken features. The boat's page is Maurice's to write, so this has to be safe
	## whether or not there are words behind the id.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story != null and story.is_playing():
		story._advance()


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
		if not Ezo.is_navigable(b.global_position.x, b.global_position.z):
			fails.append("%s is moored in water too shallow to sail out of" % b.island)
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
	# ...and the **first** boat a run boards says what a boat is for, once (`world/boat.gd`'s
	# `BOAT_PAGE`: sail round an island and it goes into the notebook). The words are
	# Maurice's and not written yet, so this checks what it can: a page that exists plays
	# here, one that does not plays nothing at all — and either way the page is closed,
	# because a milestone screen pauses the world the waits below are counting frames in.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story == null:
		fails.append("the HUD has no milestone story screen")
	elif not StoryText.milestone(boat.BOAT_PAGE).is_empty():
		if not story.is_playing() or str(story.milestone_id()) != str(boat.BOAT_PAGE):
			fails.append("the first boarding played no boat page")
	_close_story(main)
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
	# Nothing is written into the notebook by landing: the Islands chapter is charted by
	# sailing round an island (section 10), so the book opens empty even though the run woke
	# up here. `player.island_here()` still answers — the survey beat asks it whose page a
	# finished survey earned — and it must name the island the drone is standing on.
	var landed: String = str(player.island_here())
	if landed != "ezo":
		fails.append("the drone does not know which island it landed on: '%s'" % landed)
	if Notes.count_drawn("islands") != 0:
		fails.append("landing wrote an island into the notebook: %s" % str(Notes.drawn()))

	# 7. The bow points out to sea: pressing W must not sail the player into the
	#    beach the boat is moored beside (the new-style boats are yawed south).
	for b in boats:
		var bow: Vector3 = b.global_position - b.global_transform.basis.z * 8.0
		if Ezo.is_land(bow.x, bow.z):
			fails.append("%s bows inland" % b.island)

	# 8. The hull cannot be sailed onto land. Aim the bow at the beach it is moored
	#    beside and hold W: it must refuse, and the pinned player must stay above
	#    the surface. Before this check existed the boat sailed 48 m through Ezo
	#    and stood the player 1.6 m under the island's hills.
	boat.global_position = Vector3(mooring.x, 0.0, mooring.z)
	boat.rotation.y = 0.0        # bow north: straight at the beach
	boat.board_for_test(player)
	_close_story(main)           # a second boarding says nothing (the page is a one-off)
	for i in 3:
		await physics_frame
	Input.action_press("move_forward")
	for i in 180:
		await physics_frame
	Input.action_release("move_forward")
	var inland: float = mooring.distance_to(boat.global_position)
	if inland > 8.0:
		fails.append("the boat sailed %.1f m inland (the shore should stop it)" % inland)
	if not Ezo.is_navigable(boat.global_position.x, boat.global_position.z):
		fails.append("the boat sits in water too shallow to float it")
	if Ezo.is_land(boat.global_position.x, boat.global_position.z):
		fails.append("the boat is aground on dry land")
	if boat._hint == null or not boat._hint.visible:
		fails.append("the shore refusal told the player nothing")
	var surface: float = Ezo.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < surface:
		fails.append("the player is %.2f m under the island" % (surface - player.global_position.y))
	# ... and the refusal must not wedge it: turned back out to sea, it sails away.
	boat.rotation.y = PI
	var blocked := boat.global_position
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
	Input.action_release("move_forward")
	if blocked.distance_to(boat.global_position) < 5.0:
		fails.append("the boat was stuck against the shore (%.1f m after turning back)"
				% blocked.distance_to(boat.global_position))
	# Hand the player back to dry land: while a boat is driving it pins the player
	# to its deck every frame, which would overwrite the save-check positions below.
	boat.global_position = Vector3(mooring.x, 0.0, mooring.z)
	for i in 3:
		await physics_frame
	if not boat._go_ashore():
		fails.append("boat refused to land beside its own mooring after the beach test")

	# 9. A save written at sea must not drop the player into the water on load:
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

	# 10. **The Islands chapter is a map the player drew.** Nothing is written by standing on
	#     an island or landing on it — the run opens the book on four empty chapters — and
	#     sailing right round one is what writes it down. The ring is walked with the hull, a
	#     waypoint per compass sector, each waypoint a point the rule itself accepts
	#     (`_chart_ring`): so this fails if the band or the requirement ever asked for a
	#     sector that is not reachable, which is the whole reason CHART_BAND is measured.
	var ring: Array = _chart_ring("ezo")
	if ring.size() != Ezo.CHART_SECTORS:
		fails.append("ezo offers %d of %d chart sectors" % [ring.size(), Ezo.CHART_SECTORS])
	boat.global_position = Vector3(mooring.x, 0.0, mooring.z)
	boat.rotation.y = PI
	boat.board_for_test(player)
	if story != null and story.is_playing():
		fails.append("the boat's page came up on a later boarding")
	_close_story(main)
	for i in 3:
		await physics_frame
	# Half a circuit is not a circuit.
	for i in ring.size() / 2:
		var half: Vector2 = ring[i]
		boat.global_position = Vector3(half.x, 0.0, half.y)
		for j in 2:
			await physics_frame
	if Notes.has("islands", "ezo"):
		fails.append("half a circuit wrote the island into the notebook")
	# ...and all of it is.
	for p in ring:
		boat.global_position = Vector3(p.x, 0.0, p.y)
		for j in 2:
			await physics_frame
	if not Notes.has("islands", "ezo"):
		fails.append("sailing right round Ezo did not write it into the notebook")
	if str(player.island_here()) != "ezo":
		fails.append("the drone does not know it is off Ezo: '%s'" % player.island_here())
	if not boat._go_ashore():
		fails.append("could not land again after the circuit")

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _chart_ring(id: String) -> Array:
	## One waypoint per compass sector that the charting rule accepts, found by walking
	## bearings out from the island's chart centre until the rule says "this is sea in the
	## band". The list is what a hull sailing right round the island would pass through, and
	## building it from the rule is the point: a sector that cannot be reached cannot be put
	## in the ring, and the caller sees the shortfall.
	var out: Array = []
	var centre: Vector2 = Ezo.centre_of(id)
	for s in Ezo.CHART_SECTORS:
		var found := Vector2.INF
		var dir := Vector2(cos(_bearing(s)), sin(_bearing(s)))
		var r := 4.0
		while r <= 900.0 and found == Vector2.INF:
			var p: Vector2 = centre + dir * r
			if Ezo.chart_sector(id, p) == s:
				found = p
			r += 4.0
		if found != Vector2.INF:
			out.append(found)
	return out


func _bearing(sector: int) -> float:
	## A bearing in the middle of a sector: the ring waypoint should be found by walking out
	## along the sector's own half-way line, so it is unambiguously that sector's.
	return -PI + (float(sector) + 0.5) * (TAU / float(Ezo.CHART_SECTORS))
