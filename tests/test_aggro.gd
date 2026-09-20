extends SceneTree
## Headless check: every animal fights back. Hitting any of the six species turns
## it aggro — it joins the "aggro_fauna" group and closes on the player — and the
## fight ends by itself (killed, given up, or the player died). The HUD's Enemy
## line names the animal that is on you and shows its life points while the fight
## lasts, and is gone once it is over.

const Island := preload("res://world/island.gd")

const GIVE_UP := 5.0   # fauna/fauna_base.gd GIVE_UP_TIME
const LEASH := 30.0    # fauna/fauna_base.gd AGGRO_LEASH


class FakePlayer extends Node3D:
	## Stands in for the drone: the animals only need something in the "player"
	## group that can be damaged.
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


func _fight_case(scene_path: String, expected: String, animal_pos: Vector3,
		fake_pos: Vector3, prep: Callable = Callable()) -> PackedStringArray:
	## Hit one animal and watch it come back at us.
	var fails: PackedStringArray = []
	var animal: Node3D = (load(scene_path) as PackedScene).instantiate()
	animal.position = animal_pos
	if prep.is_valid():
		prep.call(animal)
	root.add_child(animal)
	await _wait(0.1)
	var fake := FakePlayer.new()
	fake.position = fake_pos
	root.add_child(fake)
	await _wait(0.1)

	if animal.species_name() != expected:
		fails.append("wrong_name_" + str(animal.species_name()))
	animal.damage(10.0)   # the player's blow is what starts this
	if not animal.is_aggro():
		fails.append("%s_did_not_aggro" % expected)
	if not animal.is_in_group("aggro_fauna"):
		fails.append("%s_not_in_aggro_group" % expected)

	var hits := 0
	for i in 360:          # up to 6 s of physics frames to close and strike
		await physics_frame
		if fake.hits > 0:
			hits = fake.hits
			break
	if hits < 1:
		fails.append("%s_never_fought_back" % expected)
	elif not is_equal_approx(fake.damage_taken, animal.aggro_damage() * float(hits)):
		fails.append("%s_wrong_damage" % expected)

	animal.queue_free()
	fake.queue_free()
	await _wait(0.1)
	return fails


func _init() -> void:
	var fails: PackedStringArray = []
	var land: Vector3 = Island.spawn_point()

	# 1. All six species: a hit turns them on the player and they land a blow.
	var cases := [
		["res://fauna/grazer.tscn", "Velvetback Grazer"],
		["res://fauna/scuttler.tscn", "Pebble Scuttler"],
		["res://fauna/drifter.tscn", "Lantern Drifter"],
		["res://fauna/gull.tscn", "Windvane Gull"],
		["res://fauna/rippleback.tscn", "Rippleback"],
		["res://fauna/stalker.tscn", "Dusk Stalker"],
	]
	for entry in cases:
		var scene_path: String = entry[0]
		var expected: String = entry[1]
		var animal_pos: Vector3 = land + Vector3(0.0, 0.5, 0.0)
		var fake_pos: Vector3 = land + Vector3(4.0, 0.5, 0.0)
		var prep: Callable = Callable()
		match expected:
			"Lantern Drifter":
				animal_pos = land + Vector3(0.0, 3.0, 0.0)
			"Windvane Gull":
				# Keep the orbit in reach: an unconfigured gull circles world
				# origin, which is a 140 m approach from here.
				prep = func(gull: Node3D) -> void:
					gull.set("anchor", Vector2(land.x, land.z))
					gull.set("orbit_radius", 5.0)
			"Rippleback":
				# Only fights inside the caldera lake — it cannot leave the water.
				var lake: Vector2 = Island.CALDERA_CENTER
				animal_pos = Vector3(lake.x, Island.LAKE_LEVEL - 1.0, lake.y)
				fake_pos = Vector3(lake.x, Island.LAKE_LEVEL - 0.5, lake.y)
			"Dusk Stalker":
				# Give it room: its territory is adopted where it stands.
				fake_pos = land + Vector3(5.0, 0.5, 0.0)
		fails.append_array(await _fight_case(scene_path, expected, animal_pos,
				fake_pos, prep))

	# 2. The fight ends when the player gets away: out of the leash for longer
	#    than GIVE_UP_TIME and the animal calms down and leaves the group.
	var stray: Node3D = (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	stray.position = land
	root.add_child(stray)
	var away := FakePlayer.new()
	away.position = land + Vector3(3.0, 0.5, 0.0)
	root.add_child(away)
	await _wait(0.2)
	stray.damage(10.0)
	if not stray.is_aggro():
		fails.append("leash_case_did_not_aggro")
	away.position = land + Vector3(LEASH + 60.0, 0.5, 0.0)
	await _wait(GIVE_UP + 1.5)
	if stray.is_aggro() or stray.is_in_group("aggro_fauna"):
		fails.append("never_gave_up_the_chase")
	stray.queue_free()
	away.queue_free()

	# 3. The HUD line, on the real scene: hidden with nobody angry, naming the
	#    nearest fighter plus its life points while it lasts, gone when it dies.
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var label: Label = main.get_node_or_null("HUD/EnemyLabel")
	if label == null:
		fails.append("no_enemy_label_in_hud")
	else:
		if label.visible:
			fails.append("enemy_line_visible_without_a_fight")
		var spot: Vector3 = player.global_position + Vector3(2.5, 0.0, 0.0)
		var beast: Node3D = (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
		main.add_child(beast)
		beast.global_position = Vector3(spot.x,
				Island.height_at(spot.x, spot.z) + 0.55, spot.z)
		await _wait(0.2)
		beast.damage(10.0)
		await _wait(0.2)
		if not label.visible:
			fails.append("enemy_line_missing_in_a_fight")
		elif not label.text.begins_with("Enemy: "):
			fails.append("enemy_line_wrong_text:" + label.text)
		elif not label.text.contains("Velvetback Grazer"):
			fails.append("enemy_line_unnamed:" + label.text)
		elif not label.text.contains("40/50"):
			fails.append("enemy_line_no_life_points:" + label.text)

		# Killing it ends the fight, and the line goes with it.
		beast.damage(100.0)
		await _wait(0.3)
		if label.visible:
			fails.append("enemy_line_outlived_the_fight")

		# Dying ends every fight too: nobody hunts a corpse.
		var second: Node3D = (load("res://fauna/scuttler.tscn") as PackedScene).instantiate()
		main.add_child(second)
		second.global_position = Vector3(spot.x,
				Island.height_at(spot.x, spot.z) + 0.25, spot.z)
		await _wait(0.2)
		second.damage(10.0)
		await _wait(0.2)
		if not second.is_aggro():
			fails.append("second_animal_did_not_aggro")
		player.life = 1.0
		player.damage(50.0)
		await _wait(0.3)
		if second.is_aggro() or not second.get_tree().get_nodes_in_group("aggro_fauna").is_empty():
			fails.append("death_did_not_end_the_fights")
		if label.visible:
			fails.append("enemy_line_outlived_the_player")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
