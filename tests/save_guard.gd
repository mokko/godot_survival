extends RefCounted
## Test-only guard for the live save directory.
##
## `user://saves/` belongs to whoever is playing. A test that writes a save into
## it and does not put it back leaves slots behind that the player then sees in
## Load Game — and two tests leaving different slots behind is how a *third* test
## starts failing for a reason that has nothing to do with it (test_save_migration
## only passes when no slot exists, and everyone else's leftovers made it fail).
##
## The old pattern was a per-test backup of `read_slot(1..5)` and a rewrite at the
## end. That misses the index file (names, last-played), misses any file shape the
## restore loop did not think of, and silently loses a save if the test exits
## early. This snapshots the whole directory — every file, by text — and restores
## it file for file, deleting anything that was not there to begin with.
##
## Use:
##     const SaveGuard := preload("res://tests/save_guard.gd")
##     var guard := SaveGuard.new()      # snapshots on construction
##     guard.wipe()                      # optional: a clean slate to test against
##     ...
##     guard.restore()                   # last thing before quit()
##
## `restore()` is idempotent: calling it twice, or calling it when the test never
## wrote anything, is a no-op.

const SaveGame := preload("res://world/savegame.gd")

## file name → contents, exactly as they were when this guard was made.
var _files := {}
## Whether the directory existed at all: a fresh install has no `saves/`, and a
## test must not leave one behind for the game to find.
var _dir_existed := false


func _init() -> void:
	_dir_existed = DirAccess.dir_exists_absolute(SaveGame.SAVE_DIR)
	for name in _list():
		var path: String = SaveGame.SAVE_DIR.path_join(name)
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			_files[name] = f.get_as_text()
			f.close()


static func _list() -> PackedStringArray:
	var d := DirAccess.open(SaveGame.SAVE_DIR)
	if d == null:
		return PackedStringArray()
	return d.get_files()


func _write(name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveGame.SAVE_DIR)
	var f := FileAccess.open(SaveGame.SAVE_DIR.path_join(name), FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func wipe() -> void:
	## Empty the slot files and the index, so a test that needs "no save anywhere"
	## gets it without knowing how many slots there are or what they are called.
	for name in _list():
		DirAccess.remove_absolute(SaveGame.SAVE_DIR.path_join(name))


func restore() -> void:
	## Put the directory back exactly as the guard found it.
	for name in _list():
		if not _files.has(name):
			DirAccess.remove_absolute(SaveGame.SAVE_DIR.path_join(name))
	for name in _files:
		_write(name, _files[name])
	if not _dir_existed and _files.is_empty():
		DirAccess.remove_absolute(SaveGame.SAVE_DIR)
