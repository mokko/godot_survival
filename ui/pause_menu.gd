extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Resume / Save / Quit to Menu. Resume unpauses
## and re-captures the mouse. The player emits `pause_requested` on ESC;
## the HUD/main scene connects it to `open()`.

signal quit_to_menu

const SAVEGAME := preload("res://world/savegame.gd")

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
	var player: CharacterBody3D = get_tree().current_scene.get_node("Player")
	SAVEGAME.write(player)


func _on_quit() -> void:
	get_tree().paused = false
	quit_to_menu.emit()
