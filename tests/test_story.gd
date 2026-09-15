extends SceneTree
## Headless check: story types letter by letter; first ESC/click goes
## straight into the game (no skip-then-confirm two-stage).

func _init() -> void:
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	var label: Label = story.get_node("Center/VBox/Text")
	for i in 20:
		await process_frame
	var partial_len: int = label.text.length()
	var full_len: int = story.FULL_TEXT.length()
	story._start_game()
	# The hint is set synchronously (before the loading timer), so it can be
	# checked now: the player must be told the load is happening.
	var hint: Label = story.get_node("Center/VBox/Hint")
	var loading_shown: bool = hint.text == "Loading..." and hint.visible \
			and not label.visible
	var in_game: bool = await _await_game()
	var player: CharacterBody3D = current_scene.get_node("Player")
	for i in 90:
		await physics_frame
	print("RESULT typing=%s (%d/%d) loading_hint=%s in_game=%s floor=%s"
			% [partial_len > 0 and partial_len < full_len, partial_len,
			full_len, loading_shown, in_game, player.is_on_floor()])
	quit(0 if (partial_len > 0 and partial_len < full_len and loading_shown
			and in_game and player.is_on_floor()) else 1)


func _await_game(max_frames := 900) -> bool:
	## The scene swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are much shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false
