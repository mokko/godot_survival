extends SceneTree
## Headless check: F11 toggles fullscreen/windowed anywhere in the game.
## Verifies the input action is registered, the toggle persists through
## options.gd, and that the real input path (a parsed F11 key event) reaches
## the autoload — including while the pause menu has the tree paused.

const Options := preload("res://ui/options.gd")
const ToggleScript := preload("res://ui/display_toggle.gd")

func _init() -> void:
	var fails: PackedStringArray = []
	var dir := DirAccess.open("user://")
	var had_file := FileAccess.file_exists(Options.PATH)
	var backup := "" if not had_file else FileAccess.get_file_as_string(Options.PATH)
	dir.remove("options.json")
	Options._cache = {}

	# 1. The action exists in the project input map, bound to F11.
	var ev_map: Dictionary = ProjectSettings.get_setting("input/toggle_fullscreen", {})
	var events: Array = ev_map.get("events", [])
	var bound_f11 := false
	for e in events:
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F11:
			bound_f11 = true
	if events.is_empty() or not bound_f11:
		fails.append("f11_not_bound")

	# 2. The autoload is registered and runs while paused. Autoloads are added
	#    to the root after the first frame, so wait one out before looking.
	var autoload_path: String = str(ProjectSettings.get_setting(
			"autoload/DisplayToggle", ""))
	if not autoload_path.contains("display_toggle.gd"):
		fails.append("autoload_missing")
	await process_frame
	var toggle: Node = root.get_node_or_null("DisplayToggle")
	if toggle == null:
		fails.append("autoload_not_instantiated")
	elif toggle.process_mode != Node.PROCESS_MODE_ALWAYS:
		fails.append("autoload_pausable")

	# 3. A parsed F11 key event flips the option (starting from the default on).
	var start: bool = bool(Options.get_option("fullscreen"))
	var press := InputEventKey.new()
	press.physical_keycode = KEY_F11
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var flipped: bool = bool(Options.get_option("fullscreen")) != start

	# 4. And the choice persists across a cache reload.
	Options._cache = {}
	var persisted: bool = bool(Options.get_option("fullscreen")) != start

	# 5. F11 still works while paused (the pause menu pauses the tree).
	#    The autoload is ALWAYS, and _unhandled_input must still reach it.
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 40:
		await physics_frame
	(main.get_node("HUD/PauseMenu") as Control).open()
	await process_frame
	var before_paused: bool = bool(Options.get_option("fullscreen"))
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var while_paused: bool = bool(Options.get_option("fullscreen")) != before_paused

	# Restore the player's file and their previous choice.
	Options._cache = {}
	if had_file:
		FileAccess.open(Options.PATH, FileAccess.WRITE).store_string(backup)
	else:
		dir.remove("options.json")

	print("RESULT f11_bound=%s autoload=%s flipped=%s persisted=%s while_paused=%s"
			% [bound_f11, toggle != null, flipped, persisted, while_paused])
	var ok: bool = bound_f11 and toggle != null and flipped and persisted \
			and while_paused
	quit(0 if ok else 1)
