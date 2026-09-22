extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Continue / Save… / Pedia / Quit to Menu. Continue (or
## ESC again) unpauses and re-captures the mouse. The player emits
## `pause_requested` on ESC; the HUD/main scene connects it to `open()`.
##
## **Save… is the only way to save from here**, and it opens the Saves screen
## rather than writing on the spot: saving is a choice of which file, and a
## button that silently answers that question for you (it used to write into
## the run's own slot) is the same choice made blind. The screen answers with
## the file it wrote, and its own "Saved into Slot 2." is the feedback the menu
## used to draw a toast for.
##
## The Pedia (ui/pedia.tscn) is a child of this menu and is shown in place of it.
## This node is the only one that listens for ESC: while the book is open the key
## walks the Pedia back a page instead of resuming the game.

@onready var pedia: Control = $Pedia
@onready var saves: Control = $Saves
@onready var menu: CenterContainer = $Center


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Button presses are wired via [connection] entries in pause_menu.tscn.
	pedia.closed.connect(_on_pedia_closed)
	saves.closed.connect(_on_saves_closed)


func _unhandled_input(event: InputEvent) -> void:
	# Only runs while visible+paused (this node is WHEN_PAUSED). This node is the
	# only listener for ESC, which is why the Saves screen is opened with
	# escape_closes = false: here, ESC walks back out of whatever is open.
	if visible and event.is_action_pressed("ui_cancel"):
		if pedia.visible:
			pedia.back()   # one page up; closing the book lands back here
		elif saves.visible:
			saves.close()  # which lands back here too
		else:
			_on_continue()


func open() -> void:
	visible = true
	# Never resume play with the book or the saves list open — a fresh pause shows
	# the menu.
	if pedia.visible:
		pedia.close()
	if saves.visible:
		saves.close()
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


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/splash.tscn")


func _on_saves() -> void:
	## The same treatment as the book: the Saves screen draws its own dim and
	## panel, so the menu steps aside rather than stacking two panels. It gets the
	## run to write, and this menu keeps ESC for itself.
	menu.hide()
	saves.escape_closes = false
	saves.player = get_tree().current_scene.get_node_or_null("Player")
	saves.open_for_save()


func _on_saves_closed() -> void:
	menu.show()
	$Center/Padding/Panel/VBox/SavesButton.grab_focus()


func _on_pedia() -> void:
	## Show the book in place of the menu rather than on top of it: the Pedia
	## draws its own dim and panel, and two stacked panels read as a bug.
	menu.hide()
	pedia.open()


func _on_pedia_closed() -> void:
	menu.show()
	$Center/Padding/Panel/VBox/Continue.grab_focus()
