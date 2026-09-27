extends SceneTree
## Headless check: 16 slots, first-free-slot pickup flow, equipping,
## full-inventory rejection, savegame round-trip, and death wiping items.
## Restores the user's real saves afterwards, via tests/save_guard.gd.

const SaveGuard := preload("res://tests/save_guard.gd")


func _wheel(up: bool, shift := false) -> void:
	## A real wheel event through the ordinary pipeline: `player._unhandled_input` is what
	## decides whether a wheel walks the hotbar or zooms, so nothing here calls the
	## inventory directly.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.shift_pressed = shift
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	# The machine's saves belong to whoever is playing: snapshot them first.
	var guard := SaveGuard.new()

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

	# 3b. The mouse wheel walks the hotbar: the number keys' job by hand, **skipping empty
	#     slots** and wrapping (Maurice's call). Sent as a real wheel event, because the
	#     *player* is what turns a wheel into a selection — and Shift is held for the zoom
	#     (`tests/test_instrument_zoom.gd`), so that split is checked here too.
	# The fade-in overlay swallows input until it clears (`player._lock_check`), so the wheel
	# has to wait for the run to be listening at all.
	for i in 60:
		await physics_frame
	inv.slots[5] = "shell"
	inv.counts[5] = 1
	inv.equip(0)
	# 0 -> 1: the next held slot along.
	_wheel(false)
	await physics_frame
	if inv.equipped_slot != 1:
		fails.append("wheel_down_to_%d" % inv.equipped_slot)
	# 1 -> 5: slots 2, 3 and 4 are empty, so they are stepped over.
	_wheel(false)
	await physics_frame
	if inv.equipped_slot != 5:
		fails.append("wheel_did_not_skip_empties:%d" % inv.equipped_slot)
	# 5 -> 1: and back over them.
	_wheel(true)
	await physics_frame
	if inv.equipped_slot != 1:
		fails.append("wheel_up_did_not_skip_empties:%d" % inv.equipped_slot)
	# 1 -> 0.
	_wheel(true)
	await physics_frame
	if inv.equipped_slot != 0:
		fails.append("wheel_up_to_%d" % inv.equipped_slot)
	# 0 -> 5: it wraps rather than dead-ending at the first slot.
	_wheel(true)
	await physics_frame
	if inv.equipped_slot != 5:
		fails.append("wheel_up_did_not_wrap:%d" % inv.equipped_slot)
	# Shift+wheel is the zoom (`tests/test_instrument_zoom.gd`): the selection must not move.
	_wheel(false, true)
	await physics_frame
	if inv.equipped_slot != 5:
		fails.append("shift_wheel_moved_the_selection:%d" % inv.equipped_slot)
	# Put the bar back the way the cases below expect it: two items, the second held.
	inv.slots[5] = ""
	inv.counts[5] = 0
	inv.equip(1)

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

	# Put the machine's saves back.
	guard.restore()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
