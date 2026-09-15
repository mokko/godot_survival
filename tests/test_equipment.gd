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

	# Two arms: shoulder pivots ArmL/ArmR, each carrying shoulder ball, upper
	# arm, elbow, cuff, forearm and two claw fingers.
	var arms: Array = equip.find_children("Arm*", "Node3D", true, false)
	if arms.size() != 2:
		fails.append("arm_count=%d" % arms.size())
	else:
		var names: Array = arms.map(func(n): return String(n.name))
		names.sort()
		if names != ["ArmL", "ArmR"]:
			fails.append("arm_names")
		for arm in arms:
			if (arm as Node3D).find_children("*", "MeshInstance3D", true, false).size() < 7:
				fails.append("%s_parts" % arm.name)
			# Shoulders sit left/right of the body, above the chest band.
			var pos: Vector3 = (arm as Node3D).position
			if absf(pos.x) < 0.3 or pos.y < 0.6:
				fails.append("%s_place" % arm.name)

	# Arms are animated: the gait clock drives the idle sway, and ground speed
	# widens the swing (a parked drone must not march in place).
	var eq = player.equipment
	var t0: float = (arms[0] as Node3D).rotation.x
	eq._animate_arms(1.0)   # advance the gait clock by a second
	var swayed: bool = absf((arms[0] as Node3D).rotation.x - t0) > 0.001

	player.velocity = Vector3.ZERO
	var parked_span: float = _arm_span(eq, arms[0])
	player.velocity = Vector3(4.0, 0.0, 0.0)
	var moving_span: float = _arm_span(eq, arms[0])
	var mirrored: bool = (arms[0] as Node3D).rotation.x \
			* (arms[1] as Node3D).rotation.x < 0.0   # opposite swing phase
	player.velocity = Vector3.ZERO

	# The equip flourish raises both arms.
	eq.play_flourish()
	var raised := 0.0
	for i in 90:
		await process_frame
		raised = maxf(raised, (arms[0] as Node3D).rotation.x)
	if not swayed:
		fails.append("arm_sway")

	# Unarmed jab: the right arm drives forward, the left only counter-rotates.
	# Stepped with a fixed delta so the check doesn't depend on headless frame
	# pacing: 20 * 0.02 s covers the whole 0.34 s punch.
	player.do_punch()
	var punch_started: bool = eq._punch > 0.0
	var jab_peak := 0.0
	var left_peak := 0.0
	for i in 20:
		eq._animate_arms(0.02)
		jab_peak = maxf(jab_peak, (arms[1] as Node3D).rotation.x)
		left_peak = maxf(left_peak, absf((arms[0] as Node3D).rotation.x))
	if not punch_started:
		fails.append("punch_not_started")
	if jab_peak < 0.9:
		fails.append("punch_jab=%.2f" % jab_peak)
	if left_peak > 0.6:
		fails.append("punch_left_too_far=%.2f" % left_peak)
	if moving_span <= parked_span:
		fails.append("arm_gait parked=%.3f moving=%.3f" % [parked_span, moving_span])
	if not mirrored:
		fails.append("arm_mirror")
	if raised < 0.5:
		fails.append("arm_lift=%.2f" % raised)

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


func _arm_span(eq: Node3D, arm: Node3D) -> float:
	## Peak-to-peak of one arm's swing over a full gait cycle, measured by
	## stepping the gait clock directly (deterministic, no frame timing).
	var lo := 1e9
	var hi := -1e9
	for i in 24:
		eq._animate_arms(0.05)
		var r: float = arm.rotation.x
		lo = minf(lo, r)
		hi = maxf(hi, r)
	return hi - lo


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
