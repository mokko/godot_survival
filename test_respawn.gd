extends SceneTree
## Headless check: kill the player, let regen finish, confirm they respawn
## at the spawn point on the floor.

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	# Land first.
	for i in 60:
		await physics_frame
	print("start pos=%s" % player.global_position)
	# Walk away from spawn a bit so we can prove respawn moves us.
	player.global_position = Vector3(0, 12, 0)   # center of island
	for i in 30:
		await physics_frame
	print("wandered pos=%s" % player.global_position)
	# Kill.
	player.damage(999.0)
	# Regen takes 2s at 10/s from 0; run 5 s of physics.
	for i in 300:
		await physics_frame
	var pos := player.global_position
	print("RESULT pos=%s on_floor=%s life=%s over=%s" % [pos, player.is_on_floor(), player.life, player._game_over])
	var near_spawn := Vector2(pos.x, pos.z).distance_to(Vector2(-112.0, 82.0)) < 3.0
	var ok: bool = near_spawn and player.is_on_floor() and not player._game_over
	print("CHECK at_spawn=%s" % near_spawn)
	quit(0 if ok else 1)
