extends SceneTree
## Headless check: 16 slots, first-free-slot pickup flow, equipping,
## full-inventory rejection, savegame round-trip, and death wiping items.
## Restores the user's real savegame.json afterwards.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	# Back up the user's real save so tests can't destroy it.
	var backup := SaveGame.read()

	# 1. Inventory exists with 16 empty slots.
	if inv == null or inv.slots.size() != 16 or not inv.slots.all(func(s): return s == ""):
		fails.append("init")

	# 2. First-free-slot order + auto-equip of first item.
	player.add_item("flint")
	player.add_item("stick")
	if inv.slots[0] != "flint" or inv.slots[1] != "stick" or inv.equipped_slot != 0:
		fails.append("first_free")

	# 3. Equip via API.
	inv.equip(1)
	if player.get_equipped_item() != "stick":
		fails.append("equip")

	# 4. Fill up; 17th item is rejected.
	for i in 14:
		player.add_item("shell")
	if not inv.is_full() or player.add_item("flint"):
		fails.append("full_rejects")

	# 7. Arrows stack: packs of 5 top up to the 50 ceiling, then next slot.
	player.add_item("arrows")
	player.add_item("arrows")
	if inv.slots[0] != "arrows" or inv.counts[0] != 10:
		fails.append("arrow_stack")   # 5 + 5 = one stack of 10
	for i in 8:
		player.add_item("arrows")
	if inv.counts[0] != 50 or inv.slots[1] != "arrows" or inv.counts[1] != 5:
		fails.append("arrow_ceil")    # 10 + 40 -> 50, remainder starts slot 2

	# 7. Savegame round-trip.
	var state: Dictionary = player.save_state()
	inv.slots.fill("")
	inv.counts.fill(0)
	inv.equipped_slot = -1
	player.load_state(state)
	if inv.slots[0] != "arrows" or inv.counts[0] != 50 or inv.equipped_slot != 1:
		fails.append("save")

	# 8. Death wipes inventory (and its own saved items).
	player._trigger_game_over()
	if not inv.slots.all(func(s): return s == "") or inv.equipped_slot != -1:
		fails.append("death_wipes")
	if not player.save_state().get("items", []).all(func(s): return s == ""):
		fails.append("death_save_wiped")

	# Restore the user's real save.
	if not backup.is_empty():
		var f := FileAccess.open(SaveGame.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(backup))

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
