extends SceneTree
## Headless check: story types letter by letter; first ESC/click goes
## straight into the game (no skip-then-confirm two-stage).

func _init() -> void:
	var story = load("res://story.tscn").instantiate()
	root.add_child(story)
	var label: Label = story.get_node("Center/VBox/Text")
	for i in 20:
		await process_frame
	var partial_len: int = label.text.length()
	var full_len: int = story.FULL_TEXT.length()
	story._start_game()
	for i in 15:
		await process_frame
	var in_game: bool = current_scene != null and current_scene.name == "Main"
	var player: CharacterBody3D = current_scene.get_node("Player")
	for i in 90:
		await physics_frame
	print("RESULT typing=%s (%d/%d) in_game=%s floor=%s"
			% [partial_len > 0 and partial_len < full_len, partial_len,
			full_len, in_game, player.is_on_floor()])
	quit(0 if (partial_len > 0 and partial_len < full_len and in_game
			and player.is_on_floor()) else 1)
