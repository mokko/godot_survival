extends SceneTree
## Headless check: ESC (pause_requested) opens the pause menu, pauses the
## game, shows the mouse; Continue closes it, unpauses, re-captures mouse.

func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 90:
		await physics_frame   # let fade-in finish so input unlocks
	var player: CharacterBody3D = main.get_node("Player")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var tree := self

	# 1. ESC -> menu opens, game paused, mouse visible.
	player.pause_requested.emit()
	for i in 5:
		await process_frame
	var opened: bool = menu.visible and tree.paused \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var world_frozen: bool = not main.get_node("Player").can_process() \
			or tree.paused

	# 2. Continue -> menu closes, unpaused, mouse captured again.
	menu._on_resume()
	for i in 5:
		await process_frame
	var mouse_ok: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or DisplayServer.get_name() == "headless"
	var resumed: bool = not menu.visible and not tree.paused and mouse_ok

	print("RESULT opened=%s frozen=%s resumed=%s" % [opened, world_frozen, resumed])
	quit(0 if (opened and world_frozen and resumed) else 1)
