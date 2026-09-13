extends SceneTree
## Headless check: weapon damage table, leather armor absorption + breakage,
## and the player damage route through armor.

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
	player.damage(10.0)
	if absf(player.life - (life0 - 7.0)) > 0.01:
		fails.append("absorption_30")   # 10 * 0.3 eaten -> 7 through

	# 3. Armor degrades and breaks: durability 80, eats 3/hit at 10 dmg -> 1.5.
	var hits := 0
	while player.armor_status()["id"] != "" and hits < 100:
		player.life = 40.0   # keep alive so damage keeps flowing
		player.damage(10.0)
		hits += 1
	if player.armor_status()["id"] != "":
		fails.append("armor_never_breaks")
	# After break, full damage passes.
	player.life = 40.0
	var life1: float = player.life
	player.damage(10.0)
	if absf(player.life - (life1 - 10.0)) > 0.01:
		fails.append("broken_absorbs")

	# 4. UI path: key E on an armor slot wears it (inventory emits, HUD shows).
	inv.slots[2] = "leather_armor"
	inv.counts[2] = 1
	inv.equipped_slot = 2
	inv._refresh()
	inv.equip_armor_from_inventory()
	if player.armor_status()["id"] != "leather_armor":
		fails.append("ui_equip")
	player.life = 40.0
	var lifeA: float = player.life
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

	if not backup.is_empty():
		var f := FileAccess.open(SaveGame.SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(backup))

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
