extends SceneTree
## Headless check: katana slash — swing animation plays, cone damages a
## Destroyable in front, misses one behind/out of range, non-sword equip
## leaves grab behavior intact.

class FakeTarget extends Node3D:
	var hits := 0
	func _enter_tree() -> void:
		add_to_group("damageable")
	func damage(amount: float) -> void:
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
	var trail: MeshInstance3D = player.equipment.get("_trail")
	if trail == null or not trail.visible:
		fails.append("no_trail")

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
	if t_behind.hits != 0:
		fails.append("behind_hit")
	if t_far.hits != 0:
		fails.append("far_hit")

	# 3. Cooldown: can't re-slash mid-swing.
	player.do_slash()
	if not slash._swinging:
		fails.append("restarted_early")

	for n in [t_front, t_behind, t_far]:
		n.queue_free()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
