extends RefCounted
## Game options persisted to user://options.json. Simple static access;
## HUD and menus read/write through here.

const PATH := "user://options.json"

## option -> [key, default]
const DEFAULTS := {
	"show_fps": true,
}

static var _cache: Dictionary = {}


static func get_option(key: String) -> Variant:
	if _cache.is_empty():
		_load()
	return _cache.get(key, DEFAULTS.get(key, false))


static func set_option(key: String, value: Variant) -> void:
	if _cache.is_empty():
		_load()
	_cache[key] = value
	_save()


static func _load() -> void:
	_cache = {}
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_cache = data
	# fill any missing defaults
	for key in DEFAULTS:
		if not _cache.has(key):
			_cache[key] = DEFAULTS[key]


static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Options.save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(_cache))
