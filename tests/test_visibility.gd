extends SceneTree
## Headless check: are plants inside the camera's view frustum near spawn?
## Walks the plant list, projects each onto the viewport, counts on-screen.

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await physics_frame
	var cam: Camera3D = main.get_node("Player/Camera3D")
	var plants = main.get_node("Plants")
	var vp := Vector2(1152, 648)
	var on_screen := 0
	var nearest: float = 100000.0
	var nearest_name := ""
	var counts := {}
	for p in plants.get_children():
		var pos: Vector3 = p.global_position
		var d: float = cam.global_position.distance_to(pos)
		if d < nearest:
			nearest = d
			nearest_name = p.name
		# in front of camera and inside frustum?
		var behind: bool = cam.is_position_behind(pos)
		if not behind:
			var sp: Vector2 = cam.unproject_position(pos)
			if sp.x >= -50 and sp.x <= vp.x + 50 and sp.y >= -50 and sp.y <= vp.y + 50:
				on_screen += 1
		# species name = parented species key is lost; count by scene file via group or script
	print("RESULT on_screen=%d nearest=%0.1fm (%s) cam=%s" % [on_screen, nearest, nearest_name, cam.global_position])
	quit(0 if on_screen > 0 else 1)
