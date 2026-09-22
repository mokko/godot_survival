extends SceneTree
## Headless check: the pause menu has ONE save entry (Saves…, the list — no blind
## one-click write), saving through it writes the run's state into the file the
## player picked; Quit returns to the splash (main menu).
## Puts the machine's saves back via tests/save_guard.gd (it writes a slot).

const SaveGuard := preload("res://tests/save_guard.gd")

func _init() -> void:
	var guard := SaveGuard.new()
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

	# One entry, and it is the list: the button that wrote into the run's slot
	# without asking is gone, node and toast alike.
	var one_entry: bool = menu.get_node_or_null("Center/Padding/Panel/VBox/Save") == null \
			and menu.get_node_or_null("SaveLabel") == null
	var saves_btn: Button = menu.get_node_or_null("Center/Padding/Panel/VBox/SavesButton")
	var ok_one_entry: bool = one_entry and saves_btn != null and saves_btn.text == "Saves…"

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

	# Picking a file is the whole point: press slot 3's row and the run lands there.
	var row: Button = screen.slot_button(3)
	var ok_row: bool = row != null
	if ok_row:
		row.pressed.emit()          # first press on a filled row only arms it
		row.pressed.emit()
		await process_frame
	var data := SaveGame.read_slot(3)
	var ok_save: bool = not data.is_empty() and int(data.get("sunbulbs", -1)) == 7 \
					and absf(float(data.get("life", -1.0)) - 55.0) < 0.01 \
					and data.get("pos", []).size() == 3

	screen.close()
	await process_frame
	ok_saves = ok_saves and menu.menu.visible

	# Quit: changes scene back to the splash and unpauses.
	menu._on_quit_to_menu()
	for i in 10:
		await process_frame
	var ok_quit: bool = current_scene != null \
			and current_scene.name == "Splash" and not tree.paused

	guard.restore()

	print("RESULT save=%s quit=%s saves_screen=%s one_entry=%s row=%s" % [ok_save, ok_quit, ok_saves, ok_one_entry, ok_row])
	quit(0 if (ok_save and ok_quit and ok_saves and ok_one_entry and ok_row) else 1)
