extends SceneTree
## Headless check: Save in the pause menu writes user://savegame.json with
## position/orbs/life; Quit emits quit_to_menu (main scene wiring swaps to
## the splash).

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var player: CharacterBody3D = main.get_node("Player")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var tree := self

	# Give the player known state to save.
	player.sunbulbs_collected = 7
	player.life = 55.0

	menu._on_save()
	for i in 3:
		await process_frame
	var f := FileAccess.open("user://savegame.json", FileAccess.READ)
	var ok_save := false
	if f != null:
		var data = JSON.parse_string(f.get_as_text())
		ok_save = data != null and int(data.get("sunbulbs", -1)) == 7 \
				and absf(float(data.get("life", -1.0)) - 55.0) < 0.01 \
				and data.get("pos", []).size() == 3

	# Quit: signal fires and unpauses (handler on main will change scene).
	var quit_fired := [false]
	menu.quit_to_menu.connect(func(): quit_fired[0] = true)
	menu._on_quit()
	for i in 3:
		await process_frame
	var ok_quit: bool = quit_fired[0] and not tree.paused

	print("RESULT save=%s quit=%s" % [ok_save, ok_quit])
	quit(0 if (ok_save and ok_quit) else 1)
