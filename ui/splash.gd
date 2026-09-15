extends Control
## Splash/menu screen — the main scene. Shows the title, Start, and Continue
## (only when a savegame exists). Continue sets SaveGame.pending_load so the
## player restores the saved state once the story screen hands off to the
## game scene.

const STORY_SCENE := "res://ui/story.tscn"
const SAVEGAME := preload("res://world/savegame.gd")
const Options := preload("res://ui/options.gd")

@onready var options_panel: PanelContainer = $OptionsPanel
@onready var show_fps_btn: CheckButton = $OptionsPanel/VBox/ShowFPS
@onready var res_option: OptionButton = $OptionsPanel/VBox/ResOption
@onready var menu_vbox: VBoxContainer = $Center/VBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/VBox/Start.grab_focus()


func _on_options_pressed() -> void:
	show_fps_btn.button_pressed = Options.get_option("show_fps")
	res_option.clear()
	for r in Options.RESOLUTIONS:
		res_option.add_item("%d x %d" % [r[0], r[1]])
	res_option.select(clampi(int(Options.get_option("res")), 0,
			Options.RESOLUTIONS.size() - 1))
	menu_vbox.hide()
	options_panel.show()


func _on_options_back_pressed() -> void:
	Options.set_option("show_fps", show_fps_btn.button_pressed)
	Options.set_option("res", res_option.selected)
	options_panel.hide()
	menu_vbox.show()


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
