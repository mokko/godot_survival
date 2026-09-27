extends SceneTree
## Headless checks on the first minute of a run: where the Explorer's Kit stands, what
## it hands over, that it hands it over once, and that the katana lies within the same
## stroll, and that emptying the kit puts the satchel on the drone's shoulder and takes
## it out of the grass.
##
## The placement half is the reason this test exists at all. Nothing records the satchel
## — no HUD marker, no Pedia entry, no save flag for anything but *opened* — so "the
## drone can find its gear" is only ever as true as its transform in
## `world/main.tscn`, and a satchel standing in the sea or a metre under the ground
## looks exactly like a working one from inside the code.

const Ezo := preload("res://world/island.gd")
const SaveGame := preload("res://world/savegame.gd")

## Where a new run wakes up (`world/island.gd`, SPAWN_XZ).
const SPAWN := Vector2(-112.0, 82.0)
## A first stroll, not a journey: the satchel and the katana are both inside this much of
## the spawn.
const NEAR := 25.0
## What is in the satchel, spelled out here rather than read off it, so a contents list
## that quietly changed shape cannot pass.
const EXPECTED := ["notebook", "pen", "magnifying_glass", "binoculars"]


func _click() -> void:
	## A real left click through the input pipeline, aimed at open sky in the middle of
	## the screen — the path that decides whether anything in the HUD swallows it before
	## the story screen can see it.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(root.size.x * 0.5, root.size.y * 0.3)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _init() -> void:
	var fails: PackedStringArray = []
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player: CharacterBody3D = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")

	# 1. One satchel, a stroll from the spawn, on ground a drone can stand on, sitting
	#    exactly on the terrain (y from island.gd's height field, no floating satchel).
	var satchels := get_nodes_in_group("explorer_kit")
	if satchels.size() != 1:
		print("RESULT FAIL: satchels=%d" % satchels.size())
		quit(1)
		return
	var kit: Node3D = satchels[0]
	var site := Vector2(kit.global_position.x, kit.global_position.z)
	var ground: float = Ezo.height_at(site.x, site.y)
	if site.distance_to(SPAWN) > NEAR:
		fails.append("kit_far=%.1f" % site.distance_to(SPAWN))
	if not Ezo.is_land(site.x, site.y) or ground < 1.0:
		fails.append("kit_not_on_dry_ground=%.2f" % ground)
	if absf(kit.global_position.y - ground) > 0.01:
		fails.append("kit_floats=%.2f" % kit.global_position.y)
	if kit.is_open():
		fails.append("kit_open_on_a_fresh_run")
	if kit.contents() != EXPECTED:
		fails.append("kit_contents=%s" % str(kit.contents()))
	# The bag is lying on the cape and the drone is not wearing one: a run has to find
	# it first, which is the whole of the "we carry our inventory in the satchel" idea.
	var equip: Node = player.get_node_or_null("Equipment")
	if equip == null or not equip.has_method("wears_satchel"):
		fails.append("no_equipment_to_wear_a_bag")
	elif equip.wears_satchel():
		fails.append("wore_the_bag_before_finding_it")
	if not kit.visible:
		fails.append("the_satchel_is_not_on_the_cape_on_a_fresh_run")

	# 2. The katana is on that same stroll, and it is a real pickup: walking into it
	#    hands the sword over.
	var katana: Node3D = null
	for node in main.get_node("Items").get_children():
		if str(node.get("item_id")) != "sword":
			continue
		var spot := Vector2(node.global_position.x, node.global_position.z)
		if spot.distance_to(SPAWN) <= NEAR:
			katana = node
	if katana == null:
		fails.append("no_katana_near_spawn")
	else:
		# It is the sword *prop* (items/katana_pickup.gd), not a tinted cube: the one
		# blade a run depends on should read as a sword from across the grass.
		var blade_script: Script = katana.get_script()
		if blade_script == null \
				or not str(blade_script.resource_path).contains("katana_pickup"):
			fails.append("katana_is_not_a_sword_prop")
		katana.call("_on_body_entered", player)
		if not inv.has_item("sword"):
			fails.append("katana_not_collectable")
	inv.clear_all()

	# 3. A full bag keeps the satchel shut: the gear waits in it rather than dropping to
	#    the ground, and the satchel does not report itself opened.
	for i in 20:
		player.add_item("flint")
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	if not inv.is_full():
		fails.append("bag_not_full")
	if kit.use_for_test(player):
		fails.append("full_bag_opened_the_satchel")
	if kit.is_open() or inv.has_item("notebook"):
		fails.append("full_bag_took_something")
	inv.clear_all()

	# 4. Out of reach is out of reach (the bench's radius, the same 3.5 m).
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 6.0)
	if kit.use_for_test(player):
		fails.append("opened_from_far_away")
	if kit.is_open():
		fails.append("open_from_far_away")

	# 5. Beside it, the satchel hands over exactly its four — and no katana.
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	if not kit.use_for_test(player):
		fails.append("satchel_refused")
	if not kit.is_open():
		fails.append("satchel_still_shut")
	for item_id in EXPECTED:
		if not inv.has_item(item_id):
			fails.append("missing_%s" % item_id)
	var carried := 0
	for i in inv.SLOTS:
		if inv.slots[i] != "":
			carried += 1
	if carried != EXPECTED.size():
		fails.append("satchel_gave_%d_items" % carried)
	if inv.has_item("sword"):
		fails.append("the_satchel_gave_a_katana")

	# Emptying it puts the bag on the drone and takes it out of the grass — the two are
	# never on screen at once — and disables the shape, so no invisible wall is left
	# standing where the satchel lay.
	for i in 2:
		await process_frame
	if kit.visible:
		fails.append("the_satchel_stayed_on_the_cape_after_opening")
	if equip == null or not equip.wears_satchel():
		fails.append("the_bag_did_not_go_onto_the_drone")
	var shapes := kit.find_children("*", "CollisionShape3D", true, false)
	if shapes.is_empty() or not (shapes[0] as CollisionShape3D).disabled:
		fails.append("the_satchel_left_an_invisible_wall")

	# 5b. Finding the kit is the run's second screen: the satchel asks the HUD's story screen
	#     for its page (ui/story_text.gd's `explorer_kit` milestone) the moment it is
	#     emptied, over a paused world — and one real click hands the run back, with the
	#     world still standing (a milestone screen that loaded a scene would restart the
	#     run it is narrating).
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story == null:
		fails.append("the HUD has no milestone story screen")
	else:
		if not story.is_playing():
			fails.append("opening the kit did not put its page up")
		elif story.milestone_id() != "explorer_kit":
			fails.append("the kit played '%s'" % story.milestone_id())
		# The world instances the screen with this off. If the scene ever loses it, the
		# last press would load `world/main.tscn` over the run the page is narrating.
		if story.enters_game:
			fails.append("the world's story screen would enter the game from a milestone")
		if not paused:
			fails.append("the world did not pause behind the kit's page")
		_click()
		for i in 3:
			await process_frame
		if paused or story.is_playing():
			fails.append("the click did not hand the run back (paused=%s shown=%s)"
					% [paused, story.is_playing()])
			# Do not poison the rest of the run over it: the checks below are about the
			# satchel's save state, not about the screen.
			paused = false

	# 6. A second press hands nothing over again: the satchel is one-shot.
	var bag: Array = inv.slots.duplicate()
	if not kit.use_for_test(player):
		fails.append("second_press_refused")
	if inv.slots != bag:
		fails.append("satchel_refilled")

	# 7. "Opened" rides in the save...
	if not player.has_opened_container("explorer_kit"):
		fails.append("not_recorded_as_opened")
	var state: Dictionary = player.save_state()
	if not (state.get("containers", []) as Array).has("explorer_kit"):
		fails.append("save_missing_containers")

	# ...and a run restored from that state keeps the satchel open. Loading goes through
	# the player (the state is read straight off the dictionary, no file needed), and a
	# satchel the scene has only just built is asked again — the loaded-run case.
	player.load_state(state)
	if not player.has_opened_container("explorer_kit"):
		fails.append("restored_run_lost_the_container")
	if not inv.has_item("notebook"):
		fails.append("restored_run_lost_the_kit")
	var spare: Node3D = (load("res://world/explorer_kit.tscn") as PackedScene).instantiate()
	spare.position = kit.global_position
	main.add_child(spare)
	for i in 5:
		await physics_frame
	if not spare.is_open():
		fails.append("satchel_ignored_the_saved_opened_list")
	if spare.visible:
		fails.append("a_loaded_run_left_a_satchel_lying_on_the_cape")
	var bag2: Array = inv.slots.duplicate()
	player.global_position = spare.global_position + Vector3(0.0, 0.0, 1.2)
	spare.use_for_test(player)
	if inv.slots != bag2:
		fails.append("restored_satchel_refilled")

	if fails.is_empty():
		print("RESULT ALL PASS kit=%s" % str(kit.global_position))
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)