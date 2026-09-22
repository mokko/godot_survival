extends Control
## The Saves screen: five slots, one screen, two jobs.
##
## **Load mode** — opened from the splash's Load Game button. Pressing a row
## restores that slot: pending_load + pending_slot, then straight into the world,
## because the intro story belongs to a new run and this player has read it.
## Empty rows are shown but cannot be pressed: it is better to see that a slot is
## empty than to wonder why it is not there.
##
## The row for the slot this player was last *playing* holds focus and says so,
## and that is deliberate: it is the Continue button's old one-click resume,
## moved onto the row it meant (the autosave is not allowed to hijack it — see
## SaveGame.continue_slot). Open the screen, press Enter, and you are back where
## you stopped.
##
## **Save mode** — opened from the pause menu, where a row writes the current run
## into that slot. The row's name, rename and delete belong to that mode too.
##
## The rows are built in code rather than laid out in the scene: there are five
## of them, they are the same shape, and every word in them comes from SaveGame.
## Closing emits `closed` so whoever opened the screen can show itself again —
## the Pedia does the same, and for the same reason.
##
## **ESC**: this screen closes on it by default, because the splash screen has
## nobody else to own that key. The pause menu owns ESC for itself and sets
## `escape_closes` to false before opening this, so there is still exactly one
## owner and no race.

const SAVEGAME := preload("res://world/savegame.gd")

enum Mode { LOAD, SAVE }

## Emitted when the screen closes, so the pause menu can show itself again.
signal closed

## Emitted in load mode with the slot the player picked. The screen does not
## change scenes itself: whoever put it up knows what "loading that slot" means
## (the splash sets pending_load and enters the world; a test can simply listen).
signal slot_chosen(slot: int)

const ROW_FONT_SIZE := 24
const DETAIL_FONT_SIZE := 16

@onready var title: Label = $Center/Padding/Panel/VBox/Title
@onready var rows: VBoxContainer = $Center/Padding/Panel/VBox/Rows
@onready var hint: Label = $Center/Padding/Panel/VBox/Hint
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

## Whether this screen is the one that answers ESC. See the note above.
var escape_closes := true

var mode: int = Mode.LOAD

## The run to write in save mode. Set by whoever opens the screen from inside a
## game; null means there is nothing to save yet.
var player: Node = null

## A destructive press (overwriting a slot, deleting one) has to be made twice:
## the first press arms it and says so, any other press disarms it. Losing a save
## to a stray click is worse than pressing twice.
var _armed := {"slot": 0, "action": ""}

## The widgets of each row, by slot, so arming can restyle them in place instead
## of rebuilding the list (a rebuild would throw away a half-typed name).
var _rows := {}


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)


func open_for_load() -> void:
	mode = Mode.LOAD
	title.text = "Load Game"
	_open()


func open_for_save() -> void:
	mode = Mode.SAVE
	title.text = "Save Game"
	_open()


func _open() -> void:
	visible = true
	hint.text = "" if mode == Mode.SAVE else "Which save would you like to load?"
	_refresh()
	# Load mode: the slot last played is the row Continue used to open, so it is
	# the row holding focus — Load Game, Enter, and you are back in that run.
	# Anything else (save mode, no last-played save, an emptied slot) falls back
	# to the first pressable row.
	var resume_slot: int = SAVEGAME.continue_slot() if mode == Mode.LOAD else 0
	var target: Button = slot_button(resume_slot) if resume_slot != 0 else null
	if target == null or target.disabled:
		target = _first_pressable()
	if target != null:
		target.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func slot_button(slot: int) -> Button:
	## One row's button, by slot — what the tests (and the rename and delete
	## buttons) reach for instead of guessing at a child index.
	var node := rows.get_node_or_null("Row%d" % slot)
	if node == null:
		return null
	return node.get_node_or_null("Button") as Button


func slot_field(slot: int) -> LineEdit:
	## A row's name field (save mode only).
	var node := rows.get_node_or_null("Row%d" % slot)
	if node == null:
		return null
	return node.get_node_or_null("Name") as LineEdit


func slot_delete(slot: int) -> Button:
	## A row's delete button (save mode only).
	var node := rows.get_node_or_null("Row%d" % slot)
	if node == null:
		return null
	return node.get_node_or_null("Delete") as Button


func _refresh() -> void:
	_armed = {"slot": 0, "action": ""}
	_rows.clear()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for row in SaveGame.list_slots():
		rows.add_child(_make_row(row))


func _make_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	var slot := int(row.get("slot", 0))
	var empty := bool(row.get("empty", true))
	line.name = "Row%d" % slot
	line.add_theme_constant_override("separation", 12)

	var button := Button.new()
	button.name = "Button"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	# An empty slot is not a thing to load, and it is the thing to write into.
	# The autosave is never written by hand: it belongs to the clock.
	button.disabled = empty if mode == Mode.LOAD else SaveGame.is_autosave(slot)
	button.pressed.connect(_on_row_pressed.bind(slot))

	var detail := Label.new()
	detail.name = "Detail"
	detail.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.modulate = Color(1, 1, 1, 0.7)
	detail.text = SaveGame.describe(row)

	line.add_child(button)
	line.add_child(detail)

	var widgets := {"button": button, "detail": detail, "row": row}
	if mode == Mode.SAVE:
		var field := LineEdit.new()
		field.name = "Name"
		field.custom_minimum_size = Vector2(200, 0)
		field.placeholder_text = "name this save"
		field.text = SaveGame.default_name(slot) if empty else str(row.get("name", ""))
		field.text_submitted.connect(_on_name_submitted.bind(slot))
		var remove := Button.new()
		remove.name = "Delete"
		remove.text = "✕"
		remove.tooltip_text = "Delete this save"
		remove.disabled = empty
		remove.pressed.connect(_on_delete_pressed.bind(slot))
		line.add_child(field)
		line.add_child(remove)
		widgets["field"] = field
		widgets["delete"] = remove

	_rows[slot] = widgets
	_paint_row(slot)
	return line


func _paint_row(slot: int) -> void:
	## Restyle one row from the save on disk plus the armed state. Called instead
	## of rebuilding the list, so a half-typed name survives.
	var widgets: Dictionary = _rows.get(slot, {})
	if widgets.is_empty():
		return
	var row: Dictionary = widgets["row"]
	var button: Button = widgets["button"]
	var empty := bool(row.get("empty", true))
	var label: String = SaveGame.slot_label(slot)
	if empty:
		button.text = "%s — empty" % label
	else:
		button.text = "%s — %s" % [label, str(row.get("name", ""))]
		# Load mode: say which row is the one-click resume, so the player does
		# not have to remember which slot they were in.
		if mode == Mode.LOAD and slot == SAVEGAME.continue_slot():
			button.text += " · last played"
	if mode == Mode.SAVE and _is_armed(slot, "overwrite"):
		button.text = "%s — press again to overwrite" % label
	var remove: Button = widgets.get("delete")
	if remove != null:
		remove.text = "sure?" if _is_armed(slot, "delete") else "✕"


func _is_armed(slot: int, action: String) -> bool:
	return int(_armed.get("slot", 0)) == slot and str(_armed.get("action", "")) == action


func _arm(slot: int, action: String) -> void:
	_armed = {"slot": slot, "action": action}
	for s in _rows.keys():
		_paint_row(int(s))


func _disarm() -> void:
	if int(_armed.get("slot", 0)) == 0:
		return
	_armed = {"slot": 0, "action": ""}
	for s in _rows.keys():
		_paint_row(int(s))


func _first_pressable() -> Button:
	for row in rows.get_children():
		var button := row.get_node_or_null("Button") as Button
		if button != null and not button.disabled:
			return button
	return null


func _on_row_pressed(slot: int) -> void:
	if mode == Mode.LOAD:
		slot_chosen.emit(slot)
		return
	_save_into(slot)


func _save_into(slot: int) -> void:
	## Save mode's job. Without a run to hand there is nothing to write, which is
	## the state this screen is in when opened outside a game.
	if player == null:
		hint.text = "Nothing to save yet."
		return
	# Overwriting costs a save the player may want back, so it takes two presses:
	# the first arms the row and says what the second will do.
	if SaveGame.exists(slot) and not _is_armed(slot, "overwrite"):
		_arm(slot, "overwrite")
		hint.text = "%s already holds a save — press it again to overwrite it." \
				% SaveGame.slot_label(slot)
		return
	var field := slot_field(slot)
	var name := field.text if field != null else ""
	if SaveGame.write_slot(slot, player, name):
		hint.text = "Saved into %s." % SaveGame.slot_label(slot)
	else:
		hint.text = "Could not write %s." % SaveGame.slot_label(slot)
	_refresh()


func _on_name_submitted(slot: int, text: String) -> void:
	## Enter in the name field renames without writing the run over the slot: a
	## rename should not quietly replace an old save with the current one.
	if not SaveGame.exists(slot):
		hint.text = "Nothing in %s to rename." % SaveGame.slot_label(slot)
		return
	if SaveGame.rename_slot(slot, text):
		hint.text = "%s is now \"%s\"." % [SaveGame.slot_label(slot), SaveGame.slot_name(slot)]
	else:
		hint.text = "Could not rename %s." % SaveGame.slot_label(slot)
	_refresh()


func _on_delete_pressed(slot: int) -> void:
	## Deleting is the one action with no undo, so it takes two presses as well.
	if not _is_armed(slot, "delete"):
		_arm(slot, "delete")
		hint.text = "Delete %s? Press ✓ again to be sure." % SaveGame.slot_label(slot)
		return
	if SaveGame.delete_slot(slot):
		hint.text = "%s is gone." % SaveGame.slot_label(slot)
	else:
		hint.text = "Could not delete %s." % SaveGame.slot_label(slot)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventKey:
		_disarm()
	if not escape_closes:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()