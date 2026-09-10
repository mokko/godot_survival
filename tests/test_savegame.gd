extends SceneTree
## Headless check for the save/load flow:
## 1. SaveGame.write/read roundtrip preserves life/orbs/pos.
## 2. Splash shows Continue only when a save exists.
## 3. Continue path: pending_load flag makes the player restore state in _ready.

const SAVEGAME := preload("res://world/savegame.gd")

func _init() -> void:
	# Clean slate: remove any save from previous runs.
	DirAccess.open("user://").remove("savegame.json")

	# -- Part A: no save -> splash hides Continue.
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	var hidden_ok: bool = splash.get_node("Center/VBox/Continue").visible == false
	splash.free()

	# -- Part B: write a save from a player instance, roundtrip it.
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	root.add_child(player)
	await physics_frame
	player.life = 33.0
	player.orbs_collected = 5
	var Island := load("res://world/island.gd")
	player.global_position = Island.spawn_point() + Vector3(0.0, 0.5, 0.0)
	var save_ok: bool = SAVEGAME.write(player)
	var data := SAVEGAME.read()
	var roundtrip_ok: bool = save_ok \
			and absf(float(data.get("life", -1.0)) - 33.0) < 0.01 \
			and int(data.get("orbs", -1)) == 5 \
			and data.get("pos", []).size() == 3

	# -- Part C: save exists -> splash shows Continue.
	var splash2 = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash2)
	await process_frame
	var visible_ok: bool = splash2.get_node("Center/VBox/Continue").visible == true
	splash2.free()

	# -- Part D: Continue flow — pending_load flag -> player restores state.
	SAVEGAME.pending_load = true
	var saved_pos: Vector3 = player.global_position
	player.free()
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var p2: CharacterBody3D = main.get_node("Player")
	# life drains 1/s, so restored 33.0 shows up as just under 33 — but never
	# as the fresh-start 40. Orbs never drain and prove the restore too.
	var load_ok: bool = p2.life < 39.0 and p2.life > 31.0 \
			and p2.orbs_collected == 5 \
			and p2.global_position.distance_to(saved_pos) < 0.5 \
			and SAVEGAME.pending_load == false

	print("RESULT hidden=%s save=%s visible=%s load=%s" % [hidden_ok, roundtrip_ok, visible_ok, load_ok])
	# Clean up: don't leave a bogus save in the user's game dir.
	DirAccess.open("user://").remove("savegame.json")
	quit(0 if (hidden_ok and roundtrip_ok and visible_ok and load_ok) else 1)