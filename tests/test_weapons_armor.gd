extends SceneTree
## Headless check: weapon damage table, leather armor absorption + breakage,
## the player damage route through armor, and that armor cannot be repaired by
## taking it off and putting it back on.
##
## The player now has a short grace window after each hit (player.INVULN_TIME),
## which is tested in tests/test_player_hurt.gd. These loops deliberately clear
## it between iterations so they keep measuring armour, not grace.
## Puts the machine's saves back via tests/save_guard.gd (byte for byte, unlike the
## JSON round-trip this used to do).

const SaveGuard := preload("res://tests/save_guard.gd")

func _slot_of(inv, item_id: String) -> int:
	## Index of the first slot holding this item, -1 when it is not carried.
	for i in inv.SLOTS:
		if inv.slots[i] == item_id:
			return i
	return -1


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
	var ArmorClass: GDScript = load("res://items/armor.gd")
	var WeaponClass: GDScript = load("res://items/weapon.gd")

	# 1. Weapon damage table.
	if WeaponClass.damage_of("sword") != 25.0 or WeaponClass.damage_of("dagger") != 12.0 \
			or WeaponClass.damage_of("bow") != 15.0 or WeaponClass.damage_of("bogus") != 5.0:
		fails.append("weapon_table")

	# 2. Leather armor absorbs 30%.
	player.add_item("leather_armor")
	if not player.equip_armor("leather_armor"):
		fails.append("equip_armor")
	if player.armor_status()["id"] != "leather_armor":
		fails.append("armor_id")
	var life0: float = player.life
	player.life = 40.0
	life0 = 40.0
	player._invuln = 0.0
	player.damage(10.0)
	if absf(player.life - (life0 - 7.0)) > 0.01:
		fails.append("absorption_30")   # 10 * 0.3 eaten -> 7 through

	# 3. Armor degrades and breaks: durability 80, eats 3/hit at 10 dmg -> 1.5.
	var hits := 0
	while player.armor_status()["id"] != "" and hits < 100:
		player.life = 40.0   # keep alive so damage keeps flowing
		player._invuln = 0.0
		player.damage(10.0)
		hits += 1
	if player.armor_status()["id"] != "":
		fails.append("armor_never_breaks")
	# After break, full damage passes.
	player.life = 40.0
	var life1: float = player.life
	player._invuln = 0.0
	player.damage(10.0)
	if absf(player.life - (life1 - 10.0)) > 0.01:
		fails.append("broken_absorbs")

	# 4. UI path: key E on an armor slot wears it (inventory emits, HUD shows). A
	#    *fresh* piece, because the one broken in case 3 is broken for good: wear is
	#    remembered per item id, and only a new pickup starts whole.
	player.add_item("leather_armor")
	var slot := _slot_of(inv, "leather_armor")
	if slot < 0:
		fails.append("no_slot_for_fresh_armor")
	else:
		inv.equipped_slot = slot
		inv.equip_armor_from_inventory()
	if player.armor_status()["id"] != "leather_armor":
		fails.append("ui_equip")
	player.life = 40.0
	var lifeA: float = player.life
	player._invuln = 0.0
	player.damage(10.0)
	if absf(player.life - (lifeA - 7.0)) > 0.01:
		fails.append("ui_equip_absorbs")
	var armor_label: Label = null
	var hud: CanvasLayer = main.get_node("HUD")
	for child in hud.get_children():
		if child is Label and str(child.text).begins_with("Armor:"):
			armor_label = child
			break
	if armor_label == null or not armor_label.visible \
			or "Leather Armor" not in armor_label.text:
		fails.append("hud_label")
	if player.armor_status()["durability"] >= 80.0:
		fails.append("hud_durability_shown")   # must have degraded below max

	# 5. Key E again takes the armor off.
	inv.equip_armor_from_inventory()
	if player.armor_status()["id"] != "":
		fails.append("ui_remove")
	if armor_label.visible:
		fails.append("hud_label_hidden_after_removal")

	# 6. Unknown armor id rejected.
	if player.equip_armor("golden_plate"):
		fails.append("unknown_armor")

	# 7. armor_changed reports a state change (equip / break), not every hit.
	# It used to emit per hit, so the equip flourish fired on every scratch.
	var sig_count := [0]
	player.combat.armor_changed.connect(func(_id, _dur): sig_count[0] += 1)
	player.equip_armor("leather_armor")
	player.life = 40.0
	var after_equip: int = sig_count[0]
	player._invuln = 0.0
	player.damage(5.0)      # chips durability only — must not signal
	player.life = 40.0
	player._invuln = 0.0
	player.damage(5.0)
	if sig_count[0] != after_equip:
		fails.append("armor_changed_spam")

	# 8. Armor does not repair itself. The E path handed out the table's pristine
	#    durability on every wear, so taking a chipped piece off and putting it back
	#    on restored it to new — E twice for a full set of armor.
	inv.equip_armor_from_inventory()             # make sure nothing is worn
	player.add_item("leather_armor")             # a fresh pickup: whole again
	var slot8 := _slot_of(inv, "leather_armor")
	if slot8 < 0:
		fails.append("no_slot_for_armor_case_8")
	else:
		inv.equipped_slot = slot8
		inv.equip_armor_from_inventory()
	var whole: float = player.armor_status()["durability"]
	if absf(whole - 80.0) > 0.01:
		fails.append("fresh_armor_not_whole=%.1f" % whole)
	player.life = 40.0
	player._invuln = 0.0
	player.damage(10.0)                          # eats 3, so chips 1.5
	var chipped: float = player.armor_status()["durability"]
	if chipped >= whole:
		fails.append("armor_did_not_chip_in_case_8")
	inv.equip_armor_from_inventory()             # off
	inv.equip_armor_from_inventory()             # on again
	if absf(player.armor_status()["durability"] - chipped) > 0.01:
		fails.append("armor_repaired_itself_on_rewear")
	# The other way a re-wear could hand out a new piece: after a savegame load,
	# which goes through load_armor_state().
	player.combat.load_armor_state("leather_armor", 40.0)
	inv.equip_armor_from_inventory()             # off
	inv.equip_armor_from_inventory()             # on again
	if absf(player.armor_status()["durability"] - 40.0) > 0.01:
		fails.append("loaded_armor_repaired_itself_on_rewear")

	guard.restore()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
