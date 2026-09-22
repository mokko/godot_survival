extends SceneTree
## Headless check: the Saves screen in **save** mode.
##
## Save mode is where a save can be lost, so what this checks is the guard rails:
## a slot the player names, overwriting that takes two presses and says so before
## the second, a rename that does not quietly replace an old save with the current
## run, a delete that also takes two presses, and the autosave row that cannot be
## written by hand. Plus the ESC rule: this screen answers ESC only when its
## opener says it may (the pause menu keeps that key for itself).
##
## Restores the user's real saves afterwards.

class FakePlayer extends Node:
	var state := {"pos": [1.0, 2.0, 3.0], "life": 21.0, "sunbulbs": 2, "items": []}
	func save_state() -> Dictionary:
		return state.duplicate(true)


func _init() -> void:
	var fails: Array = []

	var backup: Dictionary = {}
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		backup[slot] = SaveGame.read_slot(slot)
		SaveGame.delete_slot(slot)

	var p := FakePlayer.new()
	root.add_child(p)

	var screen = load("res://ui/saves.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	for i in 3:
		await process_frame

	# ---- it opens for saving, with a name field and a delete on every row
	screen.player = p
	screen.open_for_save()
	await process_frame
	if String(screen.title.text) != "Save Game":
		fails.append("wrong_title_in_save_mode")
	if screen.slot_field(1) == null or screen.slot_delete(1) == null:
		fails.append("no_name_field_or_delete")
	if not screen.slot_button(SaveGame.AUTOSAVE_SLOT).disabled:
		fails.append("autosave_row_writable_by_hand")

	# ---- naming a new save: what is in the field is what the slot is called
	var field_one: LineEdit = screen.slot_field(1) as LineEdit
	if field_one != null:
		field_one.text = "Nordkap"
	screen.slot_button(1).pressed.emit()
	if not SaveGame.exists(1):
		fails.append("save_wrote_nothing")
	if SaveGame.slot_name(1) != "Nordkap":
		fails.append("save_ignored_the_name_field")
	var named := SaveGame.read_slot(1)
	if absf(float(named.get("life", -1.0)) - 21.0) > 0.01:
		fails.append("save_lost_the_state")

	# ---- overwriting takes two presses, and the first one changes nothing
	var stamped: int = int(SaveGame.read_slot(1).get("saved_at", 0))
	screen.slot_button(1).pressed.emit()
	var after_arming := SaveGame.read_slot(1)
	if int(after_arming.get("saved_at", 0)) != stamped:
		fails.append("arming_overwrite_wrote_already")
	if not "overwrite" in String(screen.hint.text):
		fails.append("arming_overwrite_says_nothing")
	p.state["life"] = 9.0
	if screen.slot_field(1) != null:
		screen.slot_field(1).text = "Nordkap II"
	screen.slot_button(1).pressed.emit()
	var overwritten := SaveGame.read_slot(1)
	if absf(float(overwritten.get("life", -1.0)) - 9.0) > 0.01:
		fails.append("second_press_did_not_write")
	if SaveGame.slot_name(1) != "Nordkap II":
		fails.append("overwrite_ignored_the_new_name")

	# ---- a rename changes the name only: not the state, not the timestamp
	var before_rename := SaveGame.read_slot(1)
	screen._on_name_submitted(1, "Renamed Only")
	var after_rename := SaveGame.read_slot(1)
	if SaveGame.slot_name(1) != "Renamed Only":
		fails.append("rename_did_not_take")
	if int(after_rename.get("saved_at", 0)) != int(before_rename.get("saved_at", 0)) \
			or absf(float(after_rename.get("life", -1.0)) - float(before_rename.get("life", -1.0))) > 0.01:
		fails.append("rename_rewrote_the_save")

	# ---- and it does not invent a save for an empty slot
	screen._on_name_submitted(4, "Nothing Here")
	if SaveGame.exists(4):
		fails.append("renaming_an_empty_slot_created_one")

	# ---- deleting takes two presses as well
	screen.slot_delete(1).pressed.emit()
	if not SaveGame.exists(1):
		fails.append("arming_delete_deleted_already")
	if not "sure" in String(screen.slot_delete(1).text):
		fails.append("arming_delete_says_nothing")
	screen.slot_delete(1).pressed.emit()
	if SaveGame.exists(1):
		fails.append("second_press_did_not_delete")

	# ---- the screen answers ESC only when its opener allows it
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen.escape_closes = false
	screen._unhandled_input(esc)
	if not screen.visible:
		fails.append("esc_closed_it_against_its_opener")
	screen.escape_closes = true
	screen._unhandled_input(esc)
	if screen.visible:
		fails.append("esc_did_not_close_it")

	# ---- switching to load mode takes the fields away again
	screen.open_for_load()
	await process_frame
	if screen.slot_field(1) != null:
		fails.append("load_mode_left_a_name_field")

	screen.queue_free()
	await process_frame

	for slot in range(1, SaveGame.MAX_SLOT + 1):
		SaveGame.delete_slot(slot)
		if not (backup[slot] as Dictionary).is_empty():
			var f := FileAccess.open(SaveGame.slot_path(slot), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(backup[slot]))
	if fails.is_empty():
		print("RESULT ALL PASS save_mode")
		quit(0)
	else:
		print("RESULT FAIL: %s" % ", ".join(fails))
		quit(1)