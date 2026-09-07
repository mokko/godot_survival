extends SceneTree
## Headless check: dropping the player off the map (y < -8) kills them
## instantly and respawns them at the start point, on the floor.

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	for i in 60:
		await physics_frame
	print("start pos=%s" % player.global_position)
	# Drop off the map: far out to sea, below the fall-death threshold.
	player.global_position = Vector3(500.0, -10.0, 500.0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var pos := player.global_position
	print("RESULT pos=%s on_floor=%s over=%s" % [pos, player.is_on_floor(), player._game_over])
	var near_spawn: bool = Vector2(pos.x, pos.z).distance_to(Vector2(-112.0, 82.0)) < 3.0
	print("CHECK at_spawn=%s never_showed_gameover=%s" % [near_spawn, not player._game_over])
	quit(0 if (near_spawn and player.is_on_floor() and not player._game_over) else 1)
