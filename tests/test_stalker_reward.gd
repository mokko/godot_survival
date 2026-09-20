extends SceneTree
## Headless check: a fight pays for itself and the world reacts.
## - a surviving animal is shoved away from the player; plants stay rooted
## - killing a stalker drops loot beside the corpse instead of vanishing with it
## - the loot is collectable (it hands its item to a player that walks in)
## - stalkers see further at night (combat fed by world/day_cycle.gd)
## - the death cue sound exists

const Island := preload("res://world/island.gd")


class FakePlayer extends Node3D:
	var got: Array = []

	func _enter_tree() -> void:
		add_to_group("player")

	func add_item(item_id: String) -> bool:
		got.append(item_id)
		return true

	func damage(_amount: float, _source := "") -> void:
		pass   # bitten while standing next to a stalker; not what we measure


class FakeCycle extends Node:
	var time_of_day := 0.25


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _pickups_under(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		var script: Script = child.get_script()
		if script != null and str(script.resource_path).contains("item_pickup"):
			found.append(child)
	return found


func _init() -> void:
	var fails: PackedStringArray = []
	var home: Vector3 = Island.spawn_point()
	var ground := Node3D.new()
	ground.position = home
	root.add_child(ground)
	var fake := FakePlayer.new()
	ground.add_child(fake)
	var cycle := FakeCycle.new()
	cycle.name = "DayCycleStub"
	cycle.add_to_group("day_cycle")
	root.add_child(cycle)
	await _wait(0.2)

	# 1. Knockback: a hit that does not kill shoves the animal away.
	var s: Node3D = (load("res://fauna/stalker.tscn") as PackedScene).instantiate()
	ground.add_child(s)
	await _wait(0.2)
	var before: Vector3 = s.global_position
	fake.global_position = before + Vector3(1.0, 0.0, 0.0)
	s.damage(5.0)
	if s.global_position.distance_to(before) < 0.8:
		fails.append("no_knockback")
	if s.global_position.distance_to(fake.global_position) \
			< before.distance_to(fake.global_position):
		fails.append("knocked_toward_attacker")

	# 2. Plants stay rooted: the same hit does not shove a sunbulb.
	var flower: Node3D = (load("res://flora/sunbulb.tscn") as PackedScene).instantiate()
	ground.add_child(flower)
	await _wait(0.2)
	var fpos: Vector3 = flower.global_position
	flower.damage(5.0)
	if flower.global_position.distance_to(fpos) > 0.01:
		fails.append("plant_slid")

	# 3. Night aggression: the day/night cycle reaches combat.
	if s.sight_radius() > 10.0:
		fails.append("day_sight_too_far")
	cycle.time_of_day = 0.8   # after sunset
	if s.sight_radius() < 12.0:
		fails.append("no_night_sight_boost")
	cycle.time_of_day = 0.25
	if s.sight_radius() > 10.0:
		fails.append("day_sight_stuck_on_night")

	# 4. Death cue must be wired before it dies (afterwards it is freed).
	if s._snd_death == null or s._snd_death.stream == null:
		fails.append("no_death_sound")

	# 5. Loot: kill it and expect pickups beside the corpse, not inside it.
	s.global_position = before
	var death_pos: Vector3 = s.global_position
	s.damage(50.0)
	await _wait(0.3)
	var drops := _pickups_under(ground)
	if drops.is_empty():
		fails.append("no_loot")
	else:
		var ids: Array = []
		var near := false
		for d in drops:
			ids.append(str(d.get("item_id")))
			if d.global_position.distance_to(death_pos) < 2.0:
				near = true
		if "emberstone" not in ids:
			fails.append("no_emberstone")
		if not near:
			fails.append("loot_far_from_corpse")
		if drops.size() > 2:
			fails.append("too_much_loot")
		# The drop must outlive the corpse it came from.
		if not is_instance_valid(drops[0]) or drops[0].is_queued_for_deletion():
			fails.append("loot_died_with_corpse")

	# 6. Loot is collectable by a player walking into it.
	if not drops.is_empty():
		fake.global_position = drops[0].global_position
		if drops[0].has_method("_on_body_entered"):
			drops[0].call("_on_body_entered", fake)
		if fake.got.is_empty():
			fails.append("loot_not_collectable")
		elif str(fake.got[0]) != str(drops[0].get("item_id")):
			fails.append("wrong_item_handed_over")

	if fails.is_empty():
		print("RESULT ALL PASS drops=%d" % drops.size())
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)