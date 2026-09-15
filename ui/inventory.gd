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
const ItemIcons := preload("res://ui/item_icons.gd")

const SLOT_SIZE := Vector2(48, 48)
const ICON_INSET := 6        # px between slot border and icon
const BADGE_SIZE := 12

var slots: Array = []            # String item ids, "" = empty
var counts: Array = []           # stack count per slot (1 for normal items)
var equipped_slot: int = -1

var _slot_panels: Array = []
var _held_label: Label
var _slot_styles: Dictionary = {}   # kind -> shared StyleBoxFlat


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
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Cell holds the item icon plus two number-only overlays: the hotkey
		# index (empty slots) and the stack count badge (stackables only).
		# Item *names* never appear in a slot any more.
		var cell := Control.new()
		cell.custom_minimum_size = SLOT_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := ItemIcons.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = ICON_INSET
		icon.offset_top = ICON_INSET
		icon.offset_right = -ICON_INSET
		icon.offset_bottom = -ICON_INSET
		cell.add_child(icon)

		var hotkey := Label.new()
		hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hotkey.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hotkey.add_theme_font_size_override("font_size", 11)
		hotkey.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		hotkey.set_anchors_preset(Control.PRESET_FULL_RECT)
		hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hotkey)

		var badge := Label.new()
		badge.add_theme_font_size_override("font_size", BADGE_SIZE)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -24
		badge.offset_top = -16
		badge.offset_right = -3
		badge.offset_bottom = -1
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(badge)

		panel.add_child(cell)
		row.add_child(panel)
		_slot_panels.append({"panel": panel, "icon": icon,
				"hotkey": hotkey, "badge": badge})

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


func consume_one(slot: int) -> bool:
	## Remove one unit from a specific stack WITHOUT promoting that slot to
	## the equipped slot — shooting an arrow must not swap the held weapon.
	## Returns false when the slot is empty. Clears the slot when it runs out.
	if slot < 0 or slot >= SLOTS or slots[slot] == "":
		return false
	counts[slot] = maxi(counts[slot] - 1, 0)
	if counts[slot] == 0:
		slots[slot] = ""
		counts[slot] = 0
		if equipped_slot == slot:
			equipped_slot = -1      # nothing held any more
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


func restore(items: Array, counts_in: Array) -> void:
	## Replace the whole inventory (savegame load). Invalid ids are kept as-is;
	## arrays are clamped to SLOTS.
	slots.resize(SLOTS)
	slots.fill("")
	counts.resize(SLOTS)
	counts.fill(0)
	for i in mini(items.size(), SLOTS):
		slots[i] = str(items[i])
		if slots[i] == "":
			counts[i] = 0        # an empty slot must never carry a count
		else:
			# A non-empty slot always holds at least one unit.
			counts[i] = maxi(
					int(counts_in[i]) if i < counts_in.size() else 1, 1)
	_refresh()


func clear_all() -> void:
	## Empty every slot (death penalty).
	slots.fill("")
	counts.fill(0)
	equipped_slot = -1
	_refresh()


func refresh() -> void:
	## Public refresh entry point (savegame load, external mutations).
	_refresh()


func _slot_style(kind: String) -> StyleBoxFlat:
	## The four slot styles, built once and shared. Rebuilding a StyleBoxFlat
	## per slot per refresh allocated 16 objects on every inventory change.
	if _slot_styles.has(kind):
		return _slot_styles[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	match kind:
		"worn":
			style.border_color = Color(0.3, 0.8, 0.9)    # worn: cyan
		"equipped":
			style.border_color = Color(1.0, 0.85, 0.2)
		"filled":
			style.border_color = Color(0.4, 0.5, 0.6)
		_:
			style.border_color = Color(0.25, 0.25, 0.28)
	_slot_styles[kind] = style
	return style


func _refresh() -> void:
	for i in SLOTS:
		var ui: Dictionary = _slot_panels[i]
		var panel: PanelContainer = ui["panel"]
		var icon: Control = ui["icon"]
		var hotkey: Label = ui["hotkey"]
		var badge: Label = ui["badge"]
		var id: String = slots[i]
		var n: int = counts[i]
		icon.set_item(id)
		# Hotkey index only on empty slots; the count badge only when a stack
		# holds more than one. Everything else is the icon itself.
		hotkey.text = "" if id != "" else str(i + 1)
		badge.text = "x%d" % n if id != "" and n > 1 else ""
		# Same precedence as before: worn beats equipped beats merely filled.
		var kind := "empty"
		if id == worn_armor_id:
			kind = "worn"
		elif i == equipped_slot:
			kind = "equipped"
		elif id != "":
			kind = "filled"
		panel.add_theme_stylebox_override("panel", _slot_style(kind))
	if equipped_slot >= 0 and slots[equipped_slot] != "":
		_held_label.text = "Held: %s" % ItemDB.item_name(slots[equipped_slot])
	else:
		_held_label.text = ""
