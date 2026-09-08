extends SceneTree
## Headless check: splash boots, Start button exists and pressing it swaps
## to the game scene with the player on the floor.

func _init() -> void:
	var splash = load("res://splash.tscn").instantiate()
	root.add_child(splash)
	for i in 5:
		await process_frame
	var start: Button = splash.get_node("Center/VBox/Start")
	var ok_title: bool = splash.get_node("Center/VBox/Title").text == "Survival"
	# Simulate the click through the same handler the signal fires.
	splash._on_start_pressed()
	for i in 10:
		await process_frame
	var main = current_scene
	var player: CharacterBody3D = main.get_node("Player")
	for i in 40:
		await physics_frame
	var on_floor: bool = player.is_on_floor()
	print("RESULT title=%s start=%s game_scene=%s player_floor=%s mouse=%d"
			% [ok_title, start != null, main.name == "Main", on_floor,
			Input.mouse_mode])
	quit(0 if (ok_title and start != null and main.name == "Main"
			and on_floor) else 1)
