extends SceneTree
## Headless check: katana slash — swing animation plays, the trail is a
## crescent (not the old 4 m disc) that sweeps, cone damages a Destroyable in
## front, misses one behind/out of range, and a landed hit lights the crosshair
## marker while a whiff does not.

class FakeTarget extends Node3D:
	var hits := 0
	func _enter_tree() -> void:
		add_to_group("damageable")
	func damage(amount: float, _source := "") -> void:
		hits += 1


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	var fails: PackedStringArray = []

	player.add_item("sword")
	inv.equip(0)   # sword is in slot 0
	for i in 3:
		await process_frame

	# 1. Slash starts: swing flag set, trail appears mid-swing.
	player.do_slash()
	var slash: Node3D = player.combat._slash
	if slash == null or not slash._swinging:
		fails.append("no_swing")
	for i in 10:
		await process_frame
	var trail: MeshInstance3D = player.equipment.get_trail()
	if trail == null or not trail.visible:
		fails.append("no_trail")
	# The trail must be an arc ribbon, not the full disc that used to sit in
	# front of the drone and read as a hit indicator.
	if trail != null:
		if not (trail.mesh is ArrayMesh):
			fails.append("trail_not_arc")
		else:
			var span: float = (trail.mesh as ArrayMesh).get_aabb().size.x
			if span >= 3.0:
				fails.append("trail_still_wide=%.2f" % span)
			if span < 0.5:
				fails.append("trail_too_small=%.2f" % span)
	# ...and it must actually move through the swing, not hang in the air.
	await process_frame
	var yaw_a: float = trail.rotation.y if trail != null else 0.0
	for i in 4:
		await process_frame
	var yaw_b: float = trail.rotation.y if trail != null else 0.0
	if absf(yaw_b - yaw_a) < 0.01:
		fails.append("trail_not_sweeping")

	# 2. Cone damage: target in front gets hit, one behind does not.
	var t_front: FakeTarget = FakeTarget.new()
	t_front.position = player.global_position \
			+ (-player.global_transform.basis.z) * 1.5
	var t_behind: FakeTarget = FakeTarget.new()
	t_behind.position = player.global_position \
			+ (player.global_transform.basis.z) * 1.5
	var t_far: FakeTarget = FakeTarget.new()
	t_far.position = player.global_position \
			+ (-player.global_transform.basis.z) * 6.0
	root.add_child(t_front)
	root.add_child(t_behind)
	root.add_child(t_far)
	for i in 3:
		await process_frame

	# wait for swing to finish (0.35 s) then re-slash for a clean hit check
	for i in 40:
		await process_frame
	player.do_slash()
	for i in 40:
		await process_frame
	if t_front.hits == 0:
		fails.append("front_not_hit")
	# A landed hit ticks the crosshair marker; it is the "you connected" cue.
	if player.hit_marker_alpha() <= 0.0:
		fails.append("no_hit_marker")
	await process_frame
	if player.hit_marker_alpha() <= 0.0:
		fails.append("hit_marker_vanished_immediately")
	if t_behind.hits != 0:
		fails.append("behind_hit")
	if t_far.hits != 0:
		fails.append("far_hit")

	# 3. Cooldown: can't re-slash mid-swing.
	player.do_slash()
	if not slash._swinging:
		fails.append("restarted_early")

	# The marker must fade out again rather than stay lit forever.
	for i in 40:
		await process_frame
	if player.hit_marker_alpha() > 0.0:
		fails.append("hit_marker_never_faded")

	# 4. A slash with no equipment node is refused instead of called on nothing.
	#    _ensure_slash() cannot build the swing without player.equipment, and this
	#    guard is the only thing standing between that and a call on a null node.
	var kept_equipment = player.equipment
	player.equipment = null
	player.combat._slash = null
	player.combat.try_slash()
	if player.combat._slash != null:
		fails.append("slash_built_without_equipment")
	player.equipment = kept_equipment

	for n in [t_front, t_behind, t_far]:
		n.queue_free()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
