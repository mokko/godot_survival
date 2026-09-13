extends Control
## Splash/menu screen — the main scene. Shows the title, Start, and Continue
## (only when a savegame exists). Continue sets SaveGame.pending_load so the
## player restores the saved state once the story screen hands off to the
## game scene.

const STORY_SCENE := "res://ui/story.tscn"
const SAVEGAME := preload("res://world/savegame.gd")
const Options := preload("res://ui/options.gd")

@onready var continue_btn: Button = $Center/VBox/Continue

@onready var options_panel: PanelContainer = $OptionsPanel
@onready var show_fps_btn: CheckButton = $OptionsPanel/VBox/ShowFPS
@onready var menu_vbox: VBoxContainer = $Center/VBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_btn.visible = SAVEGAME.exists()
	$Center/VBox/Start.grab_focus()


func _on_options_pressed() -> void:
	show_fps_btn.button_pressed = Options.get_option("show_fps")
	menu_vbox.hide()
	options_panel.show()


func _on_options_back_pressed() -> void:
	Options.set_option("show_fps", show_fps_btn.button_pressed)
	options_panel.hide()
	menu_vbox.show()


func _on_start_pressed() -> void:
	SAVEGAME.pending_load = false   # fresh run: drop any stale load request
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_continue_pressed() -> void:
	SAVEGAME.pending_load = true
	get_tree().change_scene_to_file(STORY_SCENE)
