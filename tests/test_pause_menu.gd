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
	var focused: bool = menu.get_node("Center/Padding/Panel/VBox/Continue").has_focus()
	var world_frozen: bool = not main.get_node("Player").can_process() \
			or tree.paused

	# 2. Continue -> menu closes, unpaused, mouse captured again.
	menu._on_continue()
	for i in 5:
		await process_frame
	var mouse_ok: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or DisplayServer.get_name() == "headless"
	var continued: bool = not menu.visible and not tree.paused and mouse_ok

	# 3. Before the notebook is found, the book is shut to the player: the Pedia button is
	#    greyed out, and the one door into the book refuses even when it is called directly
	#    (a disabled Button emits nothing, so the refusal itself is what this pins).
	var pedia_button: Button = menu.get_node("Center/Padding/Panel/VBox/PediaButton")
	var pedia: Control = menu.get_node("Pedia")
	player.pause_requested.emit()
	for i in 5:
		await process_frame
	var greyed: bool = pedia_button.disabled
	menu._on_pedia()
	for i in 5:
		await process_frame
	var locked: bool = greyed and not pedia.visible \
			and menu.get_node("Center").visible

	# 4. Finding the notebook brings it alive: pause again and the book is there.
	menu._on_continue()
	for i in 5:
		await process_frame
	player.add_item("notebook")
	player.pause_requested.emit()
	for i in 5:
		await process_frame
	var unlocked: bool = not pedia_button.disabled
	menu._on_pedia()
	for i in 5:
		await process_frame
	var book_opens: bool = unlocked and pedia.visible

	print("RESULT opened=%s focused=%s frozen=%s continued=%s locked=%s opens=%s"
			% [opened, focused, world_frozen, continued, locked, book_opens])
	quit(0 if (opened and focused and world_frozen and continued and locked
			and book_opens) else 1)
