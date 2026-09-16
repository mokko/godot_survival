extends SceneTree
## Headless check: the "res" option defaults to HD (index 2 = 1920x1080, the
## list is ordered smallest first with 960x600 available for slow machines),
## persists via Options, and the splash options panel exposes a picker with one
## entry per supported resolution.

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

	var default_ok: bool = int(Options.get_option("res")) == 2
	var list_ok: bool = Options.RESOLUTIONS.size() == 3 \
			and Options.RESOLUTIONS[2][0] == 1920 \
			and Options.RESOLUTIONS[2][1] == 1080 \
			and Options.RESOLUTIONS[0][0] == 960 \
			and Options.RESOLUTIONS[0][1] == 600

	Options.set_option("res", 0)
	Options._cache = {}
	var persist_ok: bool = int(Options.get_option("res")) == 0

	# Splash options panel builds the dropdown on open.
	var splash = load("res://ui/splash.tscn").instantiate()
	root.add_child(splash)
	await process_frame
	splash._on_options_pressed()
	var picker: OptionButton = splash.get_node("OptionsPanel/VBox/ResOption")
	var picker_ok: bool = picker.item_count == Options.RESOLUTIONS.size()

	# Restore user state.
	Options._cache = {}
	if had_file:
		var f := FileAccess.open(Options.PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		dir.remove("options.json")

	print("RESULT default_hd=%s list=%s persist=%s picker=%s" % [
			default_ok, list_ok, persist_ok, picker_ok])
	quit(0 if (default_ok and list_ok and persist_ok and picker_ok) else 1)
