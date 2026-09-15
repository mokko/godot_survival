extends SceneTree
## Headless check: plants and ground animals are solid — the player can't run
## through them. Asserts (1) collision shapes exist on every placed instance
## that should be solid, (2) a real CharacterBody3D driven into a tree trunk
## is stopped by it, and (3) an animal's collider tracks the animal as it
## moves (an AnimatableBody3D, not a stuck-in-place shape).

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var fails: PackedStringArray = []

	# Scene roots that must be solid: standing flora + ground fauna. Flat
	# ground cover (embermoss, mirrorlily_small) and the walk-over sunbulb
	# pickup stay passable on purpose.
	var solid_scenes := ["frostneedle", "windsinger", "mirrorlily", "ghostsilk",
			"glasspetal", "hoverfern", "lantern_reed", "pulsegrass", "sporebell",
			"thornlash", "grazer", "scuttler", "stalker", "drifter"]
	var passable_scenes := ["embermoss", "mirrorlily_small", "sunbulb",
			"gull", "rippleback"]

	# 1a. Check each scene file directly (some, like pulsegrass, exist as flora
	#     but aren't placed in the current world).
	for scene_name in solid_scenes:
		var ps := load("res://flora/%s.tscn" % scene_name) as PackedScene
		if ps == null:
			ps = load("res://fauna/%s.tscn" % scene_name) as PackedScene
		if ps == null:
			fails.append("missing_scene:%s" % scene_name)
			continue
		var inst := ps.instantiate()
		var shapes: Array = inst.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			fails.append("scene_no_collider:%s" % scene_name)
		else:
			var has_shape := false
			for s in shapes:
				if (s as CollisionShape3D).shape != null:
					has_shape = true
			if not has_shape:
				fails.append("scene_null_shape:%s" % scene_name)
		# The blocking body must be a physics body: either the root itself, or
		# a child body (thornlash keeps an Area3D root for its lash trigger).
		var blocking := inst is StaticBody3D or inst is AnimatableBody3D
		if not blocking:
			for c in inst.get_children():
				if c is StaticBody3D or c is AnimatableBody3D:
					blocking = true
		if not blocking:
			fails.append("scene_not_blocking:%s" % scene_name)
		inst.free()

	# 1b. Passable scenes must not have become blocking bodies.
	for scene_name in passable_scenes:
		var ps := load("res://flora/%s.tscn" % scene_name) as PackedScene
		if ps == null:
			ps = load("res://fauna/%s.tscn" % scene_name) as PackedScene
		if ps == null:
			fails.append("missing_scene:%s" % scene_name)
			continue
		var inst := ps.instantiate()
		if inst is StaticBody3D or inst is AnimatableBody3D:
			fails.append("should_be_passable:%s" % scene_name)
		inst.free()

	# 1c. Placed instances must carry the same colliders in the live world.
	var checked := {}
	for holder in ["Plants", "Animals"]:
		var root_node: Node = main.get_node_or_null(holder)
		if root_node == null:
			fails.append("missing_%s" % holder)
			continue
		for inst in root_node.get_children():
			var scene_name := String(inst.scene_file_path).get_file().get_basename()
			if not solid_scenes.has(scene_name):
				continue
			var shapes: Array = inst.find_children("*", "CollisionShape3D", true, false)
			if shapes.is_empty():
				fails.append("no_collider:%s" % scene_name)
			elif not ((shapes[0] as CollisionShape3D).shape != null):
				fails.append("null_shape:%s" % scene_name)
			checked[scene_name] = true
	# At least the trees and a ground animal must actually be out there, or the
	# "player can't run through" claim is untested in the live world.
	for required in ["frostneedle", "windsinger", "grazer"]:
		if not checked.has(required):
			fails.append("not_placed:%s" % required)

	# 2. Drive a stand-in body into a tree trunk: it must stop, not pass through.
	var trunk: Node3D = null
	for inst in (main.get_node("Plants") as Node).get_children():
		if String(inst.scene_file_path).ends_with("frostneedle.tscn"):
			trunk = inst
			break
	if trunk == null:
		fails.append("no_frostneedle")
	else:
		var blocked := await _drive_into(trunk, 3.0)
		if not blocked["moved"]:
			fails.append("test_body_never_moved")
		if blocked["through"]:
			fails.append("ran_through_trunk")

	# 3. An animal's collider follows the animal (it wanders every few seconds).
	var animal: Node3D = null
	for inst in (main.get_node("Animals") as Node).get_children():
		if String(inst.scene_file_path).ends_with("grazer.tscn"):
			animal = inst
			break
	if animal == null:
		fails.append("no_grazer")
	else:
		var shape: CollisionShape3D = animal.find_children(
				"*", "CollisionShape3D", true, false)[0]
		var before: Vector3 = shape.global_position
		var animal_before: Vector3 = animal.global_position
		for i in 240:
			await physics_frame
			if animal.global_position.distance_to(animal_before) > 0.5:
				break
		var animal_moved: bool = animal.global_position.distance_to(animal_before) > 0.1
		var shape_moved: bool = shape.global_position.distance_to(before) > 0.1
		if animal_moved and not shape_moved:
			fails.append("collider_detached_from_animal")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _drive_into(target: Node3D, distance: float) -> Dictionary:
	## Spawn a capsule-bodied CharacterBody3D `distance` units from `target`,
	## walk it straight at the trunk for a couple of seconds, and report
	## whether it moved at all and whether it ended up past the trunk.
	var body := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	capsule.shape = shape
	body.add_child(capsule)
	root.add_child(body)

	var trunk_radius := 0.25   # frostneedle's CylinderShape3D radius
	var start := target.global_position + Vector3(distance, 1.0, 0.0)
	body.global_position = start
	var dir := Vector3(-1, 0, 0)
	var traveled := 0.0
	var prev := body.global_position
	for i in 180:
		body.velocity = dir * 5.0 + Vector3.DOWN * 2.0
		body.move_and_slide()
		traveled += body.global_position.distance_to(prev)
		prev = body.global_position
		await physics_frame

	var dx := absf(body.global_position.x - target.global_position.x)
	var dz := absf(body.global_position.z - target.global_position.z)
	# Stopped short of the trunk axis (radius + capsule radius, minus slack for
	# sliding around it) and still on the approach side.
	var stopped := dx > (trunk_radius + shape.radius) * 0.6
	var through := body.global_position.x < target.global_position.x - 0.1 \
			and dz < trunk_radius
	body.queue_free()
	return {"moved": traveled > 1.0, "stopped": stopped, "through": through}
