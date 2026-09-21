extends SceneTree
## Headless check: the notebook fills itself, and only the way Maurice asked for.
##
##  - a fresh run starts with an empty notebook and carries the pen, the magnifying
##    glass, the binoculars and the Pedia;
##  - a **plant** is drawn by holding it in the magnifying glass for STUDY_TIME;
##  - an **animal** has two routes: watching it through the **binoculars** for
##    STUDY_TIME (45 m), or killing it with a **blade** and holding the specimen it
##    leaves in the **magnifying glass** for STUDY_TIME (the autopsy) — both reach
##    the same page;
##  - each tool refuses the other's subject and says which one to use: the glass
##    will not watch a living animal, the binoculars will not do close work;
##  - an animal killed with a **bow** (or fists) leaves nothing to open, so it never
##    reaches the notebook;
##  - what is drawn survives a save and a load.
##
## Also covers the two discovery rules that need no studying: what the drone
## carries (Equipment) and the island it is standing on (Islands).

const Notes := preload("res://ui/pedia_notes.gd")
const PediaData := preload("res://ui/pedia_data.gd")
const StudyScript := preload("res://player/study.gd")
const Weapon := preload("res://items/weapon.gd")
const SaveGame := preload("res://world/savegame.gd")

const STUDY_TIME: float = StudyScript.STUDY_TIME
const GLASS_RANGE: float = StudyScript.MAGNIFIER_RANGE


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


func _wait_tracking(player: Node, target: Node3D, condition: Callable, timeout: float) -> bool:
	## Wait for a hold to finish while keeping the crosshair on a moving subject,
	## which is what a player does: the drone has to steer, not the game.
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		if is_instance_valid(target):
			player.camera.look_at(target.global_position)
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


func _specimens(main: Node) -> Array:
	return main.get_tree().get_nodes_in_group("specimen")


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

	# 1. The start: the survey kit is carried, nothing is equipped, the species
	#    chapters are empty, and what needs no studying is already noted.
	for item_id in ["pen", "magnifying_glass", "binoculars", "notebook"]:
		if not inv.has_item(item_id):
			fails.append("no_%s_at_start" % item_id)
	if study.instrument() != "":
		fails.append("instrument_equipped_unasked")
	if Notes.has("animals", "grazer") or Notes.has("plants", "frostneedle"):
		fails.append("species_noted_before_study")
	for item_id in ["notebook", "pen", "magnifying_glass"]:
		if not Notes.has("equipment", item_id):
			fails.append("carried_%s_not_noted" % item_id)
	if not Notes.has("islands", "ezo"):
		fails.append("island_not_noted")

	# 2. Equipping the glass shows the loupe (one lens, not the binoculars' two) and
	#    a click with nothing in view starts nothing.
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable")
	await _wait(0.1)
	if not study.has_magnifier():
		fails.append("glass_not_reported")
	if not study._view.visible:
		fails.append("loupe_view_not_shown")
	if study._view.tubes != 1:
		fails.append("loupe_has_%d_tubes" % study._view.tubes)
	if study.begin():
		fails.append("studied_something_with_nothing_in_view")
	if study.is_studying():
		fails.append("session_started_with_no_subject")

	# 3. Hold a plant in view: it is drawn once the hold passes STUDY_TIME, and the
	#    meter tracks the hold while it lasts.
	var plant := (load("res://flora/frostneedle.tscn") as PackedScene).instantiate()
	main.add_child(plant)
	var forward: Vector3 = -player.global_transform.basis.z
	var ahead: Vector3 = player.global_position + Vector3(forward.x, 0.0, forward.z) * 4.0
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
	if study._meter.message == "":
		fails.append("no_drawn_message")

	# 4. An explorer has more than one way of looking, and the glass will not watch an
	#    animal alive: it refuses and names the binoculars instead.
	# To one side of the plant, so the click cannot land on the already-drawn plant,
	# and aimed at its origin: the angular fallback is exact there, so the animal is
	# found even if the ray slips past its capsule. A Lantern Drifter, because it
	# ignores the drone and barely moves — this check is about the rule, not a chase.
	var aside: Vector3 = player.global_position + Vector3(forward.z, 0.0, -forward.x) * 3.0
	var prey := (load("res://fauna/drifter.tscn") as PackedScene).instantiate()
	main.add_child(prey)
	prey.global_position = Vector3(aside.x, player.global_position.y + 1.0, aside.z)
	await _wait(0.3)
	# Up to a second of tries: a click is cast at the collider's position, which lags
	# the node by a frame, and the drifter is still settling onto its own altitude.
	var refused := false
	for i in 12:
		player.camera.look_at(prey.global_position)
		if study.begin():
			refused = true
			break
		await _wait(0.08)
	if not refused:
		fails.append("living_animal_ignored_silently")
	if study.is_studying():
		fails.append("glass_started_watching_a_living_animal")
	if Notes.has("animals", "drifter"):
		fails.append("drew_a_living_animal_with_the_glass")
	if not study._meter.message.contains("binoculars"):
		fails.append("no_binocular_hint:" + study._meter.message)

	# 5. Route one: watch it through the binoculars. Put out at 12 m — inside their
	#    reach, out of the glass's — and tracked while the hold runs, which is what a
	#    player does with a subject that drifts.
	prey.global_position = player.global_position \
			+ Vector3(forward.z, 0.0, -forward.x) * 12.0 + Vector3(0.0, 1.0, 0.0)
	await _wait(0.3)
	player.camera.look_at(prey.global_position)
	if study.begin():
		fails.append("the_glass_reached_a_subject_at_12_m")
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable")
	await _wait(0.1)
	if study._view.tubes != 2:
		fails.append("binoculars_have_%d_tubes" % study._view.tubes)
	player.camera.look_at(prey.global_position)
	if not study.begin():
		fails.append("binoculars_would_not_watch_an_animal")
	elif study.subject_id() != "drifter" or study.subject_chapter() != "animals":
		fails.append("observing_wrong_subject:%s/%s" % [study.subject_chapter(), study.subject_id()])
	if not await _wait_tracking(player, prey,
			func() -> bool: return Notes.has("animals", "drifter"), 20.0):
		fails.append("observed_never_drawn")
	if study._meter.message == "":
		fails.append("no_message_after_observing")

	# 6. Route two: the autopsy. A blade leaves a specimen; the glass opens it and
	#    reaches the same page the binoculars would have.
	var killed := (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	main.add_child(killed)
	killed.global_position = Vector3(aside.x, player.global_position.y, aside.z)
	await _wait(0.3)
	if not _equip(player, "sword"):
		fails.append("katana_not_equippable")
	killed.damage(999.0, "sword")
	await _wait(0.3)
	var specimens := _specimens(main)
	if specimens.is_empty():
		fails.append("no_specimen_after_a_blade_kill")
	var specimen = specimens[0]
	if str(specimen.study_id()) != "grazer" or str(specimen.study_chapter()) != "animals":
		fails.append("wrong_specimen:%s/%s" % [specimen.study_chapter(), specimen.study_id()])
	specimen.global_position = Vector3(aside.x, player.global_position.y + 0.2, aside.z)
	await _wait(0.1)
	# The binoculars are close-work-refusers: they will not do an autopsy at range.
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable_again")
	await _wait(0.1)
	player.camera.look_at(specimen.global_position)
	study.begin()
	if study.is_studying():
		fails.append("binoculars_agreed_to_do_an_autopsy")
	if not study._meter.message.contains("magnifying"):
		fails.append("no_glass_hint:" + study._meter.message)
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable_again")
	player.camera.look_at(specimen.global_position)
	await _wait(0.2)
	if not study.begin():
		fails.append("specimen_not_studyable")
	elif study.subject_id() != "grazer" or study.subject_chapter() != "animals":
		fails.append("autopsy_wrong_subject:%s/%s" % [study.subject_chapter(), study.subject_id()])
	if not await _wait_until(func() -> bool: return Notes.has("animals", "grazer"), 12.0):
		fails.append("autopsy_never_drawn")

	# 7. The same animal killed at range is lost to the survey: an arrow is a point,
	#    not a blade, so nothing is left behind to open.
	var shot := (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	main.add_child(shot)
	shot.global_position = Vector3(ahead.x, player.global_position.y, ahead.z)
	await _wait(0.3)
	var before := _specimens(main).size()
	# Fists, or an arrow: neither is a blade (items/weapon.gd has_blade), so the
	# animal dies and nothing is left to examine.
	if Weapon.has_blade("bow") or Weapon.has_blade(""):
		fails.append("a_bow_or_a_fist_counts_as_a_blade")
	shot.damage(999.0, "bow")
	await _wait(0.3)
	if _specimens(main).size() != before:
		fails.append("bow_kill_left_a_specimen")

	# 8. Each tool knows its own subject: the binoculars refuse a plant — close work
	#    is the glass's — and neither instrument writes anything down by refusing.
	var drawn_notes := Notes.drawn().size()
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable_again")
	await _wait(0.1)
	player.camera.look_at(plant.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("binoculars_ignored_the_plant_silently")
	if not study._meter.message.contains("magnifying"):
		fails.append("no_glass_hint_for_a_plant:" + study._meter.message)
	if study.is_studying():
		fails.append("binoculars_started_drawing_a_plant")
	if Notes.drawn().size() != drawn_notes:
		fails.append("a_refusal_wrote_something_down")

	# 9. A variant with no page of its own is not studyable, and neither is anything
	#    out of reach of either instrument.
	var cover := (load("res://flora/mirrorlily_small.tscn") as PackedScene).instantiate()
	main.add_child(cover)
	await _wait(0.1)
	if not study._study_of(cover).is_empty():
		fails.append("ground_cover_variant_studyable")
	var distant := (load("res://flora/windsinger.tscn") as PackedScene).instantiate()
	main.add_child(distant)
	distant.global_position = player.global_position + Vector3(forward.z, 0.0, -forward.x) * 200.0
	await _wait(0.1)
	var drawn_before := Notes.drawn().size()
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable_again")
	await _wait(0.1)
	player.camera.look_at(distant.global_position + Vector3(0.0, 4.0, 0.0))
	await _wait(0.2)
	if study.begin():
		fails.append("binoculars_reached_something_at_200_m")
	if Notes.drawn().size() != drawn_before:
		fails.append("a_refusal_unlocked_something")

	# 10. What is drawn survives a save and a load; clearing empties the notebook.
	var state: Dictionary = player.save_state()
	if not (state.get("notes", []) as Array).has("plants/frostneedle"):
		fails.append("notes_not_saved")
	Notes.clear()
	if Notes.has("plants", "frostneedle"):
		fails.append("clear_did_not_clear")
	player.load_state(state)
	for key in ["plants/frostneedle", "animals/drifter", "animals/grazer",
			"equipment/notebook", "equipment/pen", "equipment/magnifying_glass"]:
		if not Notes.drawn().has(key):
			fails.append("notes_not_restored:" + key)

	# 11. The Pedia shows only what is drawn: the plants chapter has exactly the one
	#     drawn plant, the animals chapter the two drawn there (one watched, one
	#     opened), and the chapter buttons carry the counts.
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
	listed = PackedStringArray()
	for child in book.grid.get_children():
		if child is Button:
			listed.append(child.text)
	if listed != PackedStringArray(["Velvetback Grazer", "Lantern Drifter"]):
		fails.append("animals_page_lists_" + str(listed))
	book.show_chapters()
	await _wait(0.05)
	var animals_button: Button = book.chapters.get_child(3)
	if not animals_button.text.begins_with("Animals"):
		fails.append("chapter_button_wrong:" + animals_button.text)
	elif not animals_button.text.contains("(2/%d)" % PediaData.subchapters("animals").size()):
		fails.append("chapter_counts_wrong:" + animals_button.text)

	# 12. The instrument view is redrawn when the tool changes, not every frame: the
	#     mask is drawn in 4 px strips (hundreds of rects) and _update_view() runs
	#     every frame, so the redraw has to be earned.
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable_for_the_redraw_case")
	await _wait(0.2)
	var swaps: int = study._view.redraw_requests
	if swaps <= 0:
		fails.append("view_never_redrawn")
	await _wait(0.6)                       # holding it: ~35 frames of _update_view()
	if study._view.redraw_requests != swaps:
		fails.append("view_redrawn_every_frame:%d->%d" % [swaps,
				study._view.redraw_requests])
	if not _equip(player, "binoculars"):
		fails.append("binoculars_not_equippable_for_the_redraw_case")
	await _wait(0.2)
	if study._view.redraw_requests <= swaps:
		fails.append("changing_the_tool_did_not_redraw")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)