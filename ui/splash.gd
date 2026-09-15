extends Control
## Splash/menu screen — the main scene. Shows the title, Start, Options and the
## Load Game button. Load Game is always shown, even when no save exists:
## loading an absent save simply starts a fresh run. It sets
## SaveGame.pending_load so the player restores the saved state once the story
## screen hands off to the game scene.

const STORY_SCENE := "res://ui/story.tscn"
const SAVEGAME := preload("res://world/savegame.gd")
const Options := preload("res://ui/options.gd")

@onready var options_panel: PanelContainer = $OptionsPanel
@onready var fullscreen_btn: CheckButton = $OptionsPanel/VBox/Fullscreen
@onready var show_fps_btn: CheckButton = $OptionsPanel/VBox/ShowFPS
@onready var res_option: OptionButton = $OptionsPanel/VBox/ResOption
@onready var menu_vbox: VBoxContainer = $Center/VBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/VBox/Start.grab_focus()
	# The project boots fullscreen (window/size/mode=3); this honours a saved
	# opt-out so a windowed player isn't fullscreened every launch.
	Options.apply_display()


func _on_options_pressed() -> void:
	fullscreen_btn.button_pressed = bool(Options.get_option("fullscreen"))
	show_fps_btn.button_pressed = Options.get_option("show_fps")
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
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_continue_pressed() -> void:
	SAVEGAME.pending_load = true
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_quit_pressed() -> void:
	## Leave the game: quit the process from the main menu. Quitting mid-run
	## stays the pause menu's job (it saves first if the player wants that).
	get_tree().quit()
