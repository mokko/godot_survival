extends RefCounted
## Game options persisted to user://options.json. Simple static access;
## HUD and menus read/write through here.

const PATH := "user://options.json"

## Supported window resolutions (width, height). "res" option stores an
## index into this list; default is HD 1920x1080.
const RESOLUTIONS := [
	[1280, 720],
	[1920, 1080],
]

## option -> [key, default]
const DEFAULTS := {
	"show_fps": true,
	"ssao": true,   # screen-space ambient occlusion in the world scene
	"res": 1,   # index into RESOLUTIONS — 1920x1080
	"fullscreen": true,
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


static func apply_display() -> void:
	## Honour the persisted "fullscreen" option. The project boots fullscreen
	## (project.godot: window/size/mode=3), so this only has to switch back to
	## a window when the player opted out — and re-apply their window size,
	## which fullscreen ignores.
	if bool(get_option("fullscreen")):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Restore the saved window size rather than keeping the monitor-sized
		# window fullscreen leaves behind.
		apply_resolution()


static func apply_resolution() -> void:
	## Set the window size from the persisted "res" option. Has no visible
	## effect while fullscreen, where the desktop size wins.
	if bool(get_option("fullscreen")):
		return
	var idx: int = clampi(int(get_option("res")), 0, RESOLUTIONS.size() - 1)
	var size: Array = RESOLUTIONS[idx]
	DisplayServer.window_set_size(Vector2i(size[0], size[1]))
	_clamp_window()


static func _clamp_window() -> void:
	## Re-center the window so a mode/resolution switch can't leave it
	## off-screen, and never let it grow past the current screen.
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var screen_pos := DisplayServer.screen_get_position(screen)
	var win := DisplayServer.window_get_size()
	win = Vector2i(mini(win.x, screen_size.x), mini(win.y, screen_size.y))
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position(
			screen_pos + (screen_size - win) / 2)


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
