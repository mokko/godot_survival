extends Node3D
## The notebook's two instruments, and the only things that fill its species
## chapters (ui/pedia_notes.gd holds the result). An explorer has more than one way
## of looking, and each tool has its own subject:
##
##  - **Binoculars** (`binoculars`) observe, from a distance: BINOCULAR_RANGE. Left
##    click with the crosshair on an animal, hold it in view for STUDY_TIME, and its
##    entry appears. This is the way to draw something that would rather not be
##    approached.
##  - **Magnifying glass** (`magnifying_glass`) is close work: MAGNIFIER_RANGE. A
##    **plant** is drawn where it grows, by holding it in the lens for STUDY_TIME
##    and writing the observation down (the drone's pen does the writing). A **dead
##    animal** — what a blade left behind (items/carcass.gd) — is drawn the same way:
##    that is the **autopsy**, and it reaches the same page the binoculars do.
##
## Clicking the wrong tool at the wrong thing says so instead of starting a drawing
## that could never finish: the glass will not watch a living animal, the binoculars
## will not do close work.
##
## The subject is found by a ray from the camera, with an angular fallback so a
## small crab or a knee-high plant under the crosshair is aimable — the flat ground
## cover has no collision at all, so the fallback is the only way those can be
## drawn. Which Pedia page a node is comes from ui/pedia_species.gd, shared with
## the animals that leave specimens.
##
## Both views (ui/instrument_view.gd) and the meter (ui/study_meter.gd) are built in
## code and parented to the HUD, like the hurt flash and the hit marker.

const PediaData := preload("res://ui/pedia_data.gd")
const Notes := preload("res://ui/pedia_notes.gd")
const PediaSpecies := preload("res://ui/pedia_species.gd")
const InstrumentView := preload("res://ui/instrument_view.gd")
const StudyMeter := preload("res://ui/study_meter.gd")

const MAGNIFIER_ITEM := "magnifying_glass"
const BINOCULAR_ITEM := "binoculars"

const STUDY_TIME := 8.0       ## seconds a subject must be held in view
const MAGNIFIER_RANGE := 6.0  ## metres: a glass wants you close to the thing
const BINOCULAR_RANGE := 45.0 ## metres: how far an animal can be observed from
const LOST_GRACE := 0.6       ## seconds the subject may slip off the crosshair
const AIM_SLACK := 0.07       ## radians of tolerance when the ray itself misses
const MESSAGE_HOLD := 2.0     ## how long a "wrong tool" line stays
const LINE_FADE := 1.2        ## alpha per second while a line fades out

## Emitted once per newly drawn entry (nothing else reports a new drawing).
signal entry_drawn(chapter: String, id: String)

var player: CharacterBody3D = null   ## resolved from the scene tree in _ready

var _subject: Node3D = null
var _tool := ""               ## the instrument the session was started with
var _range := 0.0             ## that instrument's reach, fixed for the session
var _chapter := ""
var _id := ""
var _subject_name := ""
var _held := 0.0
var _lost := 0.0
var _message := 0.0
var _view: Control = null
var _meter: Control = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	assert(player != null, "study must be a direct child of the player")
	_build_hud()


func _process(delta: float) -> void:
	_update_view()
	_update_session(delta)
	if _subject != null:
		_update_meter()
	if _meter != null:
		_meter.fade_out(delta, LINE_FADE)


## ------------------------------------------------------------------- the state

func instrument() -> String:
	## Which tool is out, "" for neither. The click path and the view both ask.
	if player == null:
		return ""
	var held: String = player.get_equipped_item()
	if held == MAGNIFIER_ITEM or held == BINOCULAR_ITEM:
		return held
	return ""


func has_magnifier() -> bool:
	return instrument() == MAGNIFIER_ITEM


func has_binoculars() -> bool:
	return instrument() == BINOCULAR_ITEM


func is_studying() -> bool:
	return _subject != null


func progress() -> float:
	## Seconds held so far, 0..STUDY_TIME.
	return _held


func subject_name() -> String:
	return _subject_name


func subject_chapter() -> String:
	return _chapter


func subject_id() -> String:
	return _id


## -------------------------------------------------------------------- the click

func begin() -> bool:
	## A left click with a tool out. Returns true when the click had something to act
	## on: a subject to start drawing, or a refusal that named the right tool.
	var tool := instrument()
	if tool == "":
		cancel()
		return false
	var range_m := _range_of(tool)
	var found := _aimed_subject(range_m)
	if found.is_empty():
		cancel()
		return false
	var refusal := _refusal(tool, found["node"])
	if refusal != "":
		## The wrong instrument at the wrong thing: say which one is wanted rather
		## than starting a drawing that could never finish.
		cancel()
		_show_message(refusal)
		return true
	_subject = found["node"]
	_tool = tool
	_range = range_m
	_chapter = found["chapter"]
	_id = found["id"]
	_subject_name = found["name"]
	_held = 0.0
	_lost = 0.0
	_message = 0.0
	_update_meter()
	return true


func cancel() -> void:
	## Subject lost, tool put away, or the drone died: the drawing is abandoned
	## where it stands. Held time is not banked — the point is to hold still.
	_subject = null
	_tool = ""
	_range = 0.0
	_chapter = ""
	_id = ""
	_subject_name = ""
	_held = 0.0
	_lost = 0.0
	if _meter != null and _meter.message == "" and _message <= 0.0:
		_meter.visible = false


## --------------------------------------------------------------- the session

func _update_session(delta: float) -> void:
	_message = maxf(_message - delta, 0.0)
	if _subject == null:
		return
	if instrument() != _tool:
		cancel()
		return
	if not is_instance_valid(_subject) or _out_of_range(_subject) or not _on_target():
		## A slip of the hand is forgiven for LOST_GRACE; past that the drawing is
		## restarted from nothing, so the entry means "I watched this properly".
		_lost += delta
		if _lost >= LOST_GRACE:
			cancel()
		return
	_lost = 0.0
	_held += delta
	if _held >= STUDY_TIME:
		_draw_entry()


func _draw_entry() -> void:
	var drawn_chapter := _chapter
	var drawn_id := _id
	var fresh := Notes.unlock(drawn_chapter, drawn_id)
	var name := _subject_name
	var autopsy := PediaSpecies.is_specimen(_subject)
	_subject = null
	_tool = ""
	_range = 0.0
	_held = 0.0
	_chapter = ""
	_id = ""
	_subject_name = ""
	## An autopsy gets its own word: it reached the same page the binoculars would
	## have, but it was done the other way, and the drone should hear which.
	var note := "Autopsy: %s" % name if autopsy else "Drawn: %s" % name
	if not fresh:
		note += " (again)"
	_show_message(note)
	if fresh:
		entry_drawn.emit(drawn_chapter, drawn_id)


func _update_meter() -> void:
	if _meter == null:
		return
	if _subject != null:
		_meter.set_state(_subject_name, _held, STUDY_TIME)


func _show_message(text: String) -> void:
	if _meter == null:
		return
	_meter.show_message(text)
	_message = MESSAGE_HOLD


## -------------------------------------------------------------------- the aim

func _range_of(tool: String) -> float:
	## How far this instrument can see: the binoculars observe at a distance, the
	## glass works at arm's length.
	return BINOCULAR_RANGE if tool == BINOCULAR_ITEM else MAGNIFIER_RANGE


func _refusal(tool: String, node: Node) -> String:
	## Each instrument has its own subject, so clicking the wrong one says which is
	## wanted. Returns "" when this tool is the right one for this thing.
	##
	##  binoculars → a living animal, from a distance
	##  glass      → a plant where it grows, or the autopsy of what a blade killed
	var record := PediaSpecies.of_node(node)
	var chapter := str(record.get("chapter", ""))
	var dead := PediaSpecies.is_specimen(node)
	if tool == BINOCULAR_ITEM and (dead or chapter == "plants"):
		return "Close work — use the magnifying glass"
	if tool == MAGNIFIER_ITEM and chapter == "animals" and not dead:
		return "Watch it through the binoculars — or open it with a blade"
	return ""


func _aimed_subject(range_m: float) -> Dictionary:
	## What the crosshair is on, if the notebook has a page for it. The ray finds
	## most of it; the angular fallback catches small bodies the ray slips past (a
	## crab's collision capsule is 30 cm) and the species with no collision at all.
	var space := player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * range_m
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true      # flat flora and specimens live on Area3D
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var found := _study_of(hit["collider"] as Node)
		if not found.is_empty():
			return found
	return _nearest_in_view(range_m)


func _nearest_in_view(range_m: float) -> Dictionary:
	var forward: Vector3 = -player.camera.global_transform.basis.z
	var from: Vector3 = player.camera.global_position
	var best: Node3D = null
	var best_dot := cos(AIM_SLACK)
	for entry in _studyable_nodes():
		var node := entry as Node3D
		var to: Vector3 = node.global_position - from
		var dist := to.length()
		if dist < 0.1 or dist > range_m:
			continue
		var dot: float = forward.dot(to / dist)
		if dot > best_dot:
			best_dot = dot
			best = node
	if best == null:
		return {}
	return _study_of(best)


func _on_target() -> bool:
	## Is the subject still under the crosshair? The same question as
	## _aimed_subject(), asked about one known node: the ray's first hit, or the
	## angle, which is what the player is actually steering with.
	if _subject == null:
		return false
	var space := player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * _range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] == _subject:
		return true
	# The ray may end on a leaf or a rock in front of the animal; the angle decides.
	var to_subject: Vector3 = _subject.global_position - from
	var dist := to_subject.length()
	if dist < 0.1:
		return true
	return (-player.camera.global_transform.basis.z).dot(to_subject / dist) >= cos(AIM_SLACK)


func _out_of_range(node: Node3D) -> bool:
	## Measured with the range the session was started with, not the current tool,
	## so a subject does not vanish mid-drawing because the tool changed (putting the
	## tool away is handled by _update_session).
	return player.camera.global_position.distance_to(node.global_position) > _range


func _studyable_nodes() -> Array:
	## Every species instance and every specimen in the world, found by what they
	## are. Only called when a click needs the angular fallback, so a tree walk is
	## fine — and it is the only way to reach species with no collision at all (the
	## flat ground cover: embermoss, pulsegrass), which the ray can never hit.
	var out: Array = []
	var scene: Node = player.get_tree().current_scene
	if scene == null:
		scene = player.get_tree().root
	_collect_species(scene, out)
	return out


func _collect_species(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Node3D and PediaSpecies.is_species(child):
			out.append(child)
		_collect_species(child, out)


func _study_of(node: Node) -> Dictionary:
	## The page a world node has, plus the node itself, which the session needs to
	## hold on to while it draws.
	var record := PediaSpecies.of_node(node)
	if record.is_empty():
		return {}
	return {"node": node, "chapter": record["chapter"], "id": record["id"],
			"name": record["name"]}


## -------------------------------------------------------------------- the HUD

func _build_hud() -> void:
	var hud: CanvasLayer = player.get_node_or_null("../HUD")
	if hud == null:
		return
	_view = Control.new()
	_view.set_script(InstrumentView)
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.visible = false
	hud.add_child(_view)
	_meter = Control.new()
	_meter.set_script(StudyMeter)
	_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_meter.offset_left = -130.0
	_meter.offset_right = 130.0
	_meter.offset_top = -140.0
	_meter.offset_bottom = -132.0
	_meter.visible = false
	hud.add_child(_meter)


func _update_view() -> void:
	## Binoculars: two tubes. Magnifying glass: one lens, closer in. Neither: none.
	if _view == null:
		return
	var held := instrument()
	_view.visible = held != ""
	if held == BINOCULAR_ITEM:
		_view.tubes = 2
		_view.radius_fraction = 0.34
	elif held == MAGNIFIER_ITEM:
		_view.tubes = 1
		_view.radius_fraction = 0.42
	if _view.visible:
		_view.queue_redraw()
	if _meter != null and _meter.visible and _meter.message == "" \
			and _subject == null:
		_meter.visible = false