extends SceneTree
## Headless check: fullscreen is the default (project boots mode=3 and the
## "fullscreen" option defaults to true), the player can opt out to windowed,
## the choice persists, and the splash options panel exposes the toggle —
## greying out the resolution picker while fullscreen is on.

const Options := preload("res://ui/options.gd")

func _init() -> void:
	# Clean slate (don't clobber the user's file: back it up).
	var dir := DirAccess.open("user://")
	var had_file := FileAccess.file_exists(Options.PATH)
	var backup := ""
	if had_file:
		backup = FileAccess.get_file_as_string(Options.PATH)
	dir.remove("options.json")
	Options._cache = {}   # force re-hydrate from defaults

	# 1. Default is fullscreen, and the project setting agrees (mode 3).
	var default_on: bool = bool(Options.get_option("fullscreen")) == true
	var proj_mode: int = int(ProjectSettings.get_setting("display/window/size/mode"))
	var boots_fullscreen: bool = proj_mode == DisplayServer.WINDOW_MODE_FULLSCREEN

	# 2. Opting out persists.
	Options.set_option("fullscreen", false)
	Options._cache = {}
	var opt_out_persists: bool = bool(Options.get_option("fullscreen")) == false

	# 3. The panel reflects the option and disables the resolution picker
	#    while fullscreen, re-enabling it in windowed mode.
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	splash._on_options_pressed()
	var toggle: CheckButton = splash.get_node("OptionsPanel/VBox/Fullscreen")
	var picker: OptionButton = splash.get_node("OptionsPanel/VBox/ResOption")
	var windowed_ok: bool = toggle.button_pressed == false \
			and picker.disabled == false

	# Emulate a real click: setting button_pressed emits `toggled`, which
	# splash.tscn wires to _on_fullscreen_toggled.
	toggle.button_pressed = true
	await process_frame
	var fullscreen_ok: bool = picker.disabled == true \
			and bool(Options.get_option("fullscreen")) == true

	# Toggling back to windowed must not leave the picker stuck disabled.
	toggle.button_pressed = false
	await process_frame
	var back_to_window_ok: bool = picker.disabled == false \
			and bool(Options.get_option("fullscreen")) == false

	# Restore user state.
	Options._cache = {}
	if had_file:
		var f := FileAccess.open(Options.PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		dir.remove("options.json")

	print("RESULT default_fullscreen=%s boot_mode=3:%s opt_out_persists=%s "
			% [default_on, boots_fullscreen, opt_out_persists]
			+ "windowed_ui=%s fullscreen_ui=%s back_to_window=%s"
			% [windowed_ok, fullscreen_ok, back_to_window_ok])
	var ok: bool = default_on and boots_fullscreen and opt_out_persists \
			and windowed_ok and fullscreen_ok and back_to_window_ok
	quit(0 if ok else 1)
