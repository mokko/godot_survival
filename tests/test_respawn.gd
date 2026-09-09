extends SceneTree
## Headless check: player dies -> game-over screen shows and STAYS, player
## stays dead (no auto-regen). The ESC restart path respawns at spawn point.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	for i in 60:
		await physics_frame
	# Move away and kill.
	player.global_position = Vector3(0, 12, 0)
	for i in 20:
		await physics_frame
	player.damage(999.0)
	# 3 seconds of physics: must stay dead, no auto-revive.
	for i in 180:
		await physics_frame
	var still_dead: bool = player._game_over
	var label = main.get_node("HUD/GameOverContainer")
	var label_visible: bool = label.visible
	# Trigger the ESC path directly (what _unhandled_input calls).
	player._restart()
	for i in 60:
		await physics_frame
	var pos := player.global_position
	var near_spawn: bool = Vector2(pos.x, pos.z).distance_to(Vector2(-112.0, 82.0)) < 3.0
	print("RESULT stayed_dead=%s label_shown=%s after_esc pos=%s floor=%s at_spawn=%s" % [
		still_dead, label_visible, pos, player.is_on_floor(), near_spawn])
	quit(0 if (still_dead and label_visible and near_spawn and player.is_on_floor()) else 1)
