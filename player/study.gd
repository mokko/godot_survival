extends Node3D
## Studying a species — the only way a plant or animal gets drawn into the notebook.
##
## The player equips the binoculars and clicks with the crosshair on a species,
## then holds it in view for STUDY_TIME seconds; the entry is drawn and the Pedia
## lists it from then on. Nothing else fills the notebook's species chapters.
##
## The subject is found by a ray from the camera, with an angular fallback so a
## small crab under the crosshair is aimable (see _aimed_subject()). A species is
## studyable when its own scene file names a Pedia subchapter — fauna/grazer.tscn
## is animals/grazer, flora/sunbulb.tscn is plants/sunbulb — the same ids
## ui/pedia_data.gd already uses. So a species becomes studyable by being built,
## and ground-cover variants with no page of their own (mirrorlily_small) simply
## are not studyable.
##
## While the binoculars are equipped, this node also shows the binocular view
## (ui/binocular_view.gd) and the study meter (ui/study_meter.gd); both are built
## in code and parented to the HUD, like the hurt flash and the hit marker.

const PediaData := preload("res://ui/pedia_data.gd")
const Notes := preload("res://ui/pedia_notes.gd")
const BinocularView := preload("res://ui/binocular_view.gd")
const StudyMeter := preload("res://ui/study_meter.gd")

const BINOCULAR_ITEM := "binoculars"
const STUDY_TIME := 8.0      ## seconds the subject must be held in view
const STUDY_RANGE := 45.0    ## metres: further away than this is too far to draw
const LOST_GRACE := 0.6      ## seconds the subject may slip off the crosshair
const AIM_SLACK := 0.07      ## radians of tolerance when the ray itself misses
const DONE_HOLD := 1.6       ## how long the "Drawn!" line stays up
const DONE_FADE := 1.2       ## alpha per second while it fades

## Emitted once per newly drawn entry (the study code has no other output).
signal entry_drawn(chapter: String, id: String)

var player: CharacterBody3D = null   ## resolved from the scene tree in _ready

var _subject: Node3D = null
var _chapter := ""
var _id := ""
var _subject_name := ""
var _held := 0.0
var _lost := 0.0
var _done := 0.0
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
		_meter.fade_out(delta, DONE_FADE)


func equipped() -> bool:
	## Is the drone holding the binoculars? The click path and the view both ask.
	return player != null and player.get_equipped_item() == BINOCULAR_ITEM


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


func begin() -> bool:
	## A left click with the binoculars out. Returns true when there is something
	## to study under the crosshair, so the caller can cue a click either way.
	var found := _aimed_subject()
	if found.is_empty():
		cancel()
		return false
	_subject = found["node"]
	_chapter = found["chapter"]
	_id = found["id"]
	_subject_name = found["name"]
	_held = 0.0
	_lost = 0.0
	_done = 0.0
	_update_meter()
	return true


func cancel() -> void:
	## Target lost, put away, or the drone died: the drawing is abandoned where it
	## stands. Held time is not banked — the point of studying is to hold still.
	_subject = null
	_chapter = ""
	_id = ""
	_subject_name = ""
	_held = 0.0
	_lost = 0.0
	if _meter != null and _meter.done_text == "":
		_meter.visible = false


## --------------------------------------------------------------- the session

func _update_session(delta: float) -> void:
	if _done > 0.0:
		_done = maxf(_done - delta, 0.0)
	if _subject == null:
		return
	if not equipped():
		cancel()
		return
	if not is_instance_valid(_subject) or _out_of_range(_subject) or not _on_target():
		## A slip of the hand is forgiven for LOST_GRACE; past that the drawing is
		## restarted from nothing, so the entry means "I watched this animal".
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
	_subject = null
	_held = 0.0
	_chapter = ""
	_id = ""
	_subject_name = ""
	_done = DONE_HOLD
	if _meter != null:
		_meter.show_done(name if fresh else "%s (again)" % name)
	if fresh:
		entry_drawn.emit(drawn_chapter, drawn_id)


func _update_meter() -> void:
	if _meter == null:
		return
	if _subject != null:
		_meter.set_state(_subject_name, _held, STUDY_TIME)
	elif _done <= 0.0:
		_meter.visible = false


## ------------------------------------------------------------------ the aim

func _aimed_subject() -> Dictionary:
	## What the crosshair is on, if it is a species that can be drawn. The ray
	## finds most of them; the angular fallback catches small bodies the ray slips
	## past (a crab's collision capsule is 30 cm) without letting the player study
	## something beside the crosshair.
	var space := player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * STUDY_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true      # flat flora (sunbulb) lives on Area3D
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var found := _study_of(hit["collider"] as Node)
		if not found.is_empty():
			return found
	return _nearest_in_view()


func _nearest_in_view() -> Dictionary:
	var forward: Vector3 = -player.camera.global_transform.basis.z
	var from: Vector3 = player.camera.global_position
	var best: Node3D = null
	var best_dot := cos(AIM_SLACK)
	for entry in _studyable_nodes():
		var node := entry as Node3D
		var to: Vector3 = node.global_position - from
		var dist := to.length()
		if dist < 0.1 or dist > STUDY_RANGE:
			continue
		var dot: float = forward.dot(to / dist)
		if dot > best_dot:
			best_dot = dot
			best = node
	if best == null:
		return {}
	return _study_of(best)


func _on_target() -> bool:
	## Is the subject still under the crosshair? Same question as _aimed_subject(),
	## asked about one known node: the ray's first hit, or the angular test.
	if _subject == null:
		return false
	var space := player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * STUDY_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] == _subject:
		return true
	# The ray may end on a leaf or a rock in front of the animal; the angle is what
	# the player is actually steering with.
	var to_subject: Vector3 = _subject.global_position - from
	var dist := to_subject.length()
	if dist < 0.1:
		return true
	return (-player.camera.global_transform.basis.z).dot(to_subject / dist) >= cos(AIM_SLACK)


func _out_of_range(node: Node3D) -> bool:
	return player.camera.global_position.distance_to(node.global_position) > STUDY_RANGE


func _studyable_nodes() -> Array:
	## Every species instance in the world, found by its scene path. Only called
	## when a click needs the angular fallback, so a tree walk is fine — and it is
	## the only way to reach species with no collision at all (the flat ground
	## cover: embermoss, pulsegrass), which the ray can never hit.
	var out: Array = []
	var scene: Node = player.get_tree().current_scene
	if scene == null:
		scene = player.get_tree().root
	_collect_species(scene, out)
	return out


func _collect_species(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Node3D and _is_species(child):
			out.append(child)
		_collect_species(child, out)


func _is_species(node: Node) -> bool:
	return not _study_of(node).is_empty()


func _study_of(node: Node) -> Dictionary:
	## Which Pedia subchapter a world node is, if any. The scene file is the map:
	## a species instance carries its own scene's path even when it sits inside the
	## baked animals_placed.tscn / plants_placed.tscn.
	var node_3d := node as Node3D
	if node_3d == null:
		return {}
	var path := node_3d.scene_file_path
	var chapter := ""
	if path.begins_with("res://fauna/"):
		chapter = "animals"
	elif path.begins_with("res://flora/"):
		chapter = "plants"
	else:
		return {}
	var id := path.get_file().get_basename()
	var record: Dictionary = PediaData.subchapter(chapter, id)
	if record.is_empty():
		return {}   # a variant with no page of its own (mirrorlily_small)
	return {"node": node_3d, "chapter": chapter, "id": id,
			"name": str(record["name"])}


## -------------------------------------------------------------------- the HUD

func _build_hud() -> void:
	var hud: CanvasLayer = player.get_node_or_null("../HUD")
	if hud == null:
		return
	_view = Control.new()
	_view.set_script(BinocularView)
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
	if _view != null:
		_view.visible = equipped()
	if _meter != null and _meter.visible and _meter.done_text == "" \
			and _subject == null:
		_meter.visible = false
	if _subject != null:
		_update_meter()