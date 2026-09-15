extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Resume / Save / Quit to Menu. Resume (or ESC
## again) unpauses and re-captures the mouse. The player emits
## `pause_requested` on ESC; the HUD/main scene connects it to `open()`.

const SAVEGAME := preload("res://world/savegame.gd")

@onready var save_label: Label = $SaveLabel

var _save_label_tween: Tween


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Button presses are wired via [connection] entries in pause_menu.tscn.


func _unhandled_input(event: InputEvent) -> void:
	# Only runs while visible+paused (this node is WHEN_PAUSED): ESC resumes.
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume()


func open() -> void:
	visible = true
	save_label.hide()
	_set_crosshair_visible(false)
	_apply_padding()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _apply_padding() -> void:
	## ~10% of the viewport width on each side of the panel.
	var pad: int = int(size.x * 0.1)
	$Center/Padding.add_theme_constant_override("margin_left", pad)
	$Center/Padding.add_theme_constant_override("margin_right", pad)


func _on_resume() -> void:
	visible = false
	_set_crosshair_visible(true)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_crosshair_visible(shown: bool) -> void:
	var crosshair: Node = get_tree().current_scene.get_node_or_null("HUD/Crosshair")
	if crosshair != null:
		crosshair.visible = shown


func _on_save() -> void:
	var player: CharacterBody3D = get_tree().current_scene.get_node("Player")
	var ok: bool = SAVEGAME.write(player)
	_show_save_label("Saved!" if ok else "Save failed")


func _show_save_label(text: String) -> void:
	save_label.text = text
	save_label.show()
	if _save_label_tween != null:
		_save_label_tween.kill()
	save_label.modulate.a = 1.0
	_save_label_tween = create_tween()
	_save_label_tween.tween_interval(1.2)
	_save_label_tween.tween_property(save_label, "modulate:a", 0.0, 0.6)
	_save_label_tween.tween_callback(save_label.hide)


func _on_quit() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/splash.tscn")
