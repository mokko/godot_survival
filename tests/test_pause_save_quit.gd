extends SceneTree
## Headless check: Save in the pause menu writes the run's slot with
## position/orbs/life; Quit returns to the splash (main menu).

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
	# The pause menu saves into the run's own slot (SaveGame.current_slot), which
	# for a run that was never saved before is slot 1.
	var slot: int = SaveGame.current_slot if SaveGame.current_slot > 0 else SaveGame.DEFAULT_SLOT
	var data := SaveGame.read_slot(slot)
	var ok_save: bool = not data.is_empty() and int(data.get("sunbulbs", -1)) == 7 \
				and absf(float(data.get("life", -1.0)) - 55.0) < 0.01 \
				and data.get("pos", []).size() == 3

	# Saves… opens the screen in save mode, holding this run to write, and gives
	# the menu back when it closes. ESC stays the menu's, so the screen is opened
	# with escape_closes = false.
	menu._on_saves()
	await process_frame
	var screen: Control = menu.get_node("Saves")
	var ok_saves: bool = screen.visible \
			and String(screen.title.text) == "Save Game" \
			and screen.player == player \
			and not bool(screen.escape_closes) \
			and not menu.menu.visible
	screen.close()
	await process_frame
	ok_saves = ok_saves and menu.menu.visible

	# Quit: changes scene back to the splash and unpauses.
	menu._on_quit_to_menu()
	for i in 10:
		await process_frame
	var ok_quit: bool = current_scene != null \
			and current_scene.name == "Splash" and not tree.paused

	print("RESULT save=%s quit=%s saves_screen=%s" % [ok_save, ok_quit, ok_saves])
	quit(0 if (ok_save and ok_quit and ok_saves) else 1)
