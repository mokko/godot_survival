class_name SaveGame
## Savegame I/O for survivalm — one JSON file at user://savegame.json.
## Writers: the pause menu's Save button. Readers: the splash screen's
## Continue button, which sets pending_load so the player restores the
## state in _ready. All methods are static; the player owns its state
## via save_state()/load_state().

const SAVE_PATH := "user://savegame.json"

## Set by the splash screen before entering the game; consumed (and
## cleared) by the player in _ready.
static var pending_load := false


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