extends SceneTree
## Headless check: the movable block — a `RigidBody3D` the drone grabs with a click and
## carries in front of the camera.
##
## **The world places none any more** (Maurice's call, 27 Sep: the four blocks that sat on
## the spawn beach in `world/main.tscn` are gone), so this test brings its own: what it
## covers is the scene, the grab path and the held distance. The first check — that the
## shipped world holds no block at all — is what would speak up if one were put back.

const BlockScene := preload("res://world/movable_block.tscn")


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var cam: Camera3D = player.get_node("Camera3D")
	for i in 90:
		await physics_frame
	# Counted before anything of ours exists, so this is the shipped world's answer.
	var placed: int = get_nodes_in_group("movable_block").size()

	# One block of our own, on the ground in front of the drone where the old ones lay.
	var block: RigidBody3D = BlockScene.instantiate()
	main.add_child(block)
	var spot: Vector3 = Ezo.spawn_point() + Vector3(3.0, 0.0, 3.0)
	block.global_position = Vector3(spot.x, Ezo.height_at(spot.x, spot.z) + 0.8, spot.z)
	for i in 90:
		await physics_frame
	var settled: bool = block.linear_velocity.length() < 0.5 and block.global_position.y > -5.0

	# Aim straight at it and grab through the same code path the click uses.
	var dir: Vector3 = (block.global_position + Vector3(0, 0.4, 0)
			- cam.global_position).normalized()
	cam.global_transform.basis = Basis.looking_at(dir, Vector3.UP)
	for i in 5:
		await physics_frame
	player._toggle_grab()
	var grabbed: bool = player._held_block == block
	var dist := 999.0
	if grabbed:
		for i in 40:
			await physics_frame
		dist = cam.global_position.distance_to(block.global_position)
		player._toggle_grab()
	var released: bool = player._held_block == null
	print("RESULT world_blocks=%d settled=%s grabbed=%s dist=%.1f released=%s"
			% [placed, settled, grabbed, dist, released])
	quit(0 if (placed == 0 and settled and grabbed and released and dist < 4.5) else 1)
