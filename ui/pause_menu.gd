extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Continue / Save / Pedia / Quit to Menu. Continue (or
## ESC again) unpauses and re-captures the mouse. The player emits
## `pause_requested` on ESC; the HUD/main scene connects it to `open()`.
##
## The Pedia (ui/pedia.tscn) is a child of this menu and is shown in place of it.
## This node is the only one that listens for ESC: while the book is open the key
## walks the Pedia back a page instead of resuming the game.

const SAVEGAME := preload("res://world/savegame.gd")

@onready var save_label: Label = $SaveLabel
@onready var pedia: Control = $Pedia
@onready var menu: CenterContainer = $Center

var _save_label_tween: Tween


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Button presses are wired via [connection] entries in pause_menu.tscn.
	pedia.closed.connect(_on_pedia_closed)


func _unhandled_input(event: InputEvent) -> void:
	# Only runs while visible+paused (this node is WHEN_PAUSED): ESC continues.
	if visible and event.is_action_pressed("ui_cancel"):
		if pedia.visible:
			pedia.back()   # one page up; closing the book lands back here
		else:
			_on_continue()


func open() -> void:
	visible = true
	# Never resume play with the book open — a fresh pause shows the menu.
	if pedia.visible:
		pedia.close()
	save_label.hide()
	_set_crosshair_visible(false)
	_apply_padding()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Give the menu keyboard/gamepad focus so the first button is highlighted
	# (mirrors splash.gd). Without this nothing is selected and arrow keys do
	# nothing until the mouse is used.
	$Center/Padding/Panel/VBox/Continue.grab_focus()


func _apply_padding() -> void:
	## ~10% of the viewport width on each side of the panel.
	var pad: int = int(size.x * 0.1)
	$Center/Padding.add_theme_constant_override("margin_left", pad)
	$Center/Padding.add_theme_constant_override("margin_right", pad)


func _on_continue() -> void:
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
	# Save into the slot this run plays in; a run that has never been saved
	# anywhere yet opens slot 1, and the Saves screen is how you choose another.
	var slot: int = SaveGame.current_slot if SaveGame.current_slot > 0 else SaveGame.DEFAULT_SLOT
	var ok: bool = SAVEGAME.write_slot(slot, player)
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


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/splash.tscn")


func _on_pedia() -> void:
	## Show the book in place of the menu rather than on top of it: the Pedia
	## draws its own dim and panel, and two stacked panels read as a bug.
	menu.hide()
	pedia.open()


func _on_pedia_closed() -> void:
	menu.show()
	$Center/Padding/Panel/VBox/Continue.grab_focus()
