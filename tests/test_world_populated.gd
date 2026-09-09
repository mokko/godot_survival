extends SceneTree
## Headless check: world populates — plants and animals instantiate,
## player still spawns on the floor.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await physics_frame
	var plants = main.get_node_or_null("Plants")
	var animals = main.get_node_or_null("Animals")
	var player: CharacterBody3D = main.get_node("Player")
	var n_plants: int = plants.get_child_count() if plants else 0
	var n_animals: int = animals.get_child_count() if animals else 0
	# Count animals that are alive and on terrain.
	var grounded := 0
	if animals:
		for a in animals.get_children():
			if a is Node3D and a.global_position.y > 0.0:
				grounded += 1
	print("RESULT plants=%d animals=%d grounded=%d player_floor=%s" % [
		n_plants, n_animals, grounded, player.is_on_floor()])
	quit(0 if (n_plants > 400 and n_animals >= 40 and grounded > 30 and player.is_on_floor()) else 1)
