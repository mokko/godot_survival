extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Resume / Save / Quit to Menu. Resume unpauses
## and re-captures the mouse. The player emits `pause_requested` on ESC;
## the HUD/main scene connects it to `open()`.

signal quit_to_menu

const SAVE_PATH := "user://savegame.json"

@onready var resume_btn: Button = $Center/Panel/VBox/Resume
@onready var save_btn: Button = $Center/Panel/VBox/Save
@onready var quit_btn: Button = $Center/Panel/VBox/Quit


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Button presses are wired via [connection] entries in pause_menu.tscn.


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_save() -> void:
	var main := get_tree().current_scene
	var player: CharacterBody3D = main.get_node("Player")
	var data := {
		"pos": [player.global_position.x, player.global_position.y,
				player.global_position.z],
		"orbs": player.orbs_collected,
		"life": player.life,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


func _on_quit() -> void:
	get_tree().paused = false
	quit_to_menu.emit()
