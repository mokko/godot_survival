extends Control
## Inventory overlay: 16 slots along the bottom of the screen. Items go to
## the first free slot automatically. Slots 1-8 are hotkeys (1-8) — pressing
## a number "equips" that slot (highlight; held item name shown above).

signal item_equipped(slot: int)
signal armor_changed(armor_id: String, durability: float)

const SLOTS := 16
const PACK_SIZE := 5                  # arrows come in packs of 5
const STACK_LIMITS := {"arrows": 50}   # item id -> max per slot (stackable)
const ItemDB := preload("res://items/item_db.gd")

var slots: Array = []            # String item ids, "" = empty
var counts: Array = []           # stack count per slot (1 for normal items)
var equipped_slot: int = -1

var _slot_panels: Array = []
var _held_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.resize(SLOTS)
	slots.fill("")
	counts.resize(SLOTS)
	counts.fill(0)

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
	## Stackable items first top up existing stacks (up to the stack limit),
	## then take a free slot. Normal items go to the first free slot.
	## Returns false when nothing fits.
	var limit: int = STACK_LIMITS.get(item_id, 1)
	if limit > 1:
		# Top up existing stacks that have room.
		for i in SLOTS:
			if slots[i] == item_id and counts[i] < limit:
				var take: int = mini(limit - counts[i], PACK_SIZE)   # arrows come in packs of 5
				counts[i] += take
				if equipped_slot == -1:
					equip(i)
				else:
					_refresh()
				return true
	for i in SLOTS:
		if slots[i] == "":
			slots[i] = item_id
			counts[i] = mini(PACK_SIZE, limit) if limit > 1 else 1
			if equipped_slot == -1:
				equip(i)
			else:
				_refresh()
			return true
	return false


func consume_one_equipped() -> bool:
	## Remove one unit from the equipped stack (arrows). Returns false when
	## the equipped slot is empty. Empties the slot when the stack runs out.
	if equipped_slot < 0 or equipped_slot >= SLOTS or slots[equipped_slot] == "":
		return false
	counts[equipped_slot] = maxi(counts[equipped_slot] - 1, 0)
	if counts[equipped_slot] == 0:
		slots[equipped_slot] = ""
		counts[equipped_slot] = 0
		# Keep the now-empty slot equipped rather than jumping elsewhere.
	_refresh()
	return true


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


var worn_armor_id := ""        # armor currently worn (slot stays in inventory)


func equip_armor_from_inventory() -> void:
	## Key E: wear the armor in the equipped slot, or take armor off if the
	## equipped slot holds the worn armor.
	if equipped_slot < 0 or equipped_slot >= SLOTS:
		return
	var id: String = slots[equipped_slot]
	if id == worn_armor_id:
		worn_armor_id = ""      # take it off
		armor_changed.emit("", 0.0)
		_refresh()
		return
	var stats: Dictionary = load("res://items/armor.gd").STATS.get(id, {})
	if stats.is_empty():
		return                  # equipped item is not armor
	worn_armor_id = id
	armor_changed.emit(id, float(stats.get("durability", 100.0)))
	_refresh()


func wear_armor(id: String, durability: float) -> void:
	## Programmatic wear (used on savegame load).
	worn_armor_id = id
	armor_changed.emit(id, durability)


func is_full() -> bool:
	return not slots.has("")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < 9:
			equip(idx)
		elif event.keycode == KEY_E:
			equip_armor_from_inventory()


func _refresh() -> void:
	for i in SLOTS:
		var ui: Dictionary = _slot_panels[i]
		var panel: PanelContainer = ui["panel"]
		var lab: Label = ui["label"]
		var id: String = slots[i]
		if id != "":
			var n: int = counts[i]
			lab.text = ItemDB.item_name(id) if n <= 1 else "%s x%d" % [ItemDB.item_name(id), n]
		else:
			lab.text = str(i + 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.55)
		style.set_corner_radius_all(4)
		style.set_border_width_all(2)
		if id == worn_armor_id:
			style.border_color = Color(0.3, 0.8, 0.9)   # worn: cyan
		elif i == equipped_slot:
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
