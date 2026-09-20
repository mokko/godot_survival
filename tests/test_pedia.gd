extends SceneTree
## Headless check: the Pedia is a book you can walk through. Three layers —
## chapters (Islands, Plants, Animals, Equipment), the subchapters inside one of
## them, and a data page for each thing: a square picture top left, its name in a
## bigger font, and the text describing it. Back walks one layer up and at the
## chapters page hands back to the pause menu.
##
## Also checks the things that would rot silently: every subchapter in every
## chapter has a plate to draw and text worth reading, the Equipment chapter
## covers exactly the items in items/item_db.gd, and the contents page carries
## the drone's own line about the notes.

const PediaData := preload("res://ui/pedia_data.gd")
const PediaArt := preload("res://ui/pedia_art.gd")
const ItemDB := preload("res://items/item_db.gd")

const PLATE_SIZE := Vector2(190, 190)
const CHAPTER_ORDER := ["islands", "plants", "animals", "equipment"]
const MIN_TEXT := 200
const INTRO := "Your research notes."


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

	# 2. Opening it hides the pause menu and lands on the chapters page, whose
	#    first line is the drone's own note and whose menu is the four chapters.
	pause._on_pedia()
	await _wait(0.1)
	if not pedia.visible:
		fails.append("pedia_did_not_open")
	if menu.visible:
		fails.append("pause_menu_still_showing_behind_pedia")
	if pedia.page() != "chapters":
		fails.append("did_not_open_on_chapters")
	var intro: Label = pedia.chapters.get_child(0) as Label
	if intro == null or intro.text != INTRO:
		fails.append("contents_intro_is_" + (intro.text if intro != null else "none"))
	var chapter_labels := _button_labels(pedia.chapters)
	var expected_titles: PackedStringArray = PackedStringArray()
	for id in CHAPTER_ORDER:
		expected_titles.append(PediaData.chapter_title(id))
	if chapter_labels != expected_titles:
		fails.append("chapter_list_is_" + str(chapter_labels))

	# 3. Every chapter lists all of its subchapters, and every data page has a
	#    picture, a name and text worth reading.
	for chapter_id in CHAPTER_ORDER:
		pedia.show_subchapters(chapter_id)
		await _wait(0.05)
		if pedia.page() != "subchapters":
			fails.append("%s_did_not_open" % chapter_id)
		var ids: PackedStringArray = PediaData.subchapter_ids(chapter_id)
		if ids.is_empty():
			fails.append("%s_has_no_subchapters" % chapter_id)
		if _button_labels(pedia.grid).size() != ids.size():
			fails.append("%s_lists_%d_of_%d" % [chapter_id,
					_button_labels(pedia.grid).size(), ids.size()])
		for id in ids:
			var record: Dictionary = PediaData.subchapter(chapter_id, id)
			if str(record.get("name", "")) == "" or str(record.get("subtitle", "")) == "":
				fails.append("%s/%s_missing_name_or_subtitle" % [chapter_id, id])
			if str(record.get("text", "")).length() < MIN_TEXT:
				fails.append("%s/%s_text_too_short" % [chapter_id, id])
			if PediaArt.plate_ops(chapter_id, id, PLATE_SIZE).is_empty():
				fails.append("%s/%s_has_no_plate" % [chapter_id, id])
		# ...and one of them opens as a data page.
		pedia.show_data_page(chapter_id, ids[0])
		await _wait(0.05)
		var first: Dictionary = PediaData.subchapter(chapter_id, ids[0])
		if pedia.page() != "data":
			fails.append("%s_data_page_did_not_open" % chapter_id)
		if pedia.data_name.text != str(first["name"]):
			fails.append("%s_data_name_wrong" % chapter_id)
		if pedia.data_text.text != str(first["text"]):
			fails.append("%s_data_text_wrong" % chapter_id)
		if pedia.plate.chapter != chapter_id or pedia.plate.entry_id != ids[0]:
			fails.append("%s_plate_not_set" % chapter_id)

	# 4. The data page's shape: square picture at the top left, name bigger than
	#    the body text it introduces.
	pedia.show_data_page("animals", "grazer")
	await _wait(0.1)
	var square := absf(pedia.plate.size.x - pedia.plate.size.y) <= 1.0
	if not square:
		fails.append("plate_not_square:%s" % str(pedia.plate.size))
	if pedia.plate.global_position.x >= pedia.data_name.global_position.x:
		fails.append("plate_not_left_of_the_name")
	if pedia.plate.global_position.y > pedia.data_text.global_position.y:
		fails.append("plate_not_above_the_text")
	var name_size: int = pedia.data_name.get_theme_font_size("font_size")
	var body_size: int = pedia.data_text.get_theme_font_size("font_size")
	if name_size <= body_size:
		fails.append("name_not_bigger:%d<=%d" % [name_size, body_size])

	# 5. back() walks up: data page → its subchapter menu → chapters → closed.
	pedia.show_data_page("animals", "grazer")
	await _wait(0.05)
	pedia.back()
	await _wait(0.05)
	if pedia.page() != "subchapters" or pedia.chapter != "animals":
		fails.append("back_from_data_wrong_page")
	pedia.back()
	await _wait(0.05)
	if pedia.page() != "chapters":
		fails.append("back_from_subchapters_wrong_page")
	pedia.back()
	await _wait(0.05)
	if pedia.visible:
		fails.append("back_from_chapters_did_not_close")
	if not menu.visible:
		fails.append("pause_menu_not_restored_after_close")

	# 6. Reopening starts at the chapters again, whatever page was left open.
	pedia.show_data_page("plants", "sunbulb")
	await _wait(0.05)
	pause._on_pedia()
	await _wait(0.05)
	if pedia.page() != "chapters":
		fails.append("reopened_on_" + pedia.page())

	# 7. ESC belongs to the pause menu: while the book is open it turns a page
	#    instead of resuming the game, and only resumes from the menu itself.
	pedia.show_data_page("islands", "ezo")
	await _wait(0.05)
	pause._unhandled_input(_escape())
	await _wait(0.05)
	if not pedia.visible or pedia.page() != "subchapters":
		fails.append("esc_did_not_turn_the_page")
	if not paused:
		fails.append("esc_resumed_the_game_from_the_pedia")
	pedia.back()
	pedia.back()   # subchapters → chapters → closed
	await _wait(0.05)
	if pedia.visible:
		fails.append("book_stayed_open")
	pause._unhandled_input(_escape())
	await _wait(0.05)
	if paused:
		fails.append("esc_did_not_resume_from_the_menu")

	# 8. The word lists cannot drift: Equipment covers exactly the item table.
	var item_ids: PackedStringArray = PackedStringArray()
	for id in ItemDB.ITEMS.keys():
		item_ids.append(str(id))
	var documented: PackedStringArray = PediaData.subchapter_ids("equipment")
	item_ids.sort()
	documented.sort()
	if item_ids != documented:
		fails.append("equipment_chapter_does_not_match_item_db")
	if not ItemDB.ITEMS.has("notebook") or ItemDB.item_name("notebook") != "Pedia":
		fails.append("no_notebook_item")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)