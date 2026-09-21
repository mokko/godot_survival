extends SceneTree
## Headless check: the five-slot savegame.
##
## Part 1 drives the slot API directly (no scene): five slots, names inside the
## file, independence, rename, delete, empty vs missing, and a corrupt slot not
## taking the list down.
##
## Part 2 drives a real run: the autosave clock rotating slot 5, and — the
## decision this whole change turns on — dying leaving the save on disk alone.
##
## Restores the user's real saves and index afterwards.

class FakePlayer extends Node:
	var state := {
		"pos": [1.0, 2.0, 3.0],
		"life": 40.0,
		"sunbulbs": 3,
		"items": [],
		"counts": [],
	}
	func save_state() -> Dictionary:
		return state.duplicate(true)


func _init() -> void:
	var fails: Array = []

	# ---- back up whatever this machine already has, so the test is repeatable
	var backup: Dictionary = {}
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		backup[slot] = SaveGame.read_slot(slot)
	var had_index := FileAccess.file_exists(SaveGame.INDEX_PATH)
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		SaveGame.delete_slot(slot)
	if FileAccess.file_exists(SaveGame.INDEX_PATH):
		DirAccess.remove_absolute(SaveGame.INDEX_PATH)

	# ---------------------------------------------------------------- part 1
	if SaveGame.has_any_save():
		fails.append("fresh_install_has_a_save")
	var rows: Array = SaveGame.list_slots()
	if rows.size() != 5:
		fails.append("not_five_slots")
	var empties := 0
	for row in rows:
		if bool(row["empty"]):
			empties += 1
	if empties != 5:
		fails.append("fresh_slots_not_empty")

	var p := FakePlayer.new()
	root.add_child(p)

	# A named save lands in its slot, with the name inside the file.
	SaveGame.write_slot(1, p, "First Expedition")
	if not SaveGame.exists(1):
		fails.append("slot1_missing")
	if SaveGame.slot_name(1) != "First Expedition":
		fails.append("slot1_name_lost")
	if absf(float(SaveGame.read_slot(1).get("life", -1.0)) - 40.0) > 0.01:
		fails.append("slot1_state_lost")

	# Names can be anything a player types — spaces and non-ASCII included.
	var fancy := "Reise nach Ezo — 北海道"
	SaveGame.write_slot(2, p, fancy)
	if SaveGame.slot_name(2) != fancy:
		fails.append("unicode_name_lost")

	# Slots are independent.
	p.state["life"] = 7.0
	SaveGame.write_slot(2, p, fancy)
	if absf(float(SaveGame.read_slot(1).get("life", -1.0)) - 40.0) > 0.01:
		fails.append("slot2_write_touched_slot1")

	# Saving over your own slot keeps its name; naming it changes only the name.
	SaveGame.write_slot(1, p)
	if SaveGame.slot_name(1) != "First Expedition":
		fails.append("overwrite_renamed_slot")
	SaveGame.rename_slot(1, "Renamed")
	if SaveGame.slot_name(1) != "Renamed":
		fails.append("rename_failed")
	if absf(float(SaveGame.read_slot(1).get("life", -1.0)) - 7.0) > 0.01:
		fails.append("rename_lost_state")

	# An emptied slot is valid and empty; a deleted one is simply gone.
	SaveGame.clear_slot(1)
	if SaveGame.exists(1):
		fails.append("cleared_slot_still_has_a_save")
	if SaveGame.slot_name(1) != "":
		fails.append("cleared_slot_keeps_a_name")
	SaveGame.delete_slot(2)
	if SaveGame.exists(2):
		fails.append("deleted_slot_still_exists")

	# A corrupt file is an empty slot, not a crash.
	var bad := FileAccess.open(SaveGame.slot_path(3), FileAccess.WRITE)
	if bad != null:
		bad.store_string("this is not json at all")
	if not SaveGame.read_slot(3).is_empty():
		fails.append("corrupt_slot_read_as_state")
	var rows2: Array = SaveGame.list_slots()
	if rows2.size() != 5:
		fails.append("corrupt_slot_broke_the_list")

	# The autosave is slot 5, named for itself, and loads like any other.
	SaveGame.autosave(p)
	if not SaveGame.exists(SaveGame.AUTOSAVE_SLOT):
		fails.append("autosave_missing")
	if SaveGame.slot_name(SaveGame.AUTOSAVE_SLOT) != SaveGame.AUTOSAVE_NAME:
		fails.append("autosave_name")
	if not SaveGame.is_autosave(5) or SaveGame.is_autosave(4):
		fails.append("autosave_slot_wrong")
	# Autosaving must not become "the slot you are playing".
	SaveGame.current_slot = 0
	SaveGame.autosave(p)
	if SaveGame.current_slot != 0:
		fails.append("autosave_claimed_current_slot")

	# Continue follows the slot you were *playing*, not the freshest file on disk:
	# write slot 2, then slot 1 (that is the one being played), then let the
	# autosave run — the autosave is newer, and must not hijack Continue.
	SaveGame.write_slot(2, p, "Older")
	SaveGame.write_slot(1, p, "Played")
	SaveGame.autosave(p)
	if SaveGame.most_recent_slot() != SaveGame.AUTOSAVE_SLOT:
		fails.append("most_recent_is_not_the_autosave")
	if SaveGame.continue_slot() != 1:
		fails.append("continue_not_last_played")

	# ---------------------------------------------------------------- part 2
	# A real run: the autosave clock, and death not touching the file.
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		SaveGame.delete_slot(slot)
	SaveGame.write_slot(1, p, "Before dying")
	var before := SaveGame.read_slot(1)

	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame
	var player: CharacterBody3D = main.get_node("Player")

	# The autosave clock: wind it to the interval and let one frame pass.
	var clocked := false
	if player.get("_autosave_clock") != null:
		player.set("_autosave_clock", SaveGame.AUTOSAVE_SECONDS)
		await physics_frame
		clocked = SaveGame.exists(SaveGame.AUTOSAVE_SLOT)
	if not clocked:
		fails.append("autosave_clock_did_not_fire")
	if player.get("_autosave_clock") == null or float(player.get("_autosave_clock")) >= SaveGame.AUTOSAVE_SECONDS:
		fails.append("autosave_clock_not_reset")

	# Dying: the run is over, the save is not.
	player.life = 0.0
	player._trigger_game_over()
	await physics_frame
	if not SaveGame.exists(1):
		fails.append("death_wiped_the_save")
	var after := SaveGame.read_slot(1)
	if String(after.get("name", "")) != String(before.get("name", "")) \
			or int(after.get("saved_at", 0)) != int(before.get("saved_at", 0)):
		fails.append("death_rewrote_the_save")

	# ---- put the machine back the way it was
	main.queue_free()
	for slot in range(1, SaveGame.MAX_SLOT + 1):
		SaveGame.delete_slot(slot)
		if not (backup[slot] as Dictionary).is_empty():
			var f := FileAccess.open(SaveGame.slot_path(slot), FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(backup[slot]))
	if not had_index and FileAccess.file_exists(SaveGame.INDEX_PATH):
		DirAccess.remove_absolute(SaveGame.INDEX_PATH)

	if fails.is_empty():
		print("RESULT ALL PASS slots=5")
		quit(0)
	else:
		print("RESULT FAIL: %s" % ", ".join(fails))
		quit(1)
