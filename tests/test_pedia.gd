extends SceneTree
## Headless check: the Pedia is a book you can walk through. From the pause menu
## it opens on a table of contents (Islands, Plants, Animals, Equipment); each
## chapter lists its own things; each thing has a page with a picture and text;
## Back walks one page up and at the contents page hands back to the pause menu.
##
## Also checks the two things that would rot silently: every entry in every
## chapter has a plate to draw and text worth reading, and the Equipment chapter
## covers exactly the items in items/item_db.gd.

const PediaData := preload("res://ui/pedia_data.gd")
const PediaArt := preload("res://ui/pedia_art.gd")
const ItemDB := preload("res://items/item_db.gd")

const PLATE_SIZE := Vector2(300, 220)
const CHAPTER_ORDER := ["islands", "plants", "animals", "equipment"]
const MIN_TEXT := 200


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _button_labels(container: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in container.get_children():
		if child is Button:
			out.append(child.text)
	return out


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _init() -> void:
	var fails: PackedStringArray = []

	var pause = load("res://ui/pause_menu.tscn").instantiate()
	root.add_child(pause)
	current_scene = pause
	# Let the menu's _ready run (and its @onready nodes resolve) before poking it:
	# a node added inside SceneTree._init is not ready until the tree ticks.
	await _wait(0.2)
	pause.open()
	await _wait(0.1)
	var pedia: Control = pause.get_node("Pedia")
	var menu: Control = pause.get_node("Center")

	# 1. Inside the pause menu: a Pedia button, and the book starts shut.
	var pedia_button: Button = pause.get_node_or_null("Center/Padding/Panel/VBox/PediaButton")
	if pedia_button == null or pedia_button.text != "Pedia":
		fails.append("no_pedia_button_in_pause_menu")
	elif pedia.visible:
		fails.append("pedia_visible_before_it_was_opened")

	# 2. Opening it hides the pause menu and lands on the table of contents.
	pause._on_pedia()
	await _wait(0.1)
	if not pedia.visible:
		fails.append("pedia_did_not_open")
	if menu.visible:
		fails.append("pause_menu_still_showing_behind_pedia")
	if pedia.page() != "contents":
		fails.append("did_not_open_on_contents")
	var chapter_labels := _button_labels(pedia.contents)
	var expected_titles: PackedStringArray = PackedStringArray()
	for id in CHAPTER_ORDER:
		expected_titles.append(PediaData.chapter_title(id))
	if chapter_labels != expected_titles:
		fails.append("chapter_list_is_" + str(chapter_labels))

	# 3. Every chapter lists all of its entries, and every entry page has a
	#    picture and text worth reading.
	for chapter_id in CHAPTER_ORDER:
		pedia.show_list(chapter_id)
		await _wait(0.05)
		if pedia.page() != "list":
			fails.append("%s_did_not_open" % chapter_id)
		var ids: PackedStringArray = PediaData.entry_ids(chapter_id)
		if ids.is_empty():
			fails.append("%s_has_no_entries" % chapter_id)
		if _button_labels(pedia.grid).size() != ids.size():
			fails.append("%s_lists_%d_of_%d" % [chapter_id,
					_button_labels(pedia.grid).size(), ids.size()])
		for entry_id in ids:
			var e: Dictionary = PediaData.entry(chapter_id, entry_id)
			if str(e.get("name", "")) == "" or str(e.get("subtitle", "")) == "":
				fails.append("%s/%s_missing_name_or_subtitle" % [chapter_id, entry_id])
			if str(e.get("text", "")).length() < MIN_TEXT:
				fails.append("%s/%s_text_too_short" % [chapter_id, entry_id])
			if PediaArt.plate_ops(chapter_id, entry_id, PLATE_SIZE).is_empty():
				fails.append("%s/%s_has_no_plate" % [chapter_id, entry_id])
		# ...and one of them opens as a page.
		pedia.show_entry(chapter_id, ids[0])
		await _wait(0.05)
		var e0: Dictionary = PediaData.entry(chapter_id, ids[0])
		if pedia.page() != "entry":
			fails.append("%s_entry_did_not_open" % chapter_id)
		if pedia.entry_name.text != str(e0["name"]):
			fails.append("%s_entry_name_wrong" % chapter_id)
		if pedia.entry_text.text != str(e0["text"]):
			fails.append("%s_entry_text_wrong" % chapter_id)
		if pedia.plate.chapter != chapter_id or pedia.plate.entry_id != ids[0]:
			fails.append("%s_plate_not_set" % chapter_id)

	# 4. back() walks up: entry page → its chapter list → contents → closed.
	pedia.show_entry("animals", "grazer")
	await _wait(0.05)
	pedia.back()
	await _wait(0.05)
	if pedia.page() != "list" or pedia.chapter != "animals":
		fails.append("back_from_entry_wrong_page")
	pedia.back()
	await _wait(0.05)
	if pedia.page() != "contents":
		fails.append("back_from_list_wrong_page")
	pedia.back()
	await _wait(0.05)
	if pedia.visible:
		fails.append("back_from_contents_did_not_close")
	if not menu.visible:
		fails.append("pause_menu_not_restored_after_close")

	# 5. Reopening starts at the contents again, whatever page it was left on.
	pedia.show_entry("plants", "sunbulb")
	await _wait(0.05)
	pause._on_pedia()
	await _wait(0.05)
	if pedia.page() != "contents":
		fails.append("reopened_on_" + pedia.page())

	# 6. ESC belongs to the pause menu: while the book is open it turns a page
	#    instead of resuming the game, and only resumes from the menu itself.
	pedia.show_entry("islands", "ezo")
	await _wait(0.05)
	pause._unhandled_input(_escape())
	await _wait(0.05)
	if not pedia.visible or pedia.page() != "list":
		fails.append("esc_did_not_turn_the_page")
	if not paused:
		fails.append("esc_resumed_the_game_from_the_pedia")
	pedia.back()
	pedia.back()   # list → contents → closed
	await _wait(0.05)
	if pedia.visible:
		fails.append("book_stayed_open")
	pause._unhandled_input(_escape())
	await _wait(0.05)
	if paused:
		fails.append("esc_did_not_resume_from_the_menu")

	# 7. The word lists cannot drift: Equipment covers exactly the item table.
	var item_ids: PackedStringArray = PackedStringArray()
	for id in ItemDB.ITEMS.keys():
		item_ids.append(str(id))
	var documented: PackedStringArray = PediaData.entry_ids("equipment")
	item_ids.sort()
	documented.sort()
	if item_ids != documented:
		fails.append("equipment_chapter_does_not_match_item_db")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)