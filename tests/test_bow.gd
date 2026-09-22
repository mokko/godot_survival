extends SceneTree
## Headless check: bow+arrows shooting — arrow flies, consumes from the
## stack, sticks on hit, and requires both bow and arrows.
## Puts the machine's saves back via tests/save_guard.gd (this test dies once).

const SaveGuard := preload("res://tests/save_guard.gd")

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	var guard := SaveGuard.new()

	# No bow, no arrows: nothing happens.
	player._begin_draw_bow()
	player._release_bow()
	if get_nodes_in_group("player").size() == 0:
		fails.append("player_gone")

	# Give bow + 10 arrows; draw, release -> one arrow in flight, stack 9.
	player.add_item("bow")
	player.add_item("arrows")
	player.add_item("arrows")
	if not player.has_bow() or not player.has_arrows():
		fails.append("has_items")
	# Regression: firing must not change what the player is holding. release
	# used to equip the arrow stack, so the held item became "arrows" and the
	# next left-click grabbed blocks instead of slashing.
	var held_before: String = inv.get_equipped_item()
	var slot_before: int = inv.equipped_slot
	var start: Vector3 = player.global_position
	player._begin_draw_bow()
	player._release_bow()
	if held_before != "bow":
		fails.append("held_before_was_bow")
	if inv.get_equipped_item() != held_before or inv.equipped_slot != slot_before:
		fails.append("held_weapon_swapped")
	var arrows: Array = root.find_children("*", "Area3D", true, false).filter(
			func(n): return n.get_script() != null \
				and str(n.get_script().resource_path).contains("arrow_projectile"))
	if arrows.size() != 1:
		fails.append("one_arrow")
	if inv.counts[1] != 9:
		fails.append("stack_consumed")

	# Arrow travels: let it fly a bit.
	if arrows.is_empty():
		print("RESULT FAIL: no arrow spawned")
		quit(1)
		return
	var arrow: Area3D = arrows[0]
	var p0: Vector3 = arrow.global_position
	for i in 10:
		await physics_frame
	if arrow.global_position.distance_to(p0) < 0.5:
		fails.append("arrow_moves")

	# Empty stack: can't shoot.
	inv.counts[1] = 1
	inv._refresh()
	player._begin_draw_bow()
	player._release_bow()
	if inv.counts[1] != 0 or inv.slots[1] != "":
		fails.append("last_arrow")
	var arrows2: int = root.find_children("*", "Area3D", true, false).filter(
			func(n): return n.get_script() != null \
				and str(n.get_script().resource_path).contains("arrow_projectile")).size()
	if arrows2 != 2:
		fails.append("no_arrow_without_stack")

	# No bow: can't draw.
	inv.slots[1] = "arrows"
	inv.counts[1] = 5
	inv._refresh()
	player._begin_draw_bow()
	player._release_bow()
	if player.combat.get_meta("bow_drawn", false):
		fails.append("no_bow_no_draw")

	# Clean up test arrows + put the saves back the way they were.
	for a in root.find_children("*", "Area3D", true, false):
		if a.get_script() != null and str(a.get_script().resource_path).contains("arrow_projectile"):
			a.queue_free()
	guard.restore()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
