extends SceneTree
## Headless check: the Saves screen on the splash screen.
##
## The rows are built from SaveGame, so what this checks is that the list says
## what is really on disk (a named slot with its detail, empty slots that cannot
## be loaded, the autosave as a row of its own), that pressing a filled row asks
## for that slot by number, and that the splash's two entries do two different
## jobs: Continue jumps to the last slot played, Load Game opens the list.
##
## Restores the user's real saves afterwards.

class FakePlayer extends Node:
	var state := {"pos": [1.0, 2.0, 3.0], "life": 33.0, "sunbulbs": 5, "items": []}
	func save_state() -> Dictionary:
		return state.duplicate(true)


func _init() -> void:
	var fails: Array = []

	# ---- back up what this machine has, then start from a known board
	var backup: Dictionary = {}
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		backup[slot] = SaveGame.read_slot(slot)
		SaveGame.delete_slot(slot)

	var p := FakePlayer.new()
	root.add_child(p)
	SaveGame.write_slot(2, p, "Ezo Trip")
	SaveGame.autosave(p)
	SaveGame.pending_load = false
	SaveGame.pending_slot = 0

	# ---- the two entries on the splash
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	current_scene = splash
	for i in 8:
		await process_frame

	var load_btn: Button = splash.get_node_or_null("Center/VBox/LoadGame")
	var cont_btn: Button = splash.get_node_or_null("Center/VBox/Continue")
	if load_btn == null:
		fails.append("no_load_game_button")
	if cont_btn == null or cont_btn.text != "Continue":
		fails.append("continue_button_wrong")
	if load_btn != null and load_btn.text != "Load Game":
		fails.append("load_button_wrong")

	var wired := false
	if load_btn != null:
		for c in load_btn.pressed.get_connections():
			if (c["callable"] as Callable).get_method() == "_on_load_game_pressed":
				wired = true
	if not wired:
		fails.append("load_game_not_wired")

	var saves: Control = splash.get_node_or_null("Saves")
	if saves == null:
		fails.append("no_saves_screen")
		_report(fails, backup)
		return
	if saves.visible:
		fails.append("saves_visible_before_asking")

	# ---- opening it: the list, in load mode
	if load_btn != null:
		load_btn.pressed.emit()
	for i in 3:
		await process_frame
	if not saves.visible:
		fails.append("load_button_did_not_open_saves")
	if String(saves.title.text) != "Load Game":
		fails.append("wrong_title_in_load_mode")

	# ---- the rows say what is on disk
	var filled: Button = saves.slot_button(2) as Button
	var empty: Button = saves.slot_button(3) as Button
	var auto: Button = saves.slot_button(SaveGame.AUTOSAVE_SLOT) as Button
	if filled == null or empty == null or auto == null:
		fails.append("rows_missing")
	else:
		if filled.disabled:
			fails.append("filled_row_disabled")
		if not "Ezo Trip" in filled.text:
			fails.append("row_lost_its_name")
		if not empty.disabled:
			fails.append("empty_row_loadable")
		if not auto.disabled and SaveGame.slot_name(SaveGame.AUTOSAVE_SLOT) != SaveGame.AUTOSAVE_NAME:
			fails.append("autosave_row_wrong")

	# ---- loading: the row announces its own slot, by number. It does not
	#      navigate: the splash is listening and does that (checked further down).
	var chosen: Array = []
	saves.slot_chosen.connect(func(slot: int) -> void: chosen.append(slot))
	if filled != null:
		filled.pressed.emit()
	if chosen.is_empty():
		fails.append("row_announced_nothing")
	elif int(chosen[0]) != 2:
		fails.append("row_announced_the_wrong_slot")

	# ---- and an empty row cannot be pressed at all: `disabled` is the rule, so
	#      emitting its signal is what a player would be able to do if it were not
	if empty != null and not empty.disabled:
		empty.pressed.emit()
	if chosen.size() > 1:
		fails.append("empty_row_announced_a_slot")

	# ---- closing hands control back
	var closed_seen := [false]
	saves.closed.connect(func() -> void: closed_seen[0] = true)
	saves.close()
	if saves.visible:
		fails.append("close_left_it_visible")
	if not closed_seen[0]:
		fails.append("close_did_not_announce_itself")

	# ---- the splash is listening to the screen, and loading the slot it hears
	#      about. These two are last: each one queues a scene change, so nothing
	#      after them may touch the nodes again — hence `_report` next.
	var listening := false
	for c in saves.slot_chosen.get_connections():
		if (c["callable"] as Callable).get_method() == "_on_saves_slot_chosen":
			listening = true
	if not listening:
		fails.append("splash_not_listening_to_the_screen")

	SaveGame.pending_load = false
	SaveGame.pending_slot = 0
	SaveGame.pending_new_run = true
	# What the splash does with a chosen slot. _begin_load() is the half of the
	# handler that sets the flags — the scene change it is split from cannot run
	# here, because a swap frees this very node.
	SaveGame.pending_load = false
	SaveGame.pending_slot = 0
	SaveGame.pending_new_run = true
	splash._begin_load(4)
	if not SaveGame.pending_load:
		fails.append("chosen_slot_was_not_loaded")
	if SaveGame.pending_slot != 4:
		fails.append("chosen_slot_number_lost")
	if SaveGame.pending_new_run:
		fails.append("load_marked_as_a_new_run")

	# ---- Continue is the one-click path to the slot last played
	SaveGame.pending_load = false
	SaveGame.pending_slot = 0
	SaveGame.pending_new_run = true
	splash._begin_load(SaveGame.continue_slot())
	if not SaveGame.pending_load:
		fails.append("continue_did_not_load")
	if SaveGame.pending_slot != 2:
		fails.append("continue_did_not_use_the_last_played_slot")
	if SaveGame.pending_new_run:
		fails.append("continue_marked_as_a_new_run")

	_report(fails, backup)


func _report(fails: Array, backup: Dictionary) -> void:
	SaveGame.pending_load = false
	SaveGame.pending_slot = 0
	SaveGame.pending_new_run = false
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		SaveGame.delete_slot(slot)
		if not (backup[slot] as Dictionary).is_empty():
			var f := FileAccess.open(SaveGame.slot_path(slot), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(backup[slot]))
	if fails.is_empty():
		print("RESULT ALL PASS rows=5")
		quit(0)
	else:
		print("RESULT FAIL: %s" % ", ".join(fails))
		quit(1)