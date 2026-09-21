extends SceneTree
## Headless check: the animals walk *around* solid things instead of through them.
##
## Every species moves by writing global_position (see items/destroyable.gd's
## sync_to_physics note), so the collision world never stopped them: a charging
## stalker walked straight through a boulder and a wandering grazer through a trunk.
## fauna_base.walk_step() probes each step and slides; this is the test that says so.
##
## The fixtures hang off a bare SceneTree — no main scene — so the only solid thing in
## the world is the rock each case puts down. Flying and swimming species are
## deliberately not covered: a gull steers in the air and a rippleback in the lake.
##
## Two things every case here has to get right, both learned the hard way:
##
##  - a body added or moved *this* frame is not in the physics world until a step runs,
##    and the probe is a ray against that world, so the frame waits below are load
##    bearing (without them the rock does not exist and the animal strolls through it);
##  - every position — the animals' and the rocks' — is taken from the terrain *at its
##    own spot*, because the cases sit metres apart and the island is not flat.

const Island := preload("res://world/island.gd")

const BODY_Y := 0.55
## Two metres tall on purpose: fauna_base probes a step ~1.1 m up (STEP_PROBE above a
## body that already sits at BODY_Y), so a 1 m rock passes *under* the probe. Anything
## at least as tall as a boulder or a trunk is caught.
const ROCK_SIZE := Vector3(1.0, 2.0, 1.0)


func _rock(parent: Node, xz: Vector2, size: Vector3 = ROCK_SIZE) -> StaticBody3D:
	## A rock standing on the ground at that spot, wherever the ground is there.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = Vector3(xz.x, Island.height_at(xz.x, xz.y) + size.y * 0.5, xz.y)
	return body


func _frames(n: int) -> void:
	## Let the physics server catch up: see the note at the top of the file.
	for i in n:
		await physics_frame


func _inside_rock(animal: Node3D, rock: Node3D, size: Vector3) -> bool:
	## Is the animal's centre inside the rock's footprint? Walking through it means
	## ending up here at least once.
	return absf(animal.global_position.x - rock.global_position.x) < size.x * 0.5 \
			and absf(animal.global_position.z - rock.global_position.z) < size.z * 0.5


func _spawn(scene_path: String, xz: Vector2) -> Node3D:
	## An animal standing on the ground at that spot, held still: each case drives one
	## step function by hand, so the species' own state machine must not move it
	## underneath the measurement.
	var animal: Node3D = (load(scene_path) as PackedScene).instantiate()
	root.add_child(animal)
	animal.set_physics_process(false)
	animal.global_position = Vector3(xz.x, Island.height_at(xz.x, xz.y) + BODY_Y, xz.y)
	return animal


func _init() -> void:
	var fails: PackedStringArray = []
	var land: Vector3 = Island.spawn_point()
	var here := Vector2(land.x, land.z)

	# 1. A grazer walking straight at a rock never ends up inside it.
	var grazer := _spawn("res://fauna/grazer.tscn", here)
	var rock := _rock(root, here + Vector2(1.2, 0.0))
	await _frames(3)
	for i in 60:                       # 60 x 0.2 m = 12 m of walking, at 2 m/s
		grazer._move(Vector3(1.0, 0.0, 0.0), 2.0, 0.1)
		if _inside_rock(grazer, rock, ROCK_SIZE):
			fails.append("grazer_walked_into_the_rock")
			break

	# 2. The same walk in the open covers real ground, so case 1 is about the rock and
	#    not about a gait that stopped moving.
	var walker := _spawn("res://fauna/scuttler.tscn", here + Vector2(-6.0, 0.0))
	await _frames(3)
	var start_x: float = walker.global_position.x
	for i in 20:
		walker._step(Vector3(1.0, 0.0, 0.0), 2.0, 0.1)
	var covered: float = walker.global_position.x - start_x
	if covered < 1.0:
		fails.append("unobstructed_walk_covered_%.2f_m" % covered)

	# 3. Blocked dead ahead by something long, an animal slides along it: an angry one
	#    that stopped at a wall would never reach the player.
	var wall_size := Vector3(1.0, 2.0, 14.0)
	var slider := _spawn("res://fauna/grazer.tscn", here + Vector2(-20.0, -6.0))
	var wall := _rock(root, here + Vector2(-18.0, -6.0), wall_size)
	await _frames(3)
	var start_z: float = slider.global_position.z
	for i in 30:
		slider._move(Vector3(1.0, 0.0, 0.0), 2.0, 0.1)
		if _inside_rock(slider, wall, wall_size):
			fails.append("slider_walked_into_the_wall")
			break
	if absf(slider.global_position.z - start_z) < 0.3:
		fails.append("blocked_walker_did_not_slide")

	# 4. The stalker steers with the same gait (its own _steer_to), so its charge is
	#    stopped by the same rock rather than passing through it.
	var stalker := _spawn("res://fauna/stalker.tscn", here + Vector2(-30.0, -12.0))
	var rock2 := _rock(root, here + Vector2(-28.8, -12.0))
	await _frames(3)
	for i in 40:                       # 40 x 0.75 m = 30 m of chasing, at 7.5 m/s
		var chase_to := Vector3(here.x - 20.0, 0.0, here.y - 12.0)
		stalker._steer_to(chase_to, 7.5, 0.1)
		if _inside_rock(stalker, rock2, ROCK_SIZE):
			fails.append("stalker_charged_through_the_rock")
			break

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)