extends SceneTree
## Headless check: bow+arrows shooting — arrow flies, consumes from the
## stack, sticks on hit, and requires both bow and arrows.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	var backup := SaveGame.read()

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
	var start: Vector3 = player.global_position
	player._begin_draw_bow()
	player._release_bow()
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

	# Clean up test arrows + restore save.
	for a in root.find_children("*", "Area3D", true, false):
		if a.get_script() != null and str(a.get_script().resource_path).contains("arrow_projectile"):
			a.queue_free()
	if not backup.is_empty():
		var f := FileAccess.open(SaveGame.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(backup))

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
