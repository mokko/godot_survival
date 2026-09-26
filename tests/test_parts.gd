extends SceneTree
## Headless check: robot parts — three of them lie in the world, picking one up puts it
## straight on the robot and never in the inventory, only owned parts can be fitted, the
## Frame screen lists exactly what the drone owns with the fit it is wearing marked, and
## the whole lot rides in the save.

const Legs := preload("res://player/legs.gd")
const Parts := preload("res://player/robot_parts.gd")


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	var player = main.get_node("Player")
	var equip: Node3D = player.get_node("Equipment")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var editor: Control = menu.get_node("Editor")
	var fails: PackedStringArray = []
	Parts.clear()

	# 1. One part in the world per catalogue fit, all on dry ground with something to see.
	var pickups: Array = get_nodes_in_group("part_pickup")
	if pickups.size() != Legs.PARTS.size():
		fails.append("part_pickups=%d (want %d)" % [pickups.size(), Legs.PARTS.size()])
	var seen: Dictionary = {}
	for p in pickups:
		var id := str(p.part_id)
		seen[id] = true
		if not Legs.NAMES.has(id):
			fails.append("%s is not a fit the legs catalogue knows" % id)
		if not Ezo.is_land(p.global_position.x, p.global_position.z):
			fails.append("%s is not on land" % id)
		if p.get_node_or_null("Mesh") == null:
			fails.append("%s has no mesh" % id)
		# Its prompt must be able to clear while a menu is up, which needs it to keep
		# processing through the pause — the same reason the bench does.
		if p.process_mode != Node.PROCESS_MODE_ALWAYS:
			fails.append("%s stops processing while paused, so its prompt cannot clear" % id)
	for id in Legs.PARTS:
		if not seen.has(id):
			fails.append("%s lies nowhere in the world" % id)
	# Two parts must not be on top of each other, or one hides the other.
	for i in pickups.size():
		for j in range(i + 1, pickups.size()):
			var a: Vector3 = pickups[i].global_position
			var b: Vector3 = pickups[j].global_position
			if a.distance_to(b) < 5.0:
				fails.append("%s and %s are in the same spot"
						% [pickups[i].part_id, pickups[j].part_id])

	# 2. Picking one up goes onto the robot, not into the bag.
	var first: Node3D = pickups[0]
	var first_id := str(first.part_id)
	var items_before := _item_total(player)
	first._on_body_entered(player)
	if not Parts.has(first_id):
		fails.append("picking up %s did not put it on the robot" % first_id)
	if _item_total(player) != items_before:
		fails.append("picking up a part added something to the inventory")
	if not first._collected:
		fails.append("the pickup did not mark itself collected")
	if Parts.own(first_id):
		fails.append("the same part could be found twice")

	# 3. Ownership: the stock fit is the drone's own, an unfound part is not, and nothing
	#    can be fitted by guessing an id.
	if not player.owns_part(Legs.STOCK):
		fails.append("the drone does not own its own treads")
	if player.owns_part("legs_three"):
		fails.append("a part it has not found reads as owned")
	if player.fit_legs("legs_three"):
		fails.append("fitted a part the drone had not found")
	if player.fit_legs("legs_dragon"):
		fails.append("fitted a part that does not exist")
	if equip.fitted_legs() != Legs.STOCK:
		fails.append("a refused fit changed the drone to %s" % equip.fitted_legs())

	# 4. The Frame screen: opened from a bench, listing what is owned and nothing else.
	var bench: Node3D = get_nodes_in_group("bench")[0]
	player.global_position = bench.global_position + Vector3(0.0, 0.0, 2.0)
	for i in 2:
		await physics_frame
	if not bench.use_for_test(player):
		fails.append("the bench did not open the frame screen")
	for i in 2:
		await process_frame
	if not editor.visible:
		fails.append("the frame screen is not visible after a bench")
	var rows: Array = editor.rows()
	var expected := _expected_rows(player)
	if rows != expected:
		fails.append("the screen lists %s, the drone owns %s" % [str(rows), str(expected)])

	# Finding another part puts it on the list; an unfound one stays off it.
	for p in pickups:
		if str(p.part_id) == "legs_three":
			p._on_body_entered(player)
	editor.refresh()
	rows = editor.rows()
	if not rows.has("legs_three"):
		fails.append("a found part is not listed: %s" % str(rows))
	if rows.has("legs_telescope"):
		fails.append("a part that was never found is listed: %s" % str(rows))

	# The row already on the drone is marked and inert; another row fits itself.
	var stock_row: Button = editor.fits.get_node("Fit_%s" % Legs.STOCK)
	if not stock_row.disabled:
		fails.append("the fitted row can still be pressed")
	if not stock_row.text.contains("fitted"):
		fails.append("the fitted row does not say so: '%s'" % stock_row.text)
	var row: Button = editor.fits.get_node("Fit_legs_three")
	row.pressed.emit()
	for i in 2:
		await process_frame
	if equip.fitted_legs() != "legs_three":
		fails.append("pressing a row did not fit it (%s)" % equip.fitted_legs())
	editor.refresh()
	if not editor.fits.get_node("Fit_legs_three").disabled:
		fails.append("the newly fitted row is still pressable")
	if editor.rows() != _expected_rows(player):
		fails.append("the list changed after fitting: %s" % str(editor.rows()))

	# 5. It all rides in the save, and comes back.
	var state: Dictionary = player.save_state()
	var saved: Array = state.get("parts", [])
	if not (saved.has("tread_triangle") or saved.has("legs_three")):
		fails.append("save has no parts: %s" % str(saved))
	Parts.clear()
	player.load_state(state)
	if not (Parts.has(first_id) and Parts.has("legs_three")):
		fails.append("the parts did not come back from the save")
	if equip.fitted_legs() != "legs_three":
		fails.append("the fitted part did not come back (%s)" % equip.fitted_legs())

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _expected_rows(player: Node) -> Array:
	## What the Frame screen must be listing: everything the drone owns, in catalogue
	## order. Derived rather than hardcoded, so the assertion is the invariant ("the
	## screen shows exactly what it owns") and not a restatement of the test's setup.
	var out: Array = []
	for id in ([Legs.STOCK] + Legs.PARTS):
		if player.owns_part(id):
			out.append(id)
	return out


func _item_total(player: Node) -> int:
	## How much the inventory is carrying, so "a part did not go into the bag" is a
	## measurement rather than an assumption.
	var inv = player.inventory
	if inv == null:
		return 0
	var total := 0
	for i in inv.SLOTS:
		total += int(inv.counts[i])
	return total