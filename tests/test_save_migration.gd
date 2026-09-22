extends SceneTree
## Headless check: a savefile left behind by an earlier install is adopted once, at
## startup, and only when it really is one of ours.
##
## A snap refresh hands out a new XDG_DATA_HOME (`godot-4/34`, not `godot-4/30`) and a
## rename changes the folder name, so the save the player made an hour ago sits in a
## directory the engine will never look at again. world/savegame.gd:adopt_legacy_save()
## copies the newest valid one it can find into the current location; this test drives
## it with an explicit list of roots, so nothing here depends on the real filesystem
## layout, and then checks the rules that keep it safe:
##
##  - a real save is adopted, content and all, and the original is left where it was;
##  - junk, another project's savegame.json, and an empty-named file are all ignored;
##  - an install that already has a save never adopts anything.
##
## The live save slots are wiped for the run and put back by tests/save_guard.gd:
## "an install that already has a save never adopts anything" needs an install that
## does not, and the player's own slots are not this test's to assume away.

const SaveGame := preload("res://world/savegame.gd")
const SaveGuard := preload("res://tests/save_guard.gd")

const ROOT := "user://migration_test"


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _cleanup() -> void:
	var d := DirAccess.open(ROOT)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_recursive(ROOT.path_join(sub))
	DirAccess.remove_absolute(ROOT)


func _remove_recursive(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_recursive(path.path_join(sub))
	for file in d.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _init() -> void:
	var fails: PackedStringArray = []
	# The live saves are the player's: snapshot them, and empty the slots so this
	# test's "nothing to adopt" case really is nothing. Without the wipe it passed
	# only on an install that had never saved anything.
	var guard := SaveGuard.new()
	guard.wipe()

	_cleanup()
	var ours := ROOT.path_join("34/app_userdata/Nakamoto's Paradigm")
	var older := ROOT.path_join("30/app_userdata/Survival M")
	var stranger := ROOT.path_join("34/app_userdata/3D survival")
	var junk := ROOT.path_join("34/app_userdata/Broken")
	_write(ours.path_join("savegame.json"), "{\"life\": 1.0}")
	# get_modified_time() counts whole seconds, so two files written in the same second
	# tie — and on a tie the first root in the list wins. Space them, so that "the
	# newest one wins" is what this case actually tests.
	OS.delay_msec(1100)
	_write(older.path_join("savegame.json"), "{\"pos\": [3.0, 4.0, 5.0], \"life\": 7.0}")
	_write(stranger.path_join("savegame.json"), "{\"score\": 12, \"level\": 3}")
	_write(junk.path_join("savegame.json"), "this is not json at all")

	var roots := [junk, stranger, ours, older]

	# 1. With a save already in place, nothing is adopted.
	_write(SaveGame.SAVE_PATH, "{\"life\": 42.0}")
	if SaveGame.adopt_legacy_save(roots) != "":
		fails.append("adopted_over_an_existing_save")
	if absf(float(SaveGame.read().get("life", 0.0)) - 42.0) > 0.01:
		fails.append("existing_save_was_modified")
	DirAccess.remove_absolute(SaveGame.SAVE_PATH)

	# 2. With none, the newest valid one of ours is taken — not the stranger's, not the
	#    junk — and the file it came from is left alone.
	var adopted: String = SaveGame.adopt_legacy_save(roots)
	if adopted != older.path_join("savegame.json"):
		fails.append("adopted_" + adopted)
	if not FileAccess.file_exists(adopted):
		fails.append("original_was_moved_or_deleted")
	var restored := SaveGame.read()
	if absf(float(restored.get("life", 0.0)) - 7.0) > 0.01:
		fails.append("adopted_content_wrong:life=%.1f" % float(restored.get("life", 0.0)))
	if not (restored.get("pos", []) as Array).has(3.0):
		fails.append("adopted_content_missing_pos")

	# 3. Nothing to adopt: a bare root is a quiet no-op, and no file appears.
	DirAccess.remove_absolute(SaveGame.SAVE_PATH)
	if SaveGame.adopt_legacy_save([ROOT.path_join("empty_place")]) != "":
		fails.append("adopted_from_nowhere")
	if SaveGame.exists():
		fails.append("wrote_a_save_with_nothing_to_adopt")

	# 4. The ancestor walk finds a sibling revision without being told where to look.
	#    This is the real path: <here>/../<other revision>/app_userdata/*.
	var here := OS.get_user_data_dir()
	var revision := here.get_base_dir().get_base_dir().get_base_dir()
	var sibling_root := revision.get_base_dir().path_join("sibling_probe")
	_write(sibling_root.path_join("app_userdata/Nakamoto/savegame.json"),
			"{\"pos\": [9.0, 0.0, 9.0]}")
	var found: Array = SaveGame.legacy_roots()
	var wanted := sibling_root.path_join("app_userdata/Nakamoto")
	if not found.has(wanted):
		fails.append("ancestor_walk_missed_" + wanted)
	_remove_recursive(sibling_root)

	_cleanup()
	guard.restore()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)