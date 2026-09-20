extends SceneTree
## Headless check: player dies -> game-over screen shows and STAYS, player
## stays dead (no auto-regen). The ESC restart path respawns at spawn point.
## Also: the loadout a fresh run starts with — the katana in hand and the Pedia
## notebook carried — and the fact that the death wipe takes loot but not the
## drone's own notes.

const SaveGame := preload("res://world/savegame.gd")


func _init() -> void:
	# A fresh run: the player hands out STARTING_ITEMS in its _ready. Without
	# this flag the scene starts with an empty inventory (tests load main.tscn
	# directly, skipping the splash that sets it).
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	for i in 60:
		await physics_frame
	var starts_with_kit: bool = inv.has_item("notebook") and inv.has_item("pen") \
			and inv.has_item("magnifying_glass") and inv.has_item("binoculars")
	var starts_with_katana: bool = player.get_equipped_item() == "sword"
	# Move away and kill.
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
	# The survey survives (notebook, pen, glass); ordinary gear does not.
	var keeps_notes: bool = inv.has_item("notebook")
	var keeps_kit: bool = inv.has_item("pen") and inv.has_item("magnifying_glass")
	var loot_gone: bool = not inv.has_item("binoculars")
	var back_to_fists: bool = player.get_equipped_item() == ""
	print("RESULT stayed_dead=%s label_shown=%s after_esc pos=%s floor=%s at_spawn=%s kit=%s katana=%s wiped=%s keeps_notes=%s keeps_kit=%s loot_gone=%s fists=%s" % [
		still_dead, label_visible, pos, player.is_on_floor(), near_spawn,
		starts_with_kit, starts_with_katana, notes_wiped,
		keeps_notes, keeps_kit, loot_gone, back_to_fists])
	quit(0 if (still_dead and label_visible and near_spawn and player.is_on_floor()
			and starts_with_kit and starts_with_katana
			and notes_wiped and keeps_notes and keeps_kit and loot_gone
			and back_to_fists) else 1)
