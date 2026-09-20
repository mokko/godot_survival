extends SceneTree
## Headless check: the notebook fills itself. A fresh run starts with the species
## chapters empty; the drone carries the binoculars from the first minute; a
## species is drawn by holding it in the binoculars for STUDY_TIME seconds; losing
## it draws nothing; and what is drawn survives a save and a load.
##
## Also covers the two discovery rules that need no studying: what the drone
## carries (Equipment) and the island it is standing on (Islands).

const Notes := preload("res://ui/pedia_notes.gd")
const PediaData := preload("res://ui/pedia_data.gd")
const StudyScript := preload("res://player/study.gd")
const SaveGame := preload("res://world/savegame.gd")

const STUDY_TIME: float = StudyScript.STUDY_TIME


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _wait_until(condition: Callable, timeout: float) -> bool:
	## Progress is counted in physics ticks, not wall time, so every "wait for it"
	## here is a predicate with a generous wall-clock escape.
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _equip(player: Node, item_id: String) -> bool:
	## Equip by slot, the way the number keys do.
	var inv = player.inventory
	if inv == null:
		return false
	for i in inv.SLOTS:
		if inv.slots[i] == item_id:
			inv.equip(i)
			return true
	return false


func _init() -> void:
	var fails: PackedStringArray = []

	# A fresh run, from the splash's point of view.
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	await _wait(0.4)
	var study = player.get_node("Study")
	var inv = main.get_node("HUD/Inventory")

	# 1. The start: binoculars carried, species chapters empty, equipment and the
	#    island the drone woke on already noted.
	if not inv.has_item("binoculars"):
		fails.append("no_binoculars_at_start")
	if study.equipped():
		fails.append("binoculars_equipped_unasked")
	if Notes.has("animals", "grazer") or Notes.has("plants", "windsinger"):
		fails.append("species_noted_before_study")
	if not Notes.has("equipment", "notebook"):
		fails.append("carried_notebook_not_noted")
	if not Notes.has("islands", "ezo"):
		fails.append("island_not_noted")

	# 2. Equipping them shows the binocular view; a click with nothing in view
	#    starts nothing.
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable")
	await _wait(0.1)
	if not study.equipped():
		fails.append("equipped_not_reported")
	if not study._view.visible:
		fails.append("binocular_view_not_shown")
	if study.begin():
		fails.append("studied_something_with_nothing_in_view")
	if study.is_studying():
		fails.append("session_started_with_no_subject")

	# 3. Hold a plant in view: it is drawn once the hold passes STUDY_TIME, and the
	#    meter tracks the hold while it lasts.
	var plant := (load("res://flora/frostneedle.tscn") as PackedScene).instantiate()
	main.add_child(plant)
	var forward: Vector3 = -player.global_transform.basis.z
	var ahead: Vector3 = player.global_position + Vector3(forward.x, 0.0, forward.z) * 6.0
	plant.global_position = Vector3(ahead.x, player.global_position.y, ahead.z)
	await _wait(0.2)
	player.camera.look_at(plant.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("plant_not_studyable")
	elif study.subject_id() != "frostneedle" or study.subject_chapter() != "plants":
		fails.append("wrong_subject:%s/%s" % [study.subject_chapter(), study.subject_id()])
	if not await _wait_until(func() -> bool: return study.progress() >= STUDY_TIME * 0.5, 8.0):
		fails.append("no_progress:%.1f" % study.progress())
	if not study._meter.visible or study._meter.subject == "":
		fails.append("no_meter")
	if Notes.has("plants", "frostneedle"):
		fails.append("drawn_before_the_hold_was_over:%.1f" % study.progress())
	if not study.is_studying():
		fails.append("session_ended_while_aiming")
	if not await _wait_until(func() -> bool: return Notes.has("plants", "frostneedle"), 12.0):
		fails.append("never_drawn")
	if study.is_studying():
		fails.append("session_did_not_end_when_drawn")
	if study._meter.done_text == "":
		fails.append("no_drawn_message")

	# 4. A subject that leaves is not drawn: the grazer flees a drone that comes
	#    close, which is the honest way to lose one.
	var grazer := (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	main.add_child(grazer)
	grazer.global_position = Vector3(ahead.x, player.global_position.y, ahead.z)
	await _wait(0.2)
	player.camera.look_at(grazer.global_position + Vector3(0.0, 0.6, 0.0))
	await _wait(0.2)
	var started: bool = study.begin()
	if started and study.subject_id() != "grazer":
		fails.append("studied_the_plant_instead")
	if started:
		await _wait_until(func() -> bool: return not study.is_studying(), 6.0)
	if study.is_studying():
		fails.append("kept_studying_a_grazing_grazer")
	if Notes.has("animals", "grazer"):
		fails.append("drew_a_fleeing_animal")
	if not Notes.has("plants", "frostneedle"):
		fails.append("lost_what_was_already_drawn")

	# 5. A variant with no page of its own is not studyable, and neither is
	#    something out of the glass's reach.
	var cover := (load("res://flora/mirrorlily_small.tscn") as PackedScene).instantiate()
	main.add_child(cover)
	await _wait(0.1)
	if not study._study_of(cover).is_empty():
		fails.append("ground_cover_variant_studyable")
	var distant := (load("res://flora/windsinger.tscn") as PackedScene).instantiate()
	main.add_child(distant)
	distant.global_position = player.global_position + Vector3(forward.z, 0.0, -forward.x) * 200.0
	await _wait(0.1)
	player.camera.look_at(distant.global_position + Vector3(0.0, 4.0, 0.0))
	await _wait(0.2)
	if study.begin():
		fails.append("studied_something_out_of_range")

	# 6. What is drawn survives a save and a load; clearing empties the notebook.
	var state: Dictionary = player.save_state()
	if not (state.get("notes", []) as Array).has("plants/frostneedle"):
		fails.append("notes_not_saved")
	Notes.clear()
	if Notes.has("plants", "frostneedle"):
		fails.append("clear_did_not_clear")
	player.load_state(state)
	if not Notes.has("plants", "frostneedle"):
		fails.append("notes_not_restored")
	if not Notes.has("equipment", "notebook"):
		fails.append("equipment_notes_not_restored")

	# 7. The Pedia shows only what is drawn: the plants chapter has exactly the one
	#    entry, the animals chapter says how it fills, and the chapter buttons
	#    carry the counts.
	var book = load("res://ui/pedia.tscn").instantiate()
	root.add_child(book)
	await _wait(0.1)
	book.open()
	book.show_subchapters("plants")
	await _wait(0.05)
	var listed: PackedStringArray = PackedStringArray()
	for child in book.grid.get_children():
		if child is Button:
			listed.append(child.text)
	if listed != PackedStringArray(["Frostneedle"]):
		fails.append("plants_page_lists_" + str(listed))
	book.show_subchapters("animals")
	await _wait(0.05)
	if book.grid.get_child_count() != 0:
		fails.append("animals_page_lists_undrawn_animals")
	if book._empty_label == null or book._empty_label.text.is_empty():
		fails.append("no_hint_on_an_empty_chapter")
	book.show_chapters()
	await _wait(0.05)
	var animals_button: Button = book.chapters.get_child(3)
	if not animals_button.text.begins_with("Animals"):
		fails.append("chapter_button_wrong:" + animals_button.text)
	elif not animals_button.text.contains("(0/%d)" % PediaData.subchapters("animals").size()):
		fails.append("chapter_counts_wrong:" + animals_button.text)

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)