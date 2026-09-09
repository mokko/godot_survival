extends Control
## Splash/menu screen — the new main scene. Shows the title and a Start
## button; pressing Start swaps in the game scene and captures the mouse.
## Will grow later (options, load game, ...).

const GAME_SCENE := "res://world/main.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/VBox/Start.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/story.tscn")
