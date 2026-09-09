extends SceneTree
## Headless check: blocks spawn, settle on the terrain, and respond to
## grab/release (simulate the grab by calling player._toggle_grab after
## aiming the camera at a block).

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var blocks = main.get_node("Blocks")
	for i in 90:
		await physics_frame
	var settled := 0
	for b in blocks.get_children():
		if b.linear_velocity.length() < 0.5 and b.global_position.y > -5.0:
			settled += 1
	print("RESULT blocks=%d settled=%d" % [blocks.get_child_count(), settled])
	# Aim camera straight at block1 and grab via the same code path as click.
	var block1 = blocks.get_node("Block1")
	var cam: Camera3D = player.get_node("Camera3D")
	var dir: Vector3 = (block1.global_position + Vector3(0, 0.4, 0)
			- cam.global_position).normalized()
	cam.global_transform.basis = Basis.looking_at(dir, Vector3.UP)
	for i in 5:
		await physics_frame
	player._toggle_grab()
	var grabbed: bool = player._held_block == block1
	for i in 40:
		await physics_frame
	var held_pos: Vector3 = block1.global_position
	var cam_pos: Vector3 = cam.global_position
	var dist: float = cam_pos.distance_to(held_pos)
	player._toggle_grab()
	var released: bool = player._held_block == null
	print("CHECK grabbed=%s dist=%.1f released=%s" % [grabbed, dist, released])
	# 4 blocks: 3 placed by us + 1 manually placed in the editor.
	quit(0 if (blocks.get_child_count() == 4 and settled == 4
			and grabbed and released and dist < 4.5) else 1)
