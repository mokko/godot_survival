extends Control
## Inventory overlay: 16 slots along the bottom of the screen. Items go to
## the first free slot automatically. Slots 1-8 are hotkeys (1-8) — pressing
## a number "equips" that slot (highlight; held item name shown above).

signal item_equipped(slot: int)

const SLOTS := 16
const ItemDB := preload("res://items/item_db.gd")

var slots: Array = []            # String item ids, "" = empty
var equipped_slot: int = -1

var _slot_panels: Array = []
var _held_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.resize(SLOTS)
	slots.fill("")

	# Held-item name floating above the bar.
	_held_label = Label.new()
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.add_theme_font_size_override("font_size", 14)
	add_child(_held_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(48, 48)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 11)
		lab.text = str(i + 1)
		panel.add_child(lab)
		row.add_child(panel)
		_slot_panels.append({"panel": panel, "label": lab})

	_refresh()


func add_item(item_id: String) -> bool:
	## First-free-slot insert; returns false when the inventory is full.
	for i in SLOTS:
		if slots[i] == "":
			slots[i] = item_id
			if equipped_slot == -1:
				equip(i)
			else:
				_refresh()
			return true
	return false


func equip(slot: int) -> void:
	if slot < 0 or slot >= SLOTS or slots[slot] == "":
		return
	equipped_slot = slot
	_refresh()
	item_equipped.emit(slot)


func get_equipped_item() -> String:
	if equipped_slot >= 0 and equipped_slot < SLOTS:
		return slots[equipped_slot]
	return ""


func is_full() -> bool:
	return not slots.has("")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < 9:
			equip(idx)


func _refresh() -> void:
	for i in SLOTS:
		var ui: Dictionary = _slot_panels[i]
		var panel: PanelContainer = ui["panel"]
		var lab: Label = ui["label"]
		var id: String = slots[i]
		lab.text = ItemDB.item_name(id) if id != "" else str(i + 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.55)
		style.set_corner_radius_all(4)
		style.set_border_width_all(2)
		if i == equipped_slot:
			style.border_color = Color(1.0, 0.85, 0.2)
		elif id != "":
			style.border_color = Color(0.4, 0.5, 0.6)
		else:
			style.border_color = Color(0.25, 0.25, 0.28)
		panel.add_theme_stylebox_override("panel", style)
	if equipped_slot >= 0 and slots[equipped_slot] != "":
		_held_label.text = "Held: %s" % ItemDB.item_name(slots[equipped_slot])
	else:
		_held_label.text = ""
