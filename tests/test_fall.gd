extends SceneTree
## Headless check: dropping the player off the map (y < -8) triggers the
## game-over screen and stays dead (ESC restarts at spawn).

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	for i in 60:
		await physics_frame
	# Drop off the map: far out to sea, below the fall-death threshold.
	player.global_position = Vector3(500.0, -10.0, 500.0)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var dead: bool = player._game_over
	var label = main.get_node("HUD/GameOverContainer")
	var shown: bool = label.visible
	# Stay dead for another 2 s (no auto-revive).
	for i in 120:
		await physics_frame
	var still_dead: bool = player._game_over and label.visible
	print("RESULT dead=%s label_shown=%s stays_dead=%s" % [dead, shown, still_dead])
	quit(0 if (dead and shown and still_dead) else 1)
