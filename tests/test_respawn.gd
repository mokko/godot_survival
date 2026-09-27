extends SceneTree
## Headless check: player dies -> game-over screen shows and STAYS, player
## stays dead (no auto-regen). The ESC restart path respawns at spawn point.
## Also: what a run starts with (nothing — the katana and the survey gear are found
## in the world), that the death wipe takes loot but not the drone's own notes, and
## that the keepsakes only come back for a drone that has actually held them.

const SaveGame := preload("res://world/savegame.gd")


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
	# Die empty-handed, without ever having reached the crate.
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
	# started with, and the crate is still out there waiting.
	var bare_after_death: bool = _counting_slots(inv) == 0 and player.get_equipped_item() == ""

	# Now go and open the crate the way the player does, then die again. The survey
	# is a keepsake from this point on: the death wipe takes loot, not the drone's
	# own record of the island and the instruments that fill it.
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	var opened: bool = kit.use_for_test(player)
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
	print("RESULT stayed_dead=%s label_shown=%s after_esc pos=%s floor=%s at_spawn=%s bare_start=%s bare_after_death=%s opened=%s found_kit=%s wiped=%s keeps_notes=%s keeps_kit=%s loot_gone=%s fists=%s" % [
		still_dead, label_visible, pos, player.is_on_floor(), near_spawn,
		starts_bare, bare_after_death, opened, found_kit, notes_wiped,
		keeps_notes, keeps_kit, loot_gone, back_to_fists])
	quit(0 if (still_dead and label_visible and near_spawn and player.is_on_floor()
			and starts_bare and bare_after_death and opened and found_kit
			and notes_wiped and keeps_notes and keeps_kit and loot_gone
			and back_to_fists) else 1)