extends Control
## In-game pause menu. Opens on ESC while playing: darkens the screen,
## pauses the tree, shows Continue / Save / Pedia / Quit to Menu. Continue (or
## ESC again) unpauses and re-captures the mouse. The player emits
## `pause_requested` on ESC; the HUD/main scene connects it to `open()`.
##
## **Save is the only save entry here**, and it opens the Saves screen
## rather than writing on the spot: saving is a choice of which file, and a
## button that silently answers that question for you (it used to write into
## the run's own slot) is the same choice made blind. The screen answers with
## the file it wrote, and its own "Saved into Slot 2." is the feedback the menu
## used to draw a toast for.
##
## The Pedia (ui/pedia.tscn) and the Saves screen are children of this menu, shown
## in place of it. So is the Frame screen (ui/editor.tscn) — except that one is
## opened from a service bench in the world (`open_editor`) and has no button here,
## so closing it drops the player straight back into the game rather than the menu.
## The **Pedia button is greyed out until the run has the notebook**. The book is gear
## found in the Explorer's Kit a short walk from the spawn (`world/explorer_kit.gd`),
## and a button that opens an empty notebook before the drone owns one reads as a
## broken screen rather than as something still to come. It is greyed rather than
## hidden — the panel keeps its shape and the player can see there is a thing to come
## back for (the same reason `ui/splash.gd` greys the resolution row out instead of
## hiding it). `_book_found()` is the one question both the refresh and the door ask,
## so the button and the refusal cannot drift apart.
##
## This node is the only one that listens for ESC: while any of those screens is
## open the key walks that screen back instead of resuming the game.

## The item the Pedia *is*: found in the Explorer's Kit, carried for the rest of the run
## (`player.gd`'s KEEPSAKE_ITEMS), and the thing that has to be in the bag before there is
## anything to read.
const NOTEBOOK_ITEM := "notebook"

@onready var pedia: Control = $Pedia
@onready var saves: Control = $Saves
@onready var editor: Control = $Editor
@onready var menu: CenterContainer = $Center
@onready var pedia_button: Button = $Center/Padding/Panel/VBox/PediaButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Button presses are wired via [connection] entries in pause_menu.tscn.
	pedia.closed.connect(_on_pedia_closed)
	saves.closed.connect(_on_saves_closed)
	editor.closed.connect(_on_editor_closed)
	# Until it can be asked, the answer is "no notebook": this runs before the menu is in
	# a world at all, and `open()` asks again every time the player actually pauses.
	_refresh_pedia_button()


func _book_found() -> bool:
	## Whether this run is carrying the notebook: the bag is the truth about what the
	## drone has (`player.has_item`, the same answer `world/explorer_kit.gd` gives gear
	## when it decides what to hand over). No run around the menu — or a host without a
	## player in it — answers no, so the gate fails closed rather than open.
	var scene := get_tree().current_scene
	var player: Node = scene.get_node_or_null("Player") if scene != null else null
	if player == null or not player.has_method("has_item"):
		return false
	return player.has_item(NOTEBOOK_ITEM)


func _refresh_pedia_button() -> void:
	## Grey the button, and let being disabled be the whole of both the refusal and the
	## message: Godot never emits `pressed` from a disabled Button and skips it in the
	## focus chain, so mouse, keyboard and pad all get the same answer without a second
	## rule to keep in sync. And it says nothing about why — no tooltip, no hint line,
	## deliberately: the greyed row *is* the answer, and it is greyed rather than hidden
	## so the change in the row reads as "not yet" rather than as "broken".
	pedia_button.disabled = not _book_found()


func _unhandled_input(event: InputEvent) -> void:
	# Only runs while visible+paused (this node is WHEN_PAUSED). This node is the
	# only listener for ESC, which is why the Saves screen is opened with
	# escape_closes = false: here, ESC walks back out of whatever is open.
	if visible and event.is_action_pressed("ui_cancel"):
		if pedia.visible:
			pedia.back()   # one page up; closing the book lands back here
		elif saves.visible:
			saves.close()  # which lands back here too
		elif editor.visible:
			editor.close() # which lands back in the world (see _on_editor_closed)
		else:
			_on_continue()


func open() -> void:
	visible = true
	# Never resume play with the book, the saves list or the frame screen open — a
	# fresh pause shows the menu.
	if pedia.visible:
		pedia.close()
	if saves.visible:
		saves.close()
	if editor.visible:
		editor.close()
	_set_crosshair_visible(false)
	_apply_padding()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The notebook is found out in the world, so the button is re-read every time the menu
	# comes up: pick the kit up, pause again, and the book is there.
	_refresh_pedia_button()
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
	## The disabled button is the refusal the player sees; this is the refusal itself,
	## because this is the one door into the book and it should not open for a caller
	## that got past the button (a direct call, a future hotkey, a test).
	if not _book_found():
		return
	menu.hide()
	pedia.open()


func open_editor(bench: Node = null) -> void:
	## Opened from a service bench in the world (world/bench.gd) — the only way in.
	## There is no button for it here: finding a bench is the point. Because it is
	## not opened *from* this menu, it does the whole open dance itself — pause,
	## release the mouse, step the menu aside — and closing it resumes play instead
	## of showing the menu (the player was playing, not browsing).
	visible = true
	if pedia.visible:
		pedia.close()
	if saves.visible:
		saves.close()
	_set_crosshair_visible(false)
	_apply_padding()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.hide()
	editor.open(bench)


func _on_editor_closed() -> void:
	## Straight back into the game, standing at the bench. ESC never comes here
	## twice: `_unhandled_input` routed the key to `editor.close()`, and this is the
	## one place that answer is acted on.
	_on_continue()


func _on_pedia_closed() -> void:
	menu.show()
	$Center/Padding/Panel/VBox/Continue.grab_focus()
