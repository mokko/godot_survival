extends SceneTree
## Headless check: the Dusk Stalker is aimed and legible. It adopts a territory
## where it stands (so baked stalkers hunt instead of marching to world origin),
## patrols two land legs, chases a player inside its territory, telegraphs a
## wind-up before biting, drops the chase outside its territory, flashes and is
## shoved when hit, and honours an explicit configure() from the spawner.

const Island := preload("res://world/island.gd")

const PATROL := 0
const CHASE := 1


class FakePlayer extends Node3D:
	var hits := 0
	var damage_taken := 0.0

	func _enter_tree() -> void:
		add_to_group("player")

	func damage(amount: float, _source := "") -> void:
		hits += 1
		damage_taken += amount


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _init() -> void:
	var fails: PackedStringArray = []

	var home: Vector3 = Island.spawn_point()
	var stalker: Node3D = (load("res://fauna/stalker.tscn") as PackedScene).instantiate()
	stalker.position = home   # must be set before _ready adopts it as territory
	root.add_child(stalker)
	var fake := FakePlayer.new()
	fake.position = home + Vector3(60.0, 0.0, 0.0)
	root.add_child(fake)
	await _wait(0.3)

	# 1. Self-configuration: territory adopted, both legs on dry land.
	if not stalker.is_configured():
		fails.append("not_configured")
	if stalker.territory_center.distance_to(Vector2(home.x, home.z)) > 0.01:
		fails.append("territory_not_at_spawn")
	for leg in [stalker.patrol_a, stalker.patrol_b]:
		if not Island.is_land(leg.x, leg.z):
			fails.append("patrol_leg_in_water")

	# 2. Patrols on its own: moves off the spawn point with nobody nearby.
	var start: Vector3 = stalker.global_position
	await _wait(1.5)
	if stalker.global_position.distance_to(start) < 0.5:
		fails.append("did_not_patrol")
	if stalker._state != PATROL:
		fails.append("patrolled_but_not_in_patrol_state")

	# 3. Chase: player inside territory and inside sight radius. Kept far enough
	#    out (7 m) that the stalker is still closing when we look, rather than
	#    already standing in its face and winding up.
	fake.position = stalker.global_position + Vector3(7.0, 0.0, 0.0)
	await _wait(0.25)
	if stalker._state != CHASE:
		fails.append("did_not_chase")
	var d_before: float = stalker.global_position.distance_to(fake.global_position)
	await _wait(0.5)
	if stalker.global_position.distance_to(fake.global_position) >= d_before:
		fails.append("chased_without_closing")

	# 4. Telegraph: step into biting distance and watch the wind-up happen
	#    before any damage lands.
	fake.position = stalker.global_position + Vector3(1.2, 0.0, 0.0)
	var windup_seen := false
	var hits_at_windup := -1
	var lunge_seen := false
	for i in 90:
		await physics_frame
		if stalker.state_name() == "WINDUP":
			windup_seen = true
			if hits_at_windup < 0:
				hits_at_windup = fake.hits
			if stalker._body_mesh != null and stalker._body_mesh.position.z < -0.15:
				lunge_seen = true
		if fake.hits > 0:
			break
	if not windup_seen:
		fails.append("no_windup_telegraph")
	elif hits_at_windup != 0:
		fails.append("bit_before_telegraph")
	if not lunge_seen:
		fails.append("no_lunge_pose")
	await _wait(1.5)
	if fake.hits < 1:
		fails.append("no_contact_damage")
	elif not is_equal_approx(fake.damage_taken, 5.0 * fake.hits):
		fails.append("wrong_damage_amount")
	var hits_after_first: int = fake.hits
	await _wait(0.3)
	if fake.hits != hits_after_first:
		fails.append("hit_cooldown_too_short")
	await _wait(1.2)
	if fake.hits <= hits_after_first:
		fails.append("no_second_hit")

	# 5. Leash: player outside the territory ends the chase.
	fake.position = stalker.global_position + Vector3(60.0, 0.0, 0.0)
	await _wait(1.0)
	if stalker._state == CHASE:
		fails.append("chased_outside_territory")

	# 6. Hit feedback: flash lit and shoved away from the attacker.
	await _wait(1.0)
	var pos_before: Vector3 = stalker.global_position
	fake.position = pos_before + Vector3(1.0, 0.0, 0.0)
	var life_before: float = stalker.life
	stalker.damage(10.0)
	if is_equal_approx(stalker.life, life_before):
		fails.append("no_life_loss")
	if stalker._flash <= 0.0:
		fails.append("no_hit_flash")
	if stalker.global_position.distance_to(pos_before) < 0.2:
		fails.append("no_knockback")
	if stalker.global_position.distance_to(fake.global_position) \
			< pos_before.distance_to(fake.global_position):
		fails.append("knocked_toward_attacker")
	await _wait(0.4)
	if stalker._flash > 0.0:
		fails.append("flash_never_faded")

	# 7. A reconfigured stalker honours what it is given (spawner path).
	var other: Node3D = (load("res://fauna/stalker.tscn") as PackedScene).instantiate()
	root.add_child(other)
	other.configure(Vector2(0.0, 0.0), Vector3(0.0, 0.5, 0.0),
			Vector3(9.0, 0.5, 0.0))
	if other.territory_center != Vector2.ZERO or other._state != PATROL:
		fails.append("configure_ignored")
	if other._target != Vector3(9.0, 0.5, 0.0):
		fails.append("configure_target_ignored")

	if fails.is_empty():
		print("RESULT ALL PASS hits=%d" % fake.hits)
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)