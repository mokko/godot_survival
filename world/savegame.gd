class_name SaveGame
## Savegame I/O for survivalm — one JSON file at user://savegame.json.
## Writers: the pause menu's Save button. Readers: the splash screen's
## Load Game button, which sets pending_load so the player restores the
## state in _ready. All methods are static; the player owns its state
## via save_state()/load_state().

const SAVE_PATH := "user://savegame.json"
const SAVE_FILE_NAME := "savegame.json"

## Keys a real save can be expected to carry. Used to tell our savegame apart from
## some other Godot project's file of the same name while looking for a legacy one.
const SAVE_KEYS := ["pos", "life", "inventory", "notes", "armor", "time_of_day"]

## Set by the splash screen before entering the game; consumed (and
## cleared) by the player in _ready.
static var pending_load := false

## Set by the splash screen's Start button (a fresh run) and consumed by the
## player in _ready, which hands out the starting loadout. Load Game leaves it
## false: a restored run keeps whatever it was carrying.
static var pending_new_run := false


static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Write the player's state. Returns false if the file could not be opened.
static func write(player: Node) -> bool:
	var state: Dictionary = player.save_state()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame.write failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(state))
	return true


## Read the save. Returns {} when missing or corrupt.
static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## True once per game start: returns and clears pending_load.
static func take_pending_load() -> bool:
	var take := pending_load
	pending_load = false
	return take


## True once per fresh run: returns and clears pending_new_run. The player
## reads this to hand out the starting loadout, exactly like pending_load.
static func take_pending_new_run() -> bool:
	var take := pending_new_run
	pending_new_run = false
	return take


## Wipe the savefile (death penalty: a fresh run must start empty).
## Keeps an empty valid JSON so exists() stays true and consistent.
static func clear() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame.clear failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string("{}")
	return true


## Adopt a savefile left behind by an earlier install, and return the path it came
## from ("" when there was nothing to adopt).
##
## A snap refresh hands out a new XDG_DATA_HOME (`godot-4/34`, not `godot-4/30`) and a
## rename changes the folder name; either one leaves the player's savegame in a
## directory the engine will never look at again, and the run is silently gone. This
## copies the newest valid one it can find into the current location — once, at
## startup. Best effort by design: every failure is a quiet no-op, and the file it
## finds is never moved or deleted.
##
## `roots` overrides where to look, which is how the test drives it hermetically.
static func adopt_legacy_save(roots: Array = []) -> String:
	if exists():
		return ""      # this install already has a save; never second-guess it
	var best := ""
	var best_time := -1
	for root_dir in (roots if not roots.is_empty() else legacy_roots()):
		var path: String = str(root_dir).path_join(SAVE_FILE_NAME)
		if path == SAVE_PATH or not FileAccess.file_exists(path):
			continue
		if not _looks_like_a_save(path):
			continue
		var when: int = FileAccess.get_modified_time(path)
		if when > best_time:
			best_time = when
			best = path
	if best == "":
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame.adopt failed: %s" % error_string(FileAccess.get_open_error()))
		return ""
	f.store_string(FileAccess.get_file_as_string(best))
	return best


static func legacy_roots() -> Array:
	## Where a save from an earlier install could be. On Linux the engine's own folder
	## is `<...>/godot/app_userdata/<config/name>`, so the candidates are the folders
	## beside it (an earlier title) and the same folders under every sibling revision
	## (a snap refresh). Anywhere else this finds nothing, which is the intended
	## outcome: the game simply starts without a save.
	var out: Array = []
	if OS.get_name() != "Linux":
		return out
	var dir := OS.get_user_data_dir().get_base_dir()
	for depth in 6:
		if dir.is_empty() or dir == "/" or dir == ".":
			break
		for sibling in _subdirs(dir):
			out.append(sibling)
			# A sibling can be another revision of the snap, or another XDG data
			# root: look inside it for an app_userdata (or custom-name) directory.
			for nested in ["app_userdata", ".local/share/godot/app_userdata"]:
				out.append_array(_subdirs(str(sibling).path_join(nested)))
		dir = dir.get_base_dir()
	return out


static func _subdirs(path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append(path.path_join(sub))
	return out


static func _looks_like_a_save(path: String) -> bool:
	## Anything named savegame.json in a sibling directory could belong to a different
	## project, so the content has to look like ours before it is adopted.
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	if (data as Dictionary).is_empty():
		return true      # a wiped save: valid, and adopting it changes nothing
	for key in SAVE_KEYS:
		if (data as Dictionary).has(key):
			return true
	return false