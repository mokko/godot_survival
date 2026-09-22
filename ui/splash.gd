extends Control
## Splash/menu screen — the main scene. Shows the title, Start, Options and the
## Load Game button. Load Game is always shown, even when no save exists:
## loading an absent save simply starts a fresh run. It sets
## SaveGame.pending_load so the player restores the saved state once the story
## screen hands off to the game scene.

const STORY_SCENE := "res://ui/story.tscn"
const GAME_SCENE := "res://world/main.tscn"
const SAVEGAME := preload("res://world/savegame.gd")
const Options := preload("res://ui/options.gd")

## The menu buttons, in the order they sit under the title.
const MENU_BUTTONS := ["Start", "Options", "Continue", "LoadGame", "Exit"]
## How wide the buttons are, as a fraction of the title's width. They used to
## stretch across the whole menu column — which is exactly as wide as the title,
## so "Nakamoto's Paradigm" made them a wall of buttons three times wider than
## any label in them. A third of the title reads as buttons again.
const BUTTON_WIDTH_RATIO := 1.0 / 3.0

@onready var options_panel: PanelContainer = $OptionsPanel
@onready var fullscreen_btn: CheckButton = $OptionsPanel/VBox/Fullscreen
@onready var show_fps_btn: CheckButton = $OptionsPanel/VBox/ShowFPS
@onready var ssao_btn: CheckButton = $OptionsPanel/VBox/SSAO
@onready var res_option: OptionButton = $OptionsPanel/VBox/ResOption
@onready var saves: Control = $Saves
@onready var menu_vbox: VBoxContainer = $Center/VBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A save left behind by an earlier install — an older snap revision, or the game
	# under its previous name — is adopted before anything reads it. Load Game is
	# always shown, so this is the one moment that can notice one is there.
	# A single savefile from before slots existed becomes slot 1 first, then a
	# save left behind by an earlier install is adopted. Slot 1 either way, and
	# both are copies: the files they came from are never touched.
	var migrated: String = SAVEGAME.migrate_legacy_file()
	if migrated != "":
		print("SaveGame: took the save at %s into slot 1" % migrated)
	var adopted: String = SAVEGAME.adopt_legacy_save()
	if adopted != "":
		print("SaveGame: adopted the save left at %s" % adopted)
	# The Saves screen reports the slot the player picked; entering the world is
	# this screen's job, exactly as it is for Start and Continue.
	saves.slot_chosen.connect(_on_saves_slot_chosen)
	saves.closed.connect($Center/VBox/LoadGame.grab_focus)
	_size_menu_buttons()
	$Center/VBox/Start.grab_focus()
	# The project boots fullscreen (window/size/mode=3); this honours a saved
	# opt-out so a windowed player isn't fullscreened every launch.
	Options.apply_display()


func _size_menu_buttons() -> void:
	## Buttons a third of the title wide, sized from the title's own text rather
	## than from a pixel constant (a rename or another font-size tweak keeps the
	## proportion). SIZE_SHRINK_CENTER is what stops a VBoxContainer child from
	## filling the column: each button keeps its minimum width and is centred
	## under the title, instead of matching the title's width.
	var third := ceilf(title_width() * BUTTON_WIDTH_RATIO)
	if third <= 0.0:
		return
	for button_name in MENU_BUTTONS:
		var button := menu_vbox.get_node_or_null(button_name) as Button
		if button == null:
			continue
		button.custom_minimum_size.x = third
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func title_width() -> float:
	## How wide the title's text is. The menu column is exactly this wide, so it
	## is the number the button width is a fraction of.
	var title := menu_vbox.get_node_or_null("Title") as Label
	if title == null:
		return 0.0
	var font: Font = title.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title.get_theme_font_size("font_size")).x


func _on_options_pressed() -> void:
	fullscreen_btn.button_pressed = bool(Options.get_option("fullscreen"))
	show_fps_btn.button_pressed = Options.get_option("show_fps")
	ssao_btn.button_pressed = bool(Options.get_option("ssao"))
	res_option.clear()
	for r in Options.RESOLUTIONS:
		res_option.add_item("%d x %d" % [r[0], r[1]])
	res_option.select(clampi(int(Options.get_option("res")), 0,
			Options.RESOLUTIONS.size() - 1))
	# Resolution only means something in a window; fullscreen uses the
	# desktop's. Grey it out rather than hide it, so the panel doesn't jump.
	res_option.disabled = fullscreen_btn.button_pressed
	menu_vbox.hide()
	options_panel.show()


func _on_options_back_pressed() -> void:
	Options.set_option("fullscreen", fullscreen_btn.button_pressed)
	Options.set_option("show_fps", show_fps_btn.button_pressed)
	# Ambient occlusion is a property of the world scene's environment, so
	# there is nothing to apply while the menu is up — the world reads this
	# option when it starts (world/graphics_options.gd).
	Options.set_option("ssao", ssao_btn.button_pressed)
	Options.set_option("res", res_option.selected)
	options_panel.hide()
	menu_vbox.show()


func _on_fullscreen_toggled(pressed: bool) -> void:
	# Apply immediately (like the resolution picker) so the player sees the
	# result. The toggle has to be persisted here as well, because
	# apply_display() reads it back; the other options still save on Back.
	Options.set_option("fullscreen", pressed)
	Options.apply_display()
	res_option.disabled = pressed


func _on_res_option_item_selected(index: int) -> void:
	# Apply immediately so the player sees the result, but only persist on
	# Back (consistent with the FPS toggle).
	Options.set_option("res", index)
	Options.apply_resolution()


func _on_start_pressed() -> void:
	SAVEGAME.pending_load = false   # fresh run: drop any stale load request
	# Fresh run: the player hands out the starting loadout in its _ready.
	SAVEGAME.pending_new_run = true
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_continue_pressed() -> void:
	## Load Game goes straight into the world: the intro story belongs to a new
	## run, and the player has already read it. pending_load makes the player
	## restore the save in its _ready.
	# Which slot: the one this player played last, so a fresher autosave does not
	# hijack Continue. 0 means nothing to continue and the player falls back.
	_begin_load(SAVEGAME.continue_slot())
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_saves_slot_chosen(slot: int) -> void:
	## Enter the world on that slot. The flags are set in _begin_load(); the scene
	## change is separate so the flags can be checked without a tree to swap.
	_begin_load(slot)
	get_tree().change_scene_to_file(GAME_SCENE)


func _begin_load(slot: int) -> void:
	## Ask the player to restore `slot`: pending_slot names the file, so it never
	## has to guess which one a load meant. Going into the world is the caller's
	## job — the intro story belongs to a new run, and this player has read it.
	SAVEGAME.pending_load = true
	SAVEGAME.pending_slot = slot
	SAVEGAME.pending_new_run = false


func _on_load_game_pressed() -> void:
	## The list of slots, rather than Continue's one-click jump to the last one
	## played. This screen closes on ESC: on the splash nobody else owns that key.
	saves.open_for_load()


func _on_exit_pressed() -> void:
	## Leave the game from the main menu. Leaving mid-run is the pause menu's
	## "Quit to Menu" (which hands back here); this one closes the process.
	get_tree().quit()
