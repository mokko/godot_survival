class_name SaveGame
## Savegame I/O for Nakamoto's Paradigm.
##
## Five slots live under user://saves/: four (1..4) the player writes and names
## by hand from the Saves screen, and slot 5, the autosave, which is rewritten
## every AUTOSAVE_SECONDS. **The name is inside the file, not in its name** — a
## fixed path per slot keeps saving portable (Windows, macOS and Linux disagree
## about filenames) and lets a name be anything the player types.
##
## A file is one flat Dictionary: the state the player writes through
## save_state(), plus the meta keys this class adds (`name`, `saved_at`, `slot`,
## `version`). Flat rather than nested because player.load_state() reads its keys
## straight off the dictionary and ignores what it does not recognise, so a file
## written before slots existed still loads.
##
## Writers: the Saves screen (from the pause menu's one save entry), the autosave clock on the
## player, and the death path — which no longer touches a file at all. Dying
## costs the run, not the save: the last save stays loadable.
##
## Readers: the Saves screen, and the splash's Continue / Load Game, which set
## pending_load and pending_slot; the player consumes both in _ready.

const SAVE_DIR := "user://saves"
## The slots the player writes by hand.
const SLOT_COUNT := 4
## The rotating autosave: a slot like any other when loading, but the player
## never names it and never writes it by hand.
const AUTOSAVE_SLOT := 5
const MAX_SLOT := AUTOSAVE_SLOT
const DEFAULT_SLOT := 1
const AUTOSAVE_SECONDS := 300.0
const AUTOSAVE_NAME := "Autosave"
const INDEX_PATH := "user://saves/index.json"

## What an install from before slots wrote, and what the file was called. Both
## are kept so a save from such an install can be adopted rather than lost.
const LEGACY_PATH := "user://savegame.json"
const LEGACY_FILE_NAME := "savegame.json"

## Slot 1 as a path — where the pre-slot API (read/write/clear/exists with no
## slot at all) maps onto, so callers written before slots keep working.
const SAVE_PATH := "user://saves/slot_1.json"

## Keys a real save can be expected to carry. Used to tell our savegame apart
## from some other Godot project's file of the same name while looking for a
## legacy one.
const SAVE_KEYS := ["pos", "life", "items", "inventory", "notes", "armor", "time_of_day"]

## Set by the splash screen before entering the game; consumed (and cleared) by
## the player in _ready. `pending_slot` says which slot it means (0 = whatever
## this player played last).
static var pending_load := false
static var pending_slot := 0

## Set by the splash screen's Start button (a fresh run) and consumed by the
## player in _ready, which hands out the starting loadout. Loading leaves it
## false: a restored run keeps whatever it was carrying.
static var pending_new_run := false

## The slot this run plays in — set when it is loaded from one, or written into
## one. 0 means the run has not been saved anywhere yet, so the Saves screen
## treats the first save as choosing a slot.
static var current_slot := 0


static func is_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOT


static func is_autosave(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT


static func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


static func slot_label(slot: int) -> String:
	## How the row is named when the player has not named it.
	return AUTOSAVE_NAME if is_autosave(slot) else "Slot %d" % slot


static func default_name(slot: int) -> String:
	return AUTOSAVE_NAME if is_autosave(slot) else "Expedition %d" % slot


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ------------------------------------------------------------------- writing

static func write_slot(slot: int, player: Node, name: String = "") -> bool:
	## Write the player's state into a slot. An empty `name` keeps the name the
	## slot already has, so saving over your own slot does not rename it.
	if not is_slot(slot):
		push_error("SaveGame.write_slot: no slot %d" % slot)
		return false
	ensure_dir()
	var state: Dictionary = player.save_state()
	var keep := name.strip_edges()
	if keep.is_empty():
		keep = slot_name(slot).strip_edges()
	if keep.is_empty():
		keep = default_name(slot)
	state["name"] = keep
	state["saved_at"] = int(Time.get_unix_time_from_system())
	state["slot"] = slot
	state["version"] = str(ProjectSettings.get_setting("application/config/version"))
	if not _store(slot, state):
		return false
	if not is_autosave(slot):
		current_slot = slot
		set_last_played(slot)
	return true


static func autosave(player: Node) -> bool:
	## Same file every time, so it can only ever cost the player the last
	## AUTOSAVE_SECONDS.
	return write_slot(AUTOSAVE_SLOT, player, AUTOSAVE_NAME)


static func rename_slot(slot: int, name: String) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	var trimmed := name.strip_edges()
	data["name"] = trimmed if not trimmed.is_empty() else default_name(slot)
	return _store(slot, data)


static func clear_slot(slot: int) -> bool:
	## Empty a slot but leave the file in place: an emptied slot is a valid,
	## empty save, and exists() stays honest about it.
	return _store(slot, {})


static func delete_slot(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	if current_slot == slot:
		current_slot = 0
	return DirAccess.remove_absolute(path) == OK


static func _store(slot: int, data: Dictionary) -> bool:
	ensure_dir()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveGame store failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data))
	return true


# ------------------------------------------------------------------- reading

static func read_slot(slot: int) -> Dictionary:
	## The state in a slot, or {} when the slot is empty, missing or corrupt.
	if not is_slot(slot):
		return {}
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


static func exists(slot: int = 0) -> bool:
	## With no argument — the call shape from before slots — it asks whether *any*
	## slot holds a save.
	if slot == 0:
		for i in range(1, MAX_SLOT + 1):
			if not read_slot(i).is_empty():
				return true
		return false
	return not read_slot(slot).is_empty()


static func has_any_save() -> bool:
	return exists(0)


static func slot_name(slot: int) -> String:
	var data := read_slot(slot)
	if data.is_empty():
		return ""
	var n := str(data.get("name", "")).strip_edges()
	return n if not n.is_empty() else default_name(slot)


static func slot_summary(slot: int) -> Dictionary:
	## One row for the Saves screen. Always answers, empty slot or not.
	var data := read_slot(slot)
	var row := {
		"slot": slot,
		"label": slot_label(slot),
		"autosave": is_autosave(slot),
		"empty": data.is_empty(),
		"name": "",
		"saved_at": 0,
		"life": 0.0,
		"sunbulbs": 0,
	}
	if data.is_empty():
		return row
	row["name"] = str(data.get("name", default_name(slot)))
	row["saved_at"] = int(data.get("saved_at", 0))
	row["life"] = float(data.get("life", 0.0))
	row["sunbulbs"] = int(data.get("sunbulbs", 0))
	return row


static func list_slots() -> Array:
	var out: Array = []
	for slot in range(1, MAX_SLOT + 1):
		out.append(slot_summary(slot))
	return out


static func describe(row: Dictionary) -> String:
	## A row's detail line: when it was saved and what the drone was carrying.
	if bool(row.get("empty", true)):
		return "empty"
	var when := int(row.get("saved_at", 0))
	var stamp := "when it was saved" if when <= 0 \
			else Time.get_datetime_string_from_unix_time(when, true)
	return "%s — charge %.0f, sunbulbs %d" % [
		stamp, float(row.get("life", 0.0)), int(row.get("sunbulbs", 0))]


# -------------------------------------------------------------- which slot

static func set_last_played(slot: int) -> void:
	ensure_dir()
	var f := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"last_played": slot,
			"when": int(Time.get_unix_time_from_system())}))


static func last_played_slot() -> int:
	if not FileAccess.file_exists(INDEX_PATH):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not data is Dictionary:
		return 0
	var slot := int((data as Dictionary).get("last_played", 0))
	return slot if is_slot(slot) else 0


static func most_recent_slot() -> int:
	## The newest save, by the timestamp each file carries; 0 when there is none.
	var best := 0
	var best_time := -1
	for slot in range(1, MAX_SLOT + 1):
		var data := read_slot(slot)
		if data.is_empty():
			continue
		var when := int(data.get("saved_at", 0))
		if when >= best_time:
			best_time = when
			best = slot
	return best


static func continue_slot() -> int:
	## What the splash's Continue opens: the slot this player was last *playing*,
	## so a more recent autosave does not hijack it. Falls back to the newest
	## save, then to nothing.
	var last := last_played_slot()
	if last != 0 and not read_slot(last).is_empty():
		return last
	return most_recent_slot()


# ------------------------------------------------------- pending hand-off

static func take_pending_load() -> bool:
	var take := pending_load
	pending_load = false
	return take


static func take_pending_slot() -> int:
	## The slot a pending load means: the one asked for, else whatever this player
	## played last, else the first slot.
	var slot := pending_slot
	pending_slot = 0
	if is_slot(slot):
		return slot
	var fallback := continue_slot()
	return fallback if fallback != 0 else DEFAULT_SLOT


static func take_pending_new_run() -> bool:
	var take := pending_new_run
	pending_new_run = false
	return take


# ------------------------------------------------- the API from before slots

static func read() -> Dictionary:
	## Still honoured: it means slot 1.
	return read_slot(DEFAULT_SLOT)


static func write(player: Node) -> bool:
	return write_slot(DEFAULT_SLOT, player)


static func clear() -> bool:
	return clear_slot(DEFAULT_SLOT)


static func migrate_legacy_file() -> String:
	## A save written before slots existed becomes slot 1, once. The legacy file
	## is left exactly where it is: this copies, it never moves or deletes.
	## Returns the path it came from, or "" when there was nothing to do.
	if not read_slot(DEFAULT_SLOT).is_empty():
		return ""
	if not FileAccess.file_exists(LEGACY_PATH):
		return ""
	if not _looks_like_a_save(LEGACY_PATH):
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PATH))
	if not data is Dictionary:
		return ""
	var d: Dictionary = data
	if not d.has("saved_at"):
		d["saved_at"] = int(FileAccess.get_modified_time(LEGACY_PATH))
	if not d.has("name"):
		d["name"] = default_name(DEFAULT_SLOT)
	d["slot"] = DEFAULT_SLOT
	if not _store(DEFAULT_SLOT, d):
		return ""
	return LEGACY_PATH


## Adopt a savefile left behind by an earlier install, and return the path it came
## from ("" when there was nothing to adopt).
##
## A snap refresh hands out a new XDG_DATA_HOME (`godot-4/34`, not `godot-4/30`) and a
## rename changes the folder name; either one leaves the player's savegame in a
## directory the engine will never look at again, and the run is silently gone. This
## copies the newest valid one it can find into slot 1 — once, at startup. Best
## effort by design: every failure is a quiet no-op, and the file it finds is never
## moved or deleted.
##
## `roots` overrides where to look, which is how the test drives it hermetically.
static func adopt_legacy_save(roots: Array = []) -> String:
	if has_any_save():
		return ""      # this install already has a save; never second-guess it
	var best := ""
	var best_time := -1
	for root_dir in (roots if not roots.is_empty() else legacy_roots()):
		var path: String = str(root_dir).path_join(LEGACY_FILE_NAME)
		if path == LEGACY_PATH or not FileAccess.file_exists(path):
			continue
		if not _looks_like_a_save(path):
			continue
		var when: int = FileAccess.get_modified_time(path)
		if when > best_time:
			best_time = when
			best = path
	if best == "":
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(best))
	var d: Dictionary = data if data is Dictionary else {}
	if not d.has("saved_at"):
		d["saved_at"] = best_time
	if not d.has("name"):
		d["name"] = default_name(DEFAULT_SLOT)
	d["slot"] = DEFAULT_SLOT
	if not _store(DEFAULT_SLOT, d):
		push_error("SaveGame.adopt failed: %s" % error_string(FileAccess.get_open_error()))
		return ""
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
