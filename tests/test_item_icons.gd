extends SceneTree
## Headless check: inventory slots show procedural icons instead of item-name
## text. Covers icon coverage (every ItemDB id has distinct art), well-formed
## draw ops, and the slot wiring (icon id matches the slot, hotkey numbers on
## empty slots only, count badge only for stacks of 2+).

const ItemDB := preload("res://items/item_db.gd")
const ItemIcons := preload("res://ui/item_icons.gd")

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	# 1. Every item in the DB has its own icon art, and the art is well formed:
	#    non-empty, every op carries a kind + colour, and coordinates stay in
	#    the box the slot hands over.
	var size := Vector2(36, 36)
	var seen: Dictionary = {}
	for id in ItemDB.ITEMS:
		if not ItemIcons.ICON_IDS.has(id):
			fails.append("no_art:%s" % id)
			continue
		var ops: Array = ItemIcons.icon_ops(id, size)
		if ops.is_empty():
			fails.append("empty_art:%s" % id)
			continue
		for op in ops:
			if not op.has("kind") or not op.has("color"):
				fails.append("bad_op:%s" % id)
				break
			for p in _points_of(op):
				if p.x < -0.5 or p.y < -0.5 \
						or p.x > size.x + 0.5 or p.y > size.y + 0.5:
					fails.append("out_of_box:%s" % id)
					break
		# Two items sharing identical art would mean a copy-paste slip.
		var key := var_to_str(ops)
		if seen.has(key):
			fails.append("duplicate_art:%s=%s" % [id, seen[key]])
		seen[key] = id

	# An empty id must draw nothing (the slot frame alone shows through).
	if not ItemIcons.icon_ops("", size).is_empty():
		fails.append("empty_id_draws")

	# 2. Slot wiring: pick items up and check what each slot shows.
	player.add_item("flint")
	player.add_item("sword")
	player.add_item("arrows")     # stackable: 5 in one slot
	player.add_item("arrows")     # tops up to 10
	for i in 3:
		await process_frame

	var rows: Array = inv._slot_panels
	if rows.size() != 16:
		fails.append("slot_count")
	else:
		# Filled slot: icon carries the item id, no hotkey number.
		var s0: Dictionary = rows[0]
		if s0["icon"].item_id != "flint":
			fails.append("icon_id:flint=%s" % s0["icon"].item_id)
		if s0["hotkey"].text != "":
			fails.append("filled_slot_hotkey_text")
		if s0["badge"].text != "":
			fails.append("single_item_badge:%s" % s0["badge"].text)
		# Stack: badge shows the count.
		var s2: Dictionary = rows[2]
		if s2["icon"].item_id != "arrows" or s2["badge"].text != "x10":
			fails.append("stack_badge:%s %s" % [s2["icon"].item_id, s2["badge"].text])
		# Empty slot: no icon art, hotkey number still visible.
		var s9: Dictionary = rows[9]
		if s9["icon"].item_id != "" \
				or not ItemIcons.icon_ops(s9["icon"].item_id, size).is_empty():
			fails.append("empty_slot_icon")
		if s9["hotkey"].text != "10":
			fails.append("empty_slot_hotkey:%s" % s9["hotkey"].text)
		# No slot anywhere may print an item name (the whole point).
		for row in rows:
			for txt in [String(row["hotkey"].text), String(row["badge"].text)]:
				for id in ItemDB.ITEMS:
					if txt.contains(ItemDB.item_name(id)):
						fails.append("name_text_in_slot:%s" % txt)
						break

	# 3. Icons actually reach the canvas: render a frame with a filled slot and
	#    make sure the icon node reports a non-zero drawable rect.
	var icon: Control = inv._slot_panels[0]["icon"]
	icon.queue_redraw()
	await process_frame
	if icon.size.x <= 0.0 or icon.size.y <= 0.0:
		fails.append("icon_rect_zero")

	# Leave the inventory as we found it (this runs against the live scene).
	inv.clear_all()
	player.add_item("flint")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _points_of(op: Dictionary) -> Array:
	## Every Vector2 an op will draw, so the box check covers all kinds.
	match op["kind"]:
		"poly", "polyline":
			return op["points"]
		"line":
			return [op["from"], op["to"]]
		"circle", "ring", "arc":
			# Centre plus the ring itself.
			return [op["center"] - Vector2.ONE * op["radius"],
					op["center"] + Vector2.ONE * op["radius"]]
		"rect":
			return [op["rect"].position,
					op["rect"].position + op["rect"].size]
		"text":
			# The baseline anchor; a drawn word can run past the box, which is
			# what op["size"] is for and why the art keeps its text off the edge.
			return [op["pos"]]
	return []
