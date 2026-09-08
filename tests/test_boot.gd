extends SceneTree
## Headless check: main boots, player lands ON the floor, terrain faces up.

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	for i in 90:
		await physics_frame
	var pos := player.global_position
	print("RESULT pos=%s on_floor=%s" % [pos, player.is_on_floor()])
	# Sanity: player should be near spawn (-112, 82) and ABOVE water (y >= 0).
	var ok_floor := player.is_on_floor()
	var ok_height := pos.y >= 0.0
	print("CHECK on_floor=%s above_water=%s" % [ok_floor, ok_height])
	quit(0 if (ok_floor and ok_height) else 1)
