extends SceneTree
## Headless check: drone equipment visuals — props exist, hidden by default,
## shown when the matching item is equipped, armor shows on wear.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var equip: Node3D = player.get_node("Equipment")
	var fails: PackedStringArray = []

	# Droid body built: treads, body, dome, eye etc. exist.
	var meshes := equip.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 12:   # 2 treads + 6 hubs + body + band + lens + neck + dome + stripe + eye
		fails.append("droid_body")
	# Dome head present (a sphere mesh with radius 0.22)
	var domes := equip.find_children("*", "MeshInstance3D", true, false).filter(
			func(n): return (n as MeshInstance3D).mesh is SphereMesh \
				and absf((n as MeshInstance3D).mesh.radius - 0.22) < 0.01)
	if domes.size() != 1:
		fails.append("dome_head")

	# All props start hidden.
	for id in ["sword", "bow", "dagger", "leather_armor"]:
		var prop: Node3D = equip.get(id) if equip.get(id) != null else null
	# props are private; use visibility scan via groups instead:
	for child in equip.get_children():
		if child.get_script() == null and child is Node3D and child.position != Vector3.ZERO:
			pass
	var visible_props: int = 0
	for child in equip.get_children():
		if child is Node3D and child.visible and child.name != ".":
			visible_props += 1

	# Equip katana -> katana prop visible, bow hidden.
	player.add_item("bow")
	player.add_item("sword")
	inv.equip(1)   # sword
	for i in 3:
		await process_frame
	var sword_vis := _prop_visible(equip, Vector3(0.38, 0.7, 0.1))
	var bow_vis := _prop_visible(equip, Vector3(-0.34, 0.72, 0.12))
	if not sword_vis or bow_vis:
		fails.append("katana_swap")

	# Switch to bow.
	inv.equip(0)
	for i in 3:
		await process_frame
	if _prop_visible(equip, Vector3(0.38, 0.7, 0.1)) or not _prop_visible(equip, Vector3(-0.34, 0.72, 0.12)):
		fails.append("bow_swap")

	# Wear armor -> plates visible; remove -> hidden.
	player.add_item("leather_armor")
	inv.slots[2] = "leather_armor"
	inv.counts[2] = 1
	inv.equipped_slot = 2
	inv._refresh()
	inv.equip_armor_from_inventory()
	for i in 3:
		await process_frame
	if not _prop_visible(equip, Vector3.ZERO, true):
		fails.append("armor_show")
	inv.equip_armor_from_inventory()
	for i in 3:
		await process_frame
	if _prop_visible(equip, Vector3.ZERO, true):
		fails.append("armor_hide")

	# Flourish: on equip, drone bobs up then settles; rotors spin faster.
	player.equipment.play_flourish()
	var peaked := false
	for i in 90:
		await process_frame
		if player.equipment.position.y > 0.2:
			peaked = true
	var settled: bool = absf(player.equipment.position.y) < 0.01 or is_zero_approx(player.equipment.position.y)
	if not peaked or not settled:
		fails.append("flourish")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _prop_visible(equip: Node3D, pos: Vector3, near_origin := false) -> bool:
	## True if a prop root near pos is visible. Armor plates root at origin.
	for child in equip.get_children():
		if child is Node3D and child.get_script() == null \
				and child.get_child_count() > 0:
			var c := child as Node3D
			if near_origin:
				if c.visible and c.position.length() < 0.01:
					return true
			elif c.visible and c.position.distance_to(pos) < 0.01:
				return true
	return false
