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

	# 4. Arrows stack: packs of 5 top up to the 50 ceiling, then next slot.
	# (Done on a half-empty inventory: 2 items + 10 packs = 12 slots used.)
	player.add_item("arrows")
	player.add_item("arrows")
	if inv.slots[2] != "arrows" or inv.counts[2] != 10:
		fails.append("arrow_stack")   # 5 + 5 = one stack of 10
	for i in 9:
		player.add_item("arrows")
	if inv.counts[2] != 50 or inv.slots[3] != "arrows" or inv.counts[3] != 5:
		fails.append("arrow_ceil")    # 11 packs = 55: 50 fills slot 3, 5 spill to slot 4

	# 5. Fill up; a further item is rejected.
	for i in 12:
		player.add_item("shell")
	if not inv.is_full() or player.add_item("flint"):
		fails.append("full_rejects")

	# 7. Savegame round-trip.
	var state: Dictionary = player.save_state()
	inv.slots.fill("")
	inv.counts.fill(0)
	inv.equipped_slot = -1
	player.load_state(state)
	if inv.slots[2] != "arrows" or inv.counts[2] != 50 or inv.equipped_slot != 1:
		fails.append("save")

	# 8. Death wipes inventory (and its own saved items).
	player._trigger_game_over()
	if not inv.slots.all(func(s): return s == "") or inv.equipped_slot != -1:
		fails.append("death_wipes")
	if not player.save_state().get("items", []).all(func(s): return s == ""):
		fails.append("death_save_wiped")

	# 9. restore() invariants: an empty slot never carries a count, and a
	# non-empty slot is never left at zero. Both were possible before.
	inv.restore(["flint", "", "arrows"], [0, 0, 7])
	if inv.counts[1] != 0:
		fails.append("restore_empty_slot_count")
	if inv.counts[0] < 1:
		fails.append("restore_zero_count")
	if inv.counts[2] != 7:
		fails.append("restore_kept_count")
	# Counts array shorter than the slot list: empty slots must read 0, not 1.
	inv.restore(["", "", ""], [])
	if inv.counts[0] != 0 or inv.counts[1] != 0 or inv.counts[2] != 0:
		fails.append("restore_defaulted_counts")
	inv.clear_all()

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
