extends SceneTree
## Headless check: a blow does not reach through a solid body, in either direction.
##
## The player's cone (player/combat.gd) measures reach on the ground plane alone,
## and so do an animal's contact blow (fauna/fauna_base.gd) and the stalker's
## wind-up bite (fauna/stalker.gd). All three now ask `world/sight.gd` first, and
## this is the test that says so: a rock between two things stops the blow, taking
## the rock away lets it land, and the flat Area3D ground cover still lets it
## through on purpose. The stalker case also pins that the distance is re-measured
## when the bite lands rather than reusing the one sampled before the wind-up.
##
## Fixtures hang UP metres above the player and the blocker is placed on the ray
## sight.gd will cast, so whatever scenery stands near the spawn cannot influence
## the result.

const Island := preload("res://world/island.gd")
const Sight := preload("res://world/sight.gd")

const UP := Vector3(0.0, 8.0, 0.0)


class FakeTarget extends Node3D:
	## Something a swing can hit: the strike only needs a damageable with damage().
	var hits := 0
	func _enter_tree() -> void:
		add_to_group("damageable")
	func damage(_amount: float, _source := "") -> void:
		hits += 1


class FakePlayer extends Node3D:
	## Stands in for the drone: the animals only need something in the "player"
	## group that can be damaged.
	var hits := 0
	func _enter_tree() -> void:
		add_to_group("player")
	func damage(_amount: float, _source := "") -> void:
		hits += 1


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _solid(parent: Node, pos: Vector3) -> StaticBody3D:
	## A rock in the way: solid, and not damageable, so only line of sight is at
	## stake. Released with queue_free() by the caller.
	##
	## Thin across the ray and tall: a fat box centred near the start of a short
	## ray *contains* that start point, and Godot reports no hit for a shape the ray
	## begins inside — so a fat blocker blocks nothing here and the test would pass
	## for the wrong reason or fail for one.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 1.8, 0.4)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = pos
	return body


func _between(from_node: Node3D, to_node: Node3D) -> Vector3:
	## A point halfway along the ray sight.gd casts, so the blocker is in its path
	## whatever heights the two ends happen to be at.
	return (from_node.global_position + Sight.CHEST).lerp(
			to_node.global_position + Sight.CENTRE, 0.5)


func _init() -> void:
	var fails: PackedStringArray = []
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(30)
	var player = main.get_node("Player")
	var land: Vector3 = Island.spawn_point()
	var forward: Vector3 = -player.global_transform.basis.z

	# 1. The player's swing, with a rock on the line to a target 1.5 m ahead.
	var target := FakeTarget.new()
	root.add_child(target)
	target.global_position = player.global_position + forward * 1.5 + UP
	var rock := _solid(root, _between(player, target))
	await _wait(3)
	player.combat._strike(2.2, 0.7, "sword")
	if target.hits != 0:
		fails.append("target_hit_through_a_rock")

	# 2. Take the rock away: the same swing lands, which is what makes case 1
	#    about the rock rather than about the cone.
	rock.queue_free()
	await _wait(3)
	player.combat._strike(2.2, 0.7, "sword")
	if target.hits < 1:
		fails.append("target_not_hit_in_the_open")

	# 3. Flat ground cover must not block a blow: it is Area3D-based and the player
	#    walks through it, so a swing goes through it too.
	var cover := Area3D.new()
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(2.0, 2.0, 2.0)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	root.add_child(cover)
	cover.global_position = _between(player, target)
	await _wait(3)
	var before: int = target.hits
	player.combat._strike(2.2, 0.7, "sword")
	if target.hits == before:
		fails.append("flat_ground_cover_blocked_a_blow")
	cover.queue_free()

	# 4. The helper itself, both ways, with nothing else in the scene.
	if not Sight.clear(player, target):
		fails.append("open_air_is_not_clear")
	var second_rock := _solid(root, _between(player, target))
	await _wait(3)
	if Sight.clear(player, target):
		fails.append("rock_is_not_blocking")
	second_rock.queue_free()
	await _wait(3)

	# 5. An animal's contact blow, the other direction: the grazer cannot bite
	#    through the rock, and can in the open.
	var beast: Node3D = (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	root.add_child(beast)
	beast.set_physics_process(false)   # hold it still: this is about reach, not gait
	beast.global_position = land + UP
	var fake := FakePlayer.new()
	root.add_child(fake)
	fake.global_position = beast.global_position + Vector3(1.2, 0.0, 0.0)
	beast.provoke()
	var wall := _solid(root, _between(beast, fake))
	await _wait(3)
	beast._attack_cd = 0.0
	beast._try_hit(fake, beast.flat_distance(fake))
	if fake.hits != 0:
		fails.append("animal_bit_through_a_rock")
	wall.queue_free()
	await _wait(3)
	beast._attack_cd = 0.0
	if not beast._try_hit(fake, beast.flat_distance(fake)):
		fails.append("animal_could_not_bite_in_the_open")
	if fake.hits != 1:
		fails.append("animal_bite_hit_count=%d" % fake.hits)

	# 6. The stalker's wind-up bite: refused through the rock, landed in the open,
	#    and measured again when it lands — the distance sampled before the
	#    telegraph must not be what decides.
	var stalker: Node3D = (load("res://fauna/stalker.tscn") as PackedScene).instantiate()
	root.add_child(stalker)
	stalker.set_physics_process(false)
	stalker.global_position = land + UP
	var prey := FakePlayer.new()
	root.add_child(prey)
	prey.global_position = stalker.global_position + Vector3(1.5, 0.0, 0.0)
	stalker.provoke()
	var boulder := _solid(root, _between(stalker, prey))
	await _wait(3)
	stalker._bite(prey)
	if prey.hits != 0:
		fails.append("stalker_bit_through_a_rock")
	boulder.queue_free()
	await _wait(3)
	stalker._bite(prey)
	if prey.hits != 1:
		fails.append("stalker_bite_in_the_open_hit_count=%d" % prey.hits)
	stalker._hit_cd = 0.0
	prey.global_position = stalker.global_position + Vector3(6.0, 0.0, 0.0)
	await _wait(3)
	stalker._bite(prey)
	if prey.hits != 1:
		fails.append("stalker_bite_used_the_stale_distance")

	for n in [target, beast, fake, stalker, prey]:
		n.queue_free()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)