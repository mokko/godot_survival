extends SceneTree
## Headless check: the player can name what they draw.
##
## A name is the first *value* the notebook has ever stored (`ui/pedia_notes.gd::_names`,
## beside the `key -> true` drawings), and it never goes back into `ui/pedia_data.gd`: the
## species' own prose keeps saying what the thing *is* no matter what it has been called.
##
##  - a fresh notebook shows the data table's name and nothing else, so ignoring the whole
##    feature costs nothing;
##  - naming is for **species only** — `Notes.can_name()` is the one gate, and an entry
##    that cannot be named keeps what it had;
##  - `Notes.display_name()` is the one resolver, and every screen asks it: the Pedia's
##    list buttons, a data page's title, and the study meter's line;
##  - the field sanitises (surrounding whitespace, control characters, NAME_MAX) and an
##    **empty** field removes the name rather than storing a blank one;
##  - the field **accepts keystrokes over a paused tree**, which is how the Pedia is
##    normally open, and Enter commits;
##  - **ESC in the field abandons the edit** and the pause menu never sees the key — the
##    book stays on its page. Pressed again, with the field no longer focused, the same key
##    walks the book back out: a ladder, not a dead end;
##  - names are saved as a sibling of the drawings and tolerate a save that predates them;
##  - a fresh run clears them with the drawings (the notebook's own lifetime, not a setting);
##  - **dying does not.** The notebook is a keepsake and the death wipe takes loot, not the
##    drone's own record (`player/player.gd::_restart`), so the entry and the name it was
##    given both come through a death, and the book still lists them afterwards.

const PediaData := preload("res://ui/pedia_data.gd")
const Notes := preload("res://ui/pedia_notes.gd")
const SaveGame := preload("res://world/savegame.gd")

const PLANT := "frostneedle"
const ANIMAL := "grazer"
const NAME := "Nemo"


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _key(code: int, unicode: int) -> void:
	## A real key, through the ordinary pipeline: the field's `_gui_input` is part of
	## what is being tested, so nothing here calls the handlers directly.
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _type(text: String) -> void:
	for i in text.length():
		var code := text.unicode_at(i)
		# The keycode of a letter is its uppercase code (KEY_A = 65); the field inserts
		# from `unicode`, so this only has to be plausible, not exact.
		_key(code - 32 if code > 96 and code < 123 else code, code)
		await process_frame


func _escape() -> void:
	_key(KEY_ESCAPE, 0)
	await process_frame


func _equip(player: Node, item_id: String) -> bool:
	var inv = player.inventory
	if inv == null:
		return false
	for i in inv.SLOTS:
		if inv.slots[i] == item_id:
			inv.equip(i)
			return true
	return false


func _button_labels(container: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in container.get_children():
		if child is Button:
			out.append(child.text)
	return out


func _init() -> void:
	var fails: PackedStringArray = []

	# 1. The registry on its own: fallbacks, the gate, and what sanitising means.
	Notes.clear()
	if Notes.name_of("plants", PLANT) != "":
		fails.append("fresh_registry_has_a_name")
	var default_plant := Notes.display_name("plants", PLANT)
	if default_plant != str(PediaData.subchapter("plants", PLANT).get("name", "")):
		fails.append("no_fallback_to_the_data_table:%s" % default_plant)
	if Notes.display_name("islands", "ezo") == "":
		fails.append("islands_lost_their_name")
	if not Notes.can_name("plants") or not Notes.can_name("animals"):
		fails.append("species_not_nameable")
	if Notes.can_name("islands") or Notes.can_name("equipment"):
		fails.append("non_species_nameable")
	# An entry that cannot be named keeps what it had, whatever a caller passes.
	Notes.give_name("islands", "ezo", "Somewhere")
	if Notes.name_of("islands", "ezo") != "":
		fails.append("island_was_named")
	# Whitespace, control characters and length.
	Notes.give_name("plants", PLANT, "  \n\tMoss\t\n  ")
	if Notes.name_of("plants", PLANT) != "Moss":
		fails.append("not_sanitised:%s" % Notes.name_of("plants", PLANT))
	Notes.give_name("plants", PLANT, "a".repeat(80))
	if Notes.name_of("plants", PLANT).length() != Notes.NAME_MAX:
		fails.append("not_capped:%d" % Notes.name_of("plants", PLANT).length())
	Notes.give_name("plants", PLANT, "x".repeat(Notes.NAME_MAX + 5))
	if Notes.name_of("plants", PLANT).length() != Notes.NAME_MAX:
		fails.append("cap_is_not_NAME_MAX")
	# Renaming replaces, and an empty field removes.
	Notes.give_name("plants", PLANT, NAME)
	if Notes.display_name("plants", PLANT) != NAME:
		fails.append("rename_did_not_take")
	Notes.give_name("plants", PLANT, "   ")
	if Notes.name_of("plants", PLANT) != "" or Notes.display_name("plants", PLANT) != default_plant:
		fails.append("blank_did_not_clear")
	# Names survive a restore of the drawings and die with a clear() of the notebook.
	Notes.give_name("plants", PLANT, NAME)
	Notes.restore([])
	if Notes.name_of("plants", PLANT) != NAME:
		fails.append("restoring_drawings_wiped_names")
	Notes.clear()
	if Notes.name_of("plants", PLANT) != "":
		fails.append("clear_kept_names")
	# Junk in the names slot of a save — a file from before the feature — is not fatal.
	Notes.give_name("plants", PLANT, NAME)
	Notes.restore_names(null)
	if Notes.name_of("plants", PLANT) != "":
		fails.append("null_names_left_something")
	Notes.restore_names("junk")
	if Notes.name_of("plants", PLANT) != "":
		fails.append("junk_names_left_something")
	Notes.restore_names({"plants/%s" % PLANT: "  Fern  ", "islands/ezo": "Nope"})
	if Notes.name_of("plants", PLANT) != "Fern":
		fails.append("saved_name_not_restored")
	if Notes.name_of("islands", "ezo") != "":
		fails.append("saved_island_name_restored")

	# 2. The world: the book, the field, and the run's own save.
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: Node = main.get_node("Player")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var study: Node = player.get_node("Study")
	for i in 90:
		await physics_frame   # let the fade-in finish so input unlocks

	Notes.clear()
	player.add_item("notebook")
	player.pause_requested.emit()
	await _wait(0.1)
	menu._on_pedia()
	await _wait(0.1)
	var pedia: Control = menu.get_node("Pedia")
	if not pedia.visible:
		fails.append("book_did_not_open")
	# The book opens on a species that is already drawn, the way a run reaches it.
	Notes.unlock("plants", PLANT)
	pedia.show_subchapters("plants")
	await _wait(0.05)
	pedia.show_data_page("plants", PLANT)
	await _wait(0.05)
	var field = pedia.name_field()
	if field == null:
		fails.append("species_page_has_no_name_field")
	else:
		if not field.visible:
			fails.append("name_field_hidden")
		if field.text != "":
			fails.append("field_started_full:%s" % field.text)
		if not field.placeholder_text.contains(default_plant):
			fails.append("field_does_not_show_the_default:%s" % field.placeholder_text)

	# 3. Typing: over a paused tree, which is how the Pedia is normally open.
	field.grab_focus()
	if not field.has_focus():
		fails.append("field_would_not_take_focus")
	await _type(NAME)
	if field.text != NAME:
		fails.append("typing_did_not_land:%s" % field.text)

	# 4. ESC abandons the edit, and the pause menu never sees the key.
	var cancelled := [false]
	field.edit_cancelled.connect(func() -> void: cancelled[0] = true)
	await _type("!")
	await _escape()
	if not cancelled[0]:
		fails.append("esc_did_not_cancel")
	if field.text != "":
		fails.append("esc_left_the_edit:%s" % field.text)
	if pedia.page() != "data":
		fails.append("esc_walked_out_of_the_page:%s" % pedia.page())
	if Notes.name_of("plants", PLANT) != "":
		fails.append("a_cancelled_edit_was_saved")

	# 5. The same key, with the field out of the way, is the menu's again: a ladder.
	await _escape()
	if pedia.page() != "subchapters":
		fails.append("esc_did_not_walk_back:%s" % pedia.page())

	# 6. Enter commits, the heading follows, and the resolved name is everywhere.
	pedia.show_data_page("plants", PLANT)
	await _wait(0.05)
	field = pedia.name_field()
	field.grab_focus()
	await _type(NAME)
	await _key(KEY_ENTER, 0)
	if Notes.name_of("plants", PLANT) != NAME:
		fails.append("enter_did_not_save:%s" % Notes.name_of("plants", PLANT))
	if pedia.data_name.text != NAME:
		fails.append("heading_did_not_follow:%s" % pedia.data_name.text)
	pedia.back()
	await _wait(0.05)
	if not _button_labels(pedia.grid).has(NAME):
		fails.append("list_button_does_not_show_the_name:%s" % str(_button_labels(pedia.grid)))
	if _button_labels(pedia.grid).has(default_plant):
		fails.append("list_button_still_shows_the_default")
	# The field comes back with what the notebook holds, not with the default.
	pedia.show_data_page("plants", PLANT)
	await _wait(0.05)
	if pedia.name_field().text != NAME:
		fails.append("field_forgot_the_name:%s" % pedia.name_field().text)

	# 7. An empty field removes the name again. The selection is taken first because where
	#    the caret sits after a programmatic `text = ...` is not this test's business — and
	#    a backspace at position 0 would silently do nothing, which is a test bug that looks
	#    exactly like a broken field.
	pedia.name_field().grab_focus()
	pedia.name_field().select_all()
	await process_frame
	_key(KEY_BACKSPACE, 0)
	await process_frame
	if pedia.name_field().text != "":
		fails.append("backspace_did_not_empty_the_field:%s" % pedia.name_field().text)
	await _key(KEY_ENTER, 0)
	if Notes.name_of("plants", PLANT) != "":
		fails.append("emptied_field_kept_the_name")
	if pedia.data_name.text != default_plant:
		fails.append("emptied_field_left_the_heading:%s" % pedia.data_name.text)

	# 8. A page that cannot be named has no field at all.
	pedia.show_data_page("islands", "ezo")
	await _wait(0.05)
	if pedia.name_field() != null and pedia.name_field().visible:
		fails.append("island_page_offers_a_name")

	# 9. Close the book: the run's own save carries the names, beside the drawings.
	menu._on_continue()
	await _wait(0.1)
	Notes.give_name("plants", PLANT, NAME)
	var state: Dictionary = player.save_state()
	var saved: Dictionary = state.get("names", {})
	if saved.get("plants/%s" % PLANT, "") != NAME:
		fails.append("save_state_has_no_names:%s" % str(saved))
	if not str(state.get("notes", [])).contains("plants/%s" % PLANT):
		fails.append("save_state_lost_the_drawing")
	# A different run: the same save restores the name it was written with.
	Notes.restore_names({})
	if Notes.display_name("plants", PLANT) != default_plant:
		fails.append("empty_run_shows_a_name")
	Notes.restore_names(saved)
	if Notes.name_of("plants", PLANT) != NAME:
		fails.append("save_did_not_carry_the_name")

	# 10. The study meter's line is the resolved name too — that is what the drone "says"
	#     when something is drawn, so it is the one place the world speaks a name.
	var plant: Node3D = (load("res://flora/frostneedle.tscn") as PackedScene).instantiate()
	main.add_child(plant)
	var forward: Vector3 = -player.global_transform.basis.z
	var ahead: Vector3 = player.global_position + Vector3(forward.x, 0.0, forward.z) * 4.0
	plant.global_position = Vector3(ahead.x, player.global_position.y, ahead.z)
	await _wait(0.2)
	# The glass comes out of the satchel in a real run; here it is handed over directly,
	# because this test is about names and not about world/explorer_kit.gd.
	player.add_item("magnifying_glass")
	await _wait(0.1)
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable")
	await _wait(0.2)
	player.camera.look_at(plant.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("plant_not_studyable")
	await _wait(0.2)
	if study.subject_name() != NAME:
		fails.append("study_says_%s" % study.subject_name())
	# The meter says the *kind* while the hold runs — and it must not say the name the player
	# gave it either: the drawing is what earns a name at all, so speaking it here would spend
	# it before it was earned.
	if study._meter.subject != "plant":
		fails.append("meter_says_%s" % study._meter.subject)
	if study._meter.subject == NAME:
		fails.append("meter_spent_the_name:%s" % study._meter.subject)

	# 11. Dying keeps the notebook. The drone dies the way the island kills it (no life
	#     left), respawns the way the game-over screen does, and both halves have to come
	#     through: the entry and the name it was given — and the book has to still list it.
	if Notes.name_of("plants", PLANT) != NAME or not Notes.has("plants", PLANT):
		fails.append("nothing_to_lose_before_death")
	player._fall_death()
	await _wait(0.2)
	if not player._game_over:
		fails.append("the_fall_did_not_kill")
	player._restart()
	await _wait(0.2)
	if Notes.name_of("plants", PLANT) != NAME:
		fails.append("death_wiped_the_name")
	if not Notes.has("plants", PLANT):
		fails.append("death_wiped_the_drawing")
	player.pause_requested.emit()
	await _wait(0.1)
	menu._on_pedia()
	await _wait(0.1)
	pedia.show_subchapters("plants")
	await _wait(0.05)
	if not _button_labels(pedia.grid).has(NAME):
		fails.append("after_death_the_book_lost_it:%s" % str(_button_labels(pedia.grid)))
	menu._on_continue()
	await _wait(0.1)

	if fails.is_empty():
		print("RESULT ALL PASS max=%d name=%s" % [Notes.NAME_MAX, NAME])
	else:
		print("RESULT FAIL %s" % ", ".join(fails))
	quit(0 if fails.is_empty() else 1)
