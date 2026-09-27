extends SceneTree
## Headless check: the notebook fills itself, and only the way Maurice asked for.
##
##  - a fresh run starts empty-handed and finds the survey — the pen, the magnifying
##    glass, the binoculars and the Pedia — in the Explorer's Kit satchel beside the
##    spawn (world/kit.md), with an empty notebook;
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
## Also covers the two discovery rules that need no studying — what the drone
## **carries** (Equipment) — and the two that do not fill themselves: **Islands**,
## which are charted by sailing right round one (`player._chart_step()`), so a run
## opens the book on four empty chapters, and the **survey's beat**, which is earned
## by drawing SURVEY_PLANTS plants and SURVEY_ANIMALS animals on one island.

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


## Where the survey puts its plants: **not straight ahead**, because the sections above
## leave their own plants standing — the frostneedle of section 3 is four metres in front of
## the drone and already drawn — and the aim takes the nearest studyable thing, so a click
## aimed through it would catch that instead. Each offset is (right, forward) in metres.
const PLANT_SIDES := [Vector2(2.6, 3.0), Vector2(-2.6, 3.0), Vector2(-2.0, -3.2)]


func _draw_a_plant(main: Node, player: Node, study: Node, species: String) -> String:
	## Spawn one of a species beside the drone — **on the terrain at its own spot**, not at
	## the drone's height: the ground climbs and falls over a few metres, and a plant buried
	## in a slope is behind the hill rather than under the crosshair. Aimed at its **origin**,
	## so the ray and the angular fallback agree about what is being looked at, and the
	## session is checked to have caught the species asked for before the hold is timed —
	## otherwise the drawing that completes a survey would secretly be a re-drawing of
	## something already in the book. Answers with the species id drawn, or "" if no
	## placement in front of the drone was clear.
	for side in PLANT_SIDES:
		var right: Vector3 = player.global_transform.basis.x
		var forward: Vector3 = -player.global_transform.basis.z
		var at: Vector3 = player.global_position + right * side.x + forward * side.y
		var node: Node3D = (load("res://flora/%s.tscn" % species) as PackedScene).instantiate()
		main.add_child(node)
		node.global_position = Vector3(at.x, Ezo.height_at(at.x, at.z), at.z)
		await _wait(0.2)
		player.camera.look_at(node.global_position)
		await _wait(0.2)
		if not study.begin():
			node.queue_free()
			continue
		if str(study.subject_id()) != species:
			study.cancel()                 # something else was in the way; look elsewhere
			node.queue_free()
			continue
		if not await _wait_until(func() -> bool: return Notes.has("plants", species), 14.0):
			print("  (%s: hold never finished — progress %.1f, studying %s, subject %s)"
					% [species, study.progress(), str(study.is_studying()),
						str(study.subject_id())])
			return ""
		return species
	print("  (%s: nothing in front of the drone was clear enough to aim at)" % species)
	return ""


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


func _nearest_sword(main: Node, player: Node3D) -> Node3D:
	## The katana lies in the world as an ordinary pickup (world/main.tscn, `Items`).
	## The nearest one to the drone is the one on its first stroll.
	var best: Node3D = null
	var best_distance := INF
	for node in main.get_node("Items").get_children():
		if str(node.get("item_id")) != "sword":
			continue
		var d: float = node.global_position.distance_to(player.global_position)
		if d < best_distance:
			best_distance = d
			best = node
	return best


func _close_story(main: Node) -> void:
	## Hand the run back after something in the world played a story page. Opening the satchel
	## and picking up the katana each put a **milestone screen** up over a PAUSED world
	## (ui/story.md), and nothing in the world ticks until that page is closed — so every
	## "wait for the notebook poll" below would wait on a paused tree and fail.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story != null and story.is_playing():
		story._advance()


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

	# 1. The start: empty-handed, so the survey comes from the Explorer's Kit the way it
	#    does for a player — walk up to the satchel and open it (world/kit.md). Nothing is
	#    equipped, the species chapters are empty, and what needs no studying is already
	#    noted.
	var home: Vector3 = player.global_position
	var kit: Node3D = main.get_node("ExplorerKit")
	player.global_position = kit.global_position + Vector3(0.0, 0.0, 1.2)
	if not kit.use_for_test(player):
		fails.append("kit_did_not_open")
	# The satchel's own page goes up over a paused world: close it, or the poll below waits
	# on a tree that is not ticking.
	_close_story(main)
	for i in 5:
		await physics_frame
	player.global_position = home
	# Long enough for the notebook's discovery poll (DISCOVERY_INTERVAL, 0.5 s) to
	# notice what the satchel just handed over.
	await _wait(0.7)
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
	# The Islands chapter is empty at the start as well, and that is the point: the drone
	# has woken up on Ezo, not *sailed round* it, and an island is charted by circling it in
	# a boat (`player._chart_step()`, walked in tests/test_boat.gd section 10). A book that
	# wrote itself a page for the ground under the drone's feet could never open empty.
	if Notes.count_drawn("islands") != 0:
		fails.append("an island was written down without being charted: %s" % str(Notes.drawn()))

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
	# The view draws behind the rest of the HUD on purpose: the Pedia lives in the pause menu,
	# and a view added last would dim the open book and put a lens over it. Draw order is the
	# whole mechanism, so it is what we check — a headless run has no renderer to look at. The
	# one thing *ahead* of it is the world's back buffer, which the lens blur reads
	# (`ui/instrument_view.gd`): copy the screen after the strips and the blur eats its own mask.
	var hud: CanvasLayer = main.get_node("HUD")
	if study._backbuffer == null or study._backbuffer.get_index() > study._view.get_index():
		fails.append("instrument_backbuffer_not_behind_the_lens")
	var pause: Node = hud.get_node_or_null("PauseMenu")
	if pause != null and pause.get_index() < study._view.get_index():
		fails.append("pause_menu_draws_under_the_instrument_view")
	if study._view.get_index() >= hud.get_child_count() - 1:
		fails.append("instrument_view_not_behind_the_hud")
	if study._view._lens == null:
		fails.append("no_lens_on_the_instrument_view")
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

	# 3b. A species already in the notebook is not studied again: the click says so and
	#     starts nothing (Maurice's call). The same plant, still in front of the drone.
	if not _equip(player, "magnifying_glass"):
		fails.append("glass_not_equippable_for_the_repeat")
	await _wait(0.1)
	player.camera.look_at(plant.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("a_repeat_study_was_refused_silently")
	if study.is_studying():
		fails.append("a_session_started_on_a_species_already_drawn")
	if not study._meter.message.contains("Already"):
		fails.append("no_already_studied_message: '%s'" % study._meter.message)
	if study.progress() != 0.0:
		fails.append("a_repeat_study_kept_progress:%.1f" % study.progress())

	# 3c. **A slip banks what it earned.** Interrupting a hold no longer throws the time away:
	#     the seconds come back on the next attempt at *that* species (Maurice's call, 27 Sep),
	#     another species starts at zero, and the bank is spent once the entry is drawn.
	var tree_side: Vector3 = player.global_position \
			+ Vector3(forward.z, 0.0, -forward.x) * 3.2
	var spire: Node3D = (load("res://flora/sporebell.tscn") as PackedScene).instantiate()
	main.add_child(spire)
	spire.global_position = Vector3(tree_side.x, Ezo.height_at(tree_side.x, tree_side.z), tree_side.z)
	await _wait(0.2)
	player.camera.look_at(spire.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("the_sporebell_is_not_studyable")
	if not await _wait_until(func() -> bool: return study.progress() >= 2.0, 8.0):
		fails.append("no_progress_before_the_slip:%.1f" % study.progress())
	var earned: float = study.progress()
	# Out of the glass's reach: the hold ends by itself, the way a player's slip does.
	spire.global_position = player.global_position + Vector3(0.0, 0.0, 40.0)
	if not await _wait_until(func() -> bool: return not study.is_studying(), 8.0):
		fails.append("the_session_outlived_the_slip")
	var banked: float = study.banked_progress("plants", "sporebell")
	if banked < earned - 0.3:
		fails.append("the_slip_did_not_bank:%.1f of %.1f" % [banked, earned])
	if Notes.has("plants", "sporebell"):
		fails.append("an_interrupted_hold_drew_the_entry")
	# Back within reach: the next attempt picks up where that one stopped...
	spire.global_position = Vector3(tree_side.x, Ezo.height_at(tree_side.x, tree_side.z), tree_side.z)
	await _wait(0.2)
	player.camera.look_at(spire.global_position + Vector3(0.0, 1.0, 0.0))
	await _wait(0.2)
	if not study.begin():
		fails.append("the_sporebell_could_not_be_studied_again")
	elif study.progress() < banked - 0.4:
		fails.append("the_resume_restarted:%.1f vs banked %.1f" % [study.progress(), banked])
	# ...the bank is per species, not per drone...
	if study.banked_progress("plants", "frostneedle") != 0.0:
		fails.append("another_species_inherited_the_progress")
	# ...and finishing it spends the bank: the eight seconds are the total, across attempts.
	if not await _wait_until(func() -> bool: return Notes.has("plants", "sporebell"), 14.0):
		fails.append("the_resumed_hold_never_finished")
	if study.banked_progress("plants", "sporebell") != 0.0:
		fails.append("the_bank_survived_the_drawing:%.1f"
				% study.banked_progress("plants", "sporebell"))
	# This case leaves a drawing in the notebook that the sections below were written without
	# (the Pedia chapter listing, the survey count) — take that one entry back out, the same way
	# `test_naming` does. Nothing else changes, and the bank assertions above already ran.
	var drawn_after_slip: Array = Notes.drawn()
	Notes.restore(drawn_after_slip.filter(func(k): return str(k) != "plants/sporebell"))

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
	#    reaches the same page the binoculars would have. The blade is found, not
	#    handed out: the katana lies on the same stroll as the satchel (world/kit.md),
	#    and picking it up is walking into it.
	var killed := (load("res://fauna/grazer.tscn") as PackedScene).instantiate()
	main.add_child(killed)
	killed.global_position = Vector3(aside.x, player.global_position.y, aside.z)
	await _wait(0.3)
	var katana := _nearest_sword(main, player)
	if katana == null:
		fails.append("no_katana_in_the_world")
	else:
		katana.call("_on_body_entered", player)
	# Picking a sword up is a page too (ui/story_text.gd's `katana` milestone).
	_close_story(main)
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

	# 13. The survey's beat: SURVEY_PLANTS plants **and** SURVEY_ANIMALS animals is a survey
	#     of an island, and what it earns is that island's own page — `ui/story_text.gd`'s
	#     `ezo` for Ezo, asked for on the drawing that *completed* the count and on that
	#     drawing only. The notebook is brought to one drawing short by hand, because the
	#     six holds themselves are what the sections above already cover; the **crossing**
	#     is what this checks, and the crossing is a real drawing.
	for id in PediaData.subchapter_ids("plants"):
		if Notes.count_drawn("plants") >= StudyScript.SURVEY_PLANTS - 1:
			break
		if str(id) in ["lantern_reed", "windsinger"]:
			continue                  # the two left for the real drawings below
		Notes.unlock("plants", str(id))
	for id in PediaData.subchapter_ids("animals"):
		if Notes.count_drawn("animals") >= StudyScript.SURVEY_ANIMALS:
			break
		Notes.unlock("animals", str(id))
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story == null:
		fails.append("no_story_screen_for_the_survey")
	elif Notes.count_drawn("plants") != StudyScript.SURVEY_PLANTS - 1 \
			or Notes.count_drawn("animals") != StudyScript.SURVEY_ANIMALS:
		fails.append("could_not_set_up_a_survey:%d/%d"
				% [Notes.count_drawn("plants"), Notes.count_drawn("animals")])
	else:
		if not _equip(player, "magnifying_glass"):
			fails.append("glass_not_equippable_for_the_survey")
		await _wait(0.1)
		if story.is_playing():
			fails.append("a_page_was_up_before_the_survey_was_complete")
		if await _draw_a_plant(main, player, study, "lantern_reed") == "":
			fails.append("the_plant_that_completes_a_survey_was_not_drawn")
		if not story.is_playing():
			fails.append("the_completed_survey_played_no_page")
		elif str(story.milestone_id()) != "ezo":
			fails.append("the_survey_played_%s" % story.milestone_id())
		_close_story(main)
		await _wait(0.1)
		# ...and the page is asked for by the crossing, not by every drawing after it.
		if await _draw_a_plant(main, player, study, "windsinger") == "":
			fails.append("the_plant_after_a_survey_was_not_drawn")
		if story.is_playing():
			fails.append("the_survey_page_came_up_twice")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)