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

	# 5. The second door into the book: the notebook in the drone's hand, read with a click
	#    out in the world. Same screen, same gate, same single owner for ESC — but closing it
	#    drops the player back into the game rather than onto the menu. That is the bench's
	#    contract (`world/bench.gd`), and for the same reason: they were playing, not
	#    browsing.
	pedia.back()          # chapters -> closed: the menu door lands back on the menu
	for i in 5:
		await process_frame
	menu._on_continue()
	for i in 5:
		await process_frame
	var world_again: bool = not menu.visible and not tree.paused
	# Look up at the sky first. Nothing under the reticle means a click cannot grab or punch
	# instead, which would leave the book the only thing left for it to do — and so makes
	# the assertion below about the book rather than about what happens to be lying around.
	player.camera.rotation.x = -0.9
	player.add_item("pen")
	var holds_book: bool = _equip(player, "notebook") \
			and player.get_equipped_item() == "notebook"
	_click()
	await settle()
	var read_in_world: bool = holds_book and pedia.visible and tree.paused \
			and not menu.get_node("Center").visible
	_escape()
	await settle()
	var back_in_game: bool = world_again and not pedia.visible and not tree.paused \
			and not menu.visible
	# ...and with anything else in hand the same click is still a punch, not a book.
	var holds_pen: bool = _equip(player, "pen") and player.get_equipped_item() == "pen"
	_click()
	await settle()
	var pen_does_not_read: bool = holds_pen and not pedia.visible

	print("RESULT opened=%s focused=%s frozen=%s continued=%s locked=%s opens=%s"
			% [opened, focused, world_frozen, continued, locked, book_opens]
			+ " world_again=%s holds_book=%s read=%s back=%s holds_pen=%s pen=%s"
			% [world_again, holds_book, read_in_world, back_in_game, holds_pen,
			pen_does_not_read])
	quit(0 if (opened and focused and world_frozen and continued and locked and book_opens
			and world_again and read_in_world and back_in_game
			and pen_does_not_read) else 1)


func settle() -> void:
	for i in 5:
		await process_frame


func _click() -> void:
	## A real left click through the ordinary pipeline: `player/player.gd` is what decides
	## what a click does, so nothing here calls that branch directly.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _escape() -> void:
	## A real ESC. The pause menu is the only listener for it, whatever screen is up.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _equip(player: Node, item_id: String) -> bool:
	## What the number keys do (`ui/inventory.gd::_unhandled_input`), without the key.
	var inv = player.inventory
	if inv == null:
		return false
	var idx: int = inv.slots.find(item_id)
	if idx < 0:
		return false
	inv.equip(idx)
	return true
