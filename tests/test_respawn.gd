extends SceneTree
## Headless check: player dies -> game-over screen shows and STAYS, player
## stays dead (no auto-regen). The ESC restart path respawns at spawn point.
## Also: what a run starts with (nothing — the katana and the survey gear are found
## in the world), that the death wipe takes loot but not the drone's own notes,
## that the keepsakes only come back for a drone that has actually held them, and
## that a death puts the **satchel, the sword and the boat** back where they were
## (`player/player.gd::_restart` walks the `pickup` group; each member decides what
## "back" means).

const SaveGame := preload("res://world/savegame.gd")


func _close_story(main: Node) -> void:
	## A milestone page (the katana's, the kit's) goes up over a **paused** world, and every
	## wait below counts physics frames: leave one up and the test stalls in a way that
	## reads as a dozen unrelated failures.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story != null and story.is_playing():
		story._advance()


func _counting_slots(inv: Node) -> int:
	## How many slots hold something. A bare run is zero.
	var carried := 0
	for i in inv.SLOTS:
		if inv.slots[i] != "":
			carried += 1
	return carried


func _init() -> void:
	# A fresh run: the player consumes pending_new_run in its _ready and hands out
	# STARTING_ITEMS, which is deliberately empty. Without this flag the scene starts
	# with an empty inventory too (tests load main.tscn directly, skipping the splash).
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var kit: Node3D = main.get_node("ExplorerKit")
	for i in 60:
		await physics_frame
	var starts_bare: bool = _counting_slots(inv) == 0 and player.get_equipped_item() == ""
	# Die empty-handed, without ever having reached the satchel.
	player.global_position = Vector3(0, 12, 0)
	for i in 20:
		await physics_frame
	player.damage(999.0)
	# 3 seconds of physics: must stay dead, no auto-revive.
	for i in 180:
		await physics_frame
	var still_dead: bool = player._game_over
	var label = main.get_node("HUD/GameOverContainer")
	var label_visible: bool = label.visible
	var notes_wiped: bool = not inv.has_item("notebook")
	# Trigger the ESC path directly (what _unhandled_input calls).
	player._restart()
	for i in 60:
		await physics_frame
	var pos := player.global_position
	var near_spawn: bool = Vector2(pos.x, pos.z).distance_to(Vector2(-112.0, 82.0)) < 3.0
	# Nothing was ever found, so nothing comes back: the same empty hands the run
	# started with, and the satchel is still out there waiting.
	var bare_after_death: bool = _counting_slots(inv) == 0 and player.get_equipped_item() == ""

	# Now go and open the satchel the way the player does, then die again. The survey
	# is a keepsake from this point on: the death wipe takes loot, not the drone's
	# own record of the island and the instruments that fill it.
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	var opened: bool = kit.use_for_test(player)
	_close_story(main)          # the kit narrates itself: close its page before waiting
	for i in 5:
		await physics_frame
	var found_kit: bool = inv.has_item("notebook") and inv.has_item("pen") \
			and inv.has_item("magnifying_glass") and inv.has_item("binoculars")
	player.damage(999.0)
	for i in 60:
		await physics_frame
	player._restart()
	for i in 60:
		await physics_frame
	var keeps_notes: bool = inv.has_item("notebook")
	var keeps_kit: bool = inv.has_item("pen") and inv.has_item("magnifying_glass")
	var loot_gone: bool = not inv.has_item("binoculars")
	var back_to_fists: bool = player.get_equipped_item() == ""

	# --- What a death gives back: the satchel, the sword and the boat -------------------
	# The satchel is on the cape again, shut, and the run's record of having been through it
	# is gone — leave that standing and the satchel hides itself on the next sync, which is
	# the one way this could look right here and fail in the game.
	var kit_back: bool = kit.visible and not kit.is_open() \
			and not player.has_opened_container("explorer_kit")
	var bag_off: bool = not player.get_node("Equipment").wears_satchel()
	# ...and it still works: the walk back to it, then E hands over exactly what the wipe
	# took (the binoculars) and never a second notebook, because an item the drone carries
	# is left alone.
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	for i in 3:
		await physics_frame
	var kit_again: bool = kit.use_for_test(player)
	_close_story(main)
	var binoculars_back: bool = inv.has_item("binoculars")
	var notebook_slot: int = inv.slots.find("notebook")
	var one_notebook: bool = notebook_slot >= 0 and int(inv.counts[notebook_slot]) == 1

	# The sword: taken from the cape, back on it. Found through the group rather than by
	# node name, so "the katana" means whatever the world is actually holding.
	var sword: Node3D = null
	for node in get_nodes_in_group("pickup"):
		if str(node.get("item_id")) == "sword":
			sword = node
			break
	# A world with no sword in it is a failure, not a silent skip: `sword != null` is part of
	# the pass condition below.
	var sword_home: Vector3 = Vector3.ZERO
	var sword_back := false
	var sword_takeable_again := false
	if sword != null:
		sword_home = sword.global_position
		sword._on_body_entered(player)          # the way walking into it collects it
		_close_story(main)                      # ...and it plays the katana page
	player.damage(999.0)
	for i in 60:
		await physics_frame
	player._restart()
	for i in 60:
		await physics_frame
	if sword != null:
		sword_back = sword.visible and sword.global_position.distance_to(sword_home) < 0.01
		sword_takeable_again = not player.has_item("sword")
		sword._on_body_entered(player)          # the real proof: it can be picked up again
		_close_story(main)
		sword_takeable_again = sword_takeable_again and player.has_item("sword")

	# The boat: sailed out to open water and left there **with the drone aboard** (dying at
	# sea is how a hull gets left), it is back on its mooring, bow out to sea, deck empty.
	var boat: Node3D = get_nodes_in_group("boat")[0]
	var mooring: Vector3 = boat.mooring()
	var mooring_yaw: float = boat.rotation.y
	boat.global_position = Vector3(-120.0, 0.0, 300.0)   # open water between the islands
	boat.rotation.y = 0.9
	boat.board_for_test(player)
	for i in 5:
		await physics_frame
	var sailed_away: bool = boat.global_position.distance_to(mooring) > 100.0
	player.damage(999.0)
	for i in 60:
		await physics_frame
	player._restart()
	for i in 60:
		await physics_frame
	var boat_home: bool = boat.global_position.distance_to(mooring) < 0.5
	var bow_out_to_sea: bool = absf(angle_difference(boat.rotation.y, mooring_yaw)) < 0.01
	var deck_empty: bool = not player.in_boat() and boat.driver() == null
	# ...and the drone stays where it respawned. While a boat has a driver it pins the drone
	# to its deck every physics frame, so a boat left driving would drag the respawned drone
	# straight back out to sea — the reason `respawn()` lets the driver go, not just moves.
	var pos_after: Vector3 = player.global_position
	var still_at_spawn: bool = Vector2(pos_after.x, pos_after.z).distance_to(Vector2(-112.0, 82.0)) < 3.0

	print("RESULT stayed_dead=%s label_shown=%s after_esc pos=%s floor=%s at_spawn=%s bare_start=%s bare_after_death=%s opened=%s found_kit=%s wiped=%s keeps_notes=%s keeps_kit=%s loot_gone=%s fists=%s kit_back=%s bag_off=%s kit_again=%s binoculars_back=%s one_notebook=%s sailed_away=%s boat_home=%s bow_out=%s deck_empty=%s at_spawn_after_sailing=%s sword_back=%s sword_again=%s" % [
		still_dead, label_visible, pos, player.is_on_floor(), near_spawn,
		starts_bare, bare_after_death, opened, found_kit, notes_wiped,
		keeps_notes, keeps_kit, loot_gone, back_to_fists,
		kit_back, bag_off, kit_again, binoculars_back, one_notebook,
		sailed_away, boat_home, bow_out_to_sea, deck_empty, still_at_spawn,
		sword_back, sword_takeable_again])
	quit(0 if (still_dead and label_visible and near_spawn and player.is_on_floor()
			and starts_bare and bare_after_death and opened and found_kit
			and notes_wiped and keeps_notes and keeps_kit and loot_gone
			and back_to_fists and kit_back and bag_off and kit_again
			and binoculars_back and one_notebook and sword != null
			and sailed_away and boat_home and bow_out_to_sea and deck_empty
			and still_at_spawn and sword_back and sword_takeable_again) else 1)