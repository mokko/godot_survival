extends SceneTree
## Headless check: fade overlay locks input for ~0.75s, then unlocks.

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var fade = main.get_node("FadeIn")
	var player: CharacterBody3D = main.get_node("Player")
	for i in 5:
		await physics_frame
	var locked_early: bool = fade.input_locked and player._lock_check()
	for i in 20:
		await physics_frame
	var still_locked: bool = fade.input_locked   # ~0.33s in
	for i in 60:
		await physics_frame
	var unlocked_late: bool = not fade.input_locked and not player._lock_check()
	var rect_hidden: bool = not fade.get_node("Rect").visible
	print("RESULT locked_early=%s still_locked=%s unlocked_late=%s rect_hidden=%s"
			% [locked_early, still_locked, unlocked_late, rect_hidden])
	quit(0 if (locked_early and still_locked and unlocked_late
			and rect_hidden) else 1)
