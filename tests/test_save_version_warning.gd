extends SceneTree
## Headless check: a save written by a different version of the game is flagged **before** it is
## loaded — on its own row, where the player is reading, and in one sentence on the screen that
## names both versions so they can judge for themselves.
##
## A save written by this build must stay completely quiet: the ordinary case is every save
## matching, and a warning that fires on everything is one nobody reads.
##
## The machine's real saves are snapshotted and put back with tests/save_guard.gd.

const SaveGuard := preload("res://tests/save_guard.gd")
const SAVEGAME := preload("res://world/savegame.gd")


class FakePlayer extends Node:
	var state := {"pos": [1.0, 2.0, 3.0], "life": 33.0, "sunbulbs": 5, "items": []}
	func save_state() -> Dictionary:
		return state.duplicate(true)


func _write_foreign(slot: int, version: String) -> void:
	## Authored by hand on purpose: `write_slot()` stamps this build's own version, so the only
	## way to get a save from another build is to write one.
	var data := {
		"name": "From another build", "life": 12.0, "sunbulbs": 2,
		"saved_at": 1700000000, "slot": slot, "version": version, "pos": [1.0, 2.0, 3.0],
	}
	DirAccess.make_dir_recursive_absolute(SAVEGAME.SAVE_DIR)
	var f := FileAccess.open(SAVEGAME.slot_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _init() -> void:
	var fails: PackedStringArray = []
	var guard := SaveGuard.new()
	guard.wipe()
	var p := FakePlayer.new()
	root.add_child(p)

	# 1. A board with nothing on it warns about nothing.
	if SAVEGAME.version_warning(SAVEGAME.list_slots()) != "":
		fails.append("an empty board warned about versions")

	# 2. A save this build wrote says nothing at all — the ordinary case is quiet.
	SAVEGAME.write_slot(1, p, "This build")
	var mine: Dictionary = SAVEGAME.slot_summary(1)
	if SAVEGAME.from_other_version(mine):
		fails.append("a save this build wrote counts as another version")
	if SAVEGAME.version_warning(SAVEGAME.list_slots()) != "":
		fails.append("a save this build wrote raised the warning")
	if str(SAVEGAME.describe(mine)).contains("written by"):
		fails.append("a save this build wrote names a writer: '%s'" % SAVEGAME.describe(mine))

	# 3. A save from another version is flagged, on the row and in the sentence.
	_write_foreign(3, "0.0.1-alpha")
	var foreign: Dictionary = SAVEGAME.slot_summary(3)
	if not SAVEGAME.from_other_version(foreign):
		fails.append("a save from another version is not flagged")
	if SAVEGAME.saved_by(foreign) != "0.0.1-alpha":
		fails.append("the row does not carry the writer's version ('%s')"
				% SAVEGAME.saved_by(foreign))
	if not str(SAVEGAME.describe(foreign)).contains("written by 0.0.1-alpha"):
		fails.append("the row's detail does not say who wrote it: '%s'"
				% SAVEGAME.describe(foreign))
	var warning: String = SAVEGAME.version_warning(SAVEGAME.list_slots())
	if not warning.contains("0.0.1-alpha"):
		fails.append("the warning does not name the version that wrote the save: '%s'" % warning)
	if not warning.contains(SAVEGAME.build_version()):
		fails.append("the warning does not name this build: '%s'" % warning)
	if not warning.contains("may not restore"):
		fails.append("the warning does not say what might be wrong: '%s'" % warning)

	# 4. The screen carries it where the choice is made — and only when loading, because save
	#    mode restores nothing.
	var screen = load("res://ui/saves.tscn").instantiate()
	root.add_child(screen)
	for i in 2:
		await process_frame
	screen.open_for_load()
	for i in 2:
		await process_frame
	if not screen.version_warning().contains("0.0.1-alpha"):
		fails.append("the load screen does not warn: '%s'" % screen.version_warning())
	if not str(screen.hint.text).contains("0.0.1-alpha"):
		fails.append("the load screen's line does not carry it: '%s'" % screen.hint.text)
	if not str(screen.hint.text).contains("Which save"):
		fails.append("the warning replaced the question the screen asks: '%s'" % screen.hint.text)
	screen.open_for_save()
	for i in 2:
		await process_frame
	if screen.version_warning() != "":
		fails.append("the save screen warned about versions")
	if str(screen.hint.text).contains("0.0.1-alpha"):
		fails.append("the save screen's line carries a load warning: '%s'" % screen.hint.text)
	root.remove_child(screen)
	screen.free()

	# 5. The warning is about the list, not a latch: clearing the foreign save silences it.
	DirAccess.remove_absolute(SAVEGAME.slot_path(3))
	if SAVEGAME.version_warning(SAVEGAME.list_slots()) != "":
		fails.append("the warning outlived the save that caused it")

	guard.restore()
	p.queue_free()
	print("RESULT build=%s warning='%s' failures=%d"
			% [SAVEGAME.build_version(), warning, fails.size()])
	if fails.is_empty():
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)