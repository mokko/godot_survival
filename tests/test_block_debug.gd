extends SceneTree
## Debug: where do the blocks actually end up?

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	var blocks = main.get_node("Blocks")
	var player: CharacterBody3D = main.get_node("Player")
	for i in 90:
		await physics_frame
	for b in blocks.get_children():
		print("DBG %s pos=%s vel=%.2f" % [b.name, b.global_position, b.linear_velocity.length()])
	print("DBG player=%s" % player.global_position)
	quit(0)
