extends SceneTree
## Headless check for the save/load flow:
## 1. SaveGame.write/read roundtrip preserves life/orbs/pos.
## 2. Splash shows Load Game whether or not a save exists (it always has).
## 3. Load Game path: the Saves screen's row sets pending_load, and the player
##    restores that slot in _ready — no intro story on the way in.

const SaveGuard := preload("res://tests/save_guard.gd")
const SAVEGAME := preload("res://world/savegame.gd")

func _init() -> void:
	# The machine's saves are the player's: snapshot them, and write nothing into
	# them that outlives this run.
	var guard := SaveGuard.new()

	# -- Part A: no save -> Load Game is still visible (always shown).
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	var hidden_ok: bool = splash.get_node("Center/VBox/LoadGame").visible == true
	splash.free()

	# -- Part B: write a save from a player instance, roundtrip it.
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	player.life = 33.0
	player.sunbulbs_collected = 5
	var Island := load("res://world/island.gd")
	player.global_position = Island.spawn_point() + Vector3(0.0, 0.5, 0.0)
	var save_ok: bool = SAVEGAME.write(player)
	var data := SAVEGAME.read()
	var roundtrip_ok: bool = save_ok \
			and absf(float(data.get("life", -1.0)) - 33.0) < 0.01 \
			and int(data.get("sunbulbs", -1)) == 5 \
			and data.get("pos", []).size() == 3

	# -- Part B2: armor must restore even when there is no inventory in the
	# tree. The restore used to sit inside the inventory null-guard, so a
	# player whose HUD was not resolvable silently lost its armor on load.
	var standalone_ok: bool = player.inventory == null
	player.load_state({"life": 30.0, "armor": "leather_armor",
			"armor_durability": 42.0})
	var armor_state: Dictionary = player.armor_status()
	var armor_ok: bool = standalone_ok and armor_state["id"] == "leather_armor" \
			and absf(float(armor_state["durability"]) - 42.0) < 0.01

	# -- Part C: save exists -> Load Game still visible (always shown).
	var splash2 = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash2)
	await process_frame
	var visible_ok: bool = splash2.get_node("Center/VBox/LoadGame").visible == true
	splash2.free()

	# -- Part D: load flow — pending_load flag -> player restores state.
	SAVEGAME.pending_load = true
	var saved_pos: Vector3 = player.global_position
	player.free()
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var p2: CharacterBody3D = main.get_node("Player")
	# Energy drains while we sit here, so restored 33.0 shows up as just under
	# 33 — but never as the fresh-start 40. Orbs never drain and prove the
	# restore too.
	# Position: compare horizontally; the save carries a +0.5 landing clearance.
	var dxz := Vector2(p2.global_position.x, p2.global_position.z).distance_to(
			Vector2(saved_pos.x, saved_pos.z))
	var load_ok: bool = p2.life < 39.0 and p2.life > 31.0 \
			and p2.sunbulbs_collected == 5 \
			and dxz < 1.0 \
			and SAVEGAME.pending_load == false

	# -- Part E: time of day rides along in the save. The sun lives on the
	# DayCycle node, so a save taken at dusk must come back at dusk.
	var cycle = main.get_node("DayCycle")
	cycle.time_of_day = 0.62          # just past sunset
	SAVEGAME.write(p2)
	var data2 := SAVEGAME.read()
	var tod_saved: bool = absf(float(data2.get("time_of_day", -1.0)) - 0.62) < 0.001
	cycle.time_of_day = 0.1           # knock it back to mid-morning
	p2.load_state(data2)
	var tod_restored: bool = absf(cycle.time_of_day - 0.62) < 0.001
	# ...and an old save without the key must not blow up the load.
	var legacy_ok := true
	p2.load_state({"life": 20.0, "pos": [0.0, 5.0, 0.0]})
	legacy_ok = absf(float(p2.life) - 20.0) < 0.01

	# -- Part F: "Load Game" skips the story screen — only a fresh run plays
	# the intro. It must land straight in the world.
	current_scene = null
	main.free()
	var splash3 = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash3)
	current_scene = splash3
	await process_frame
	# The real path, not a private shortcut: Load Game opens the Saves screen,
	# then the row for the slot last played is pressed. That row is the one
	# Continue used to open, so this is the old one-click resume in two clicks.
	splash3._on_load_game_pressed()
	await process_frame
	var row: Button = splash3.saves.slot_button(SAVEGAME.continue_slot())
	var row_ok: bool = row != null and not row.disabled
	if row_ok:
		row.pressed.emit()
	var landed := ""
	for i in 900:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			landed = "Main"
			break
		if current_scene != null and current_scene.name == "Story":
			landed = "Story"
			break
	var skips_story: bool = landed == "Main"

	print("RESULT hidden=%s save=%s visible=%s load=%s standalone=%s armor=%s tod_saved=%s tod_restored=%s legacy=%s row=%s skips_story=%s"
			% [hidden_ok, roundtrip_ok, visible_ok, load_ok, standalone_ok,
			armor_ok, tod_saved, tod_restored, legacy_ok, row_ok, skips_story])
	# Put the machine's saves back.
	guard.restore()
	quit(0 if (hidden_ok and roundtrip_ok and visible_ok and load_ok
			and armor_ok and tod_saved and tod_restored and legacy_ok
			and row_ok and skips_story) else 1)