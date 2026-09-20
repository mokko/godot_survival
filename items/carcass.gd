extends Area3D
## A specimen: what is left of an animal that was killed with a blade. It is the
## only way an animal gets into the notebook — the magnifying glass draws a plant
## alive, but an animal has to be dead and examinable first (fauna/fauna_base.gd
## leaves one of these when the killing blow came from an edge).
##
## An Area3D, not a body: a corpse should not block the drone, and the study ray
## looks for areas as well as bodies. Built in code like everything else — a low
## body in the species' own colour, a darker head end, and a few stiff legs — and
## it fades out of the world after SPECIMEN_TIME.

const PediaData := preload("res://ui/pedia_data.gd")

## How long a specimen stays worth walking back to. Long enough to kill, go and
## find it, and draw it; short enough that the island is not paved with corpses.
const SPECIMEN_TIME := 90.0

## The colour each species' specimen is drawn in. One table, in the one place that
## shows it — the notebook's picture of the species comes from ui/pedia_art.gd.
const SPECIMEN_COLOURS := {
	"grazer": Color(0.42, 0.5, 0.34),
	"scuttler": Color(0.5, 0.48, 0.45),
	"drifter": Color(0.78, 0.76, 0.66),
	"gull": Color(0.72, 0.75, 0.8),
	"rippleback": Color(0.26, 0.28, 0.32),
	"stalker": Color(0.14, 0.14, 0.16),
}

var chapter := ""
var species_id := ""
var display_name := ""

var _age := 0.0
var _fade := 1.0


static func spawn(parent: Node, pos: Vector3, chapter_id: String, id: String,
		name: String) -> Node3D:
	## Called by a dying animal. Returns null when there is no parent to hold it or
	## no Pedia page to draw, so a species nobody can examine leaves nothing.
	if parent == null or PediaData.subchapter(chapter_id, id).is_empty():
		return null
	var carcass := Area3D.new()
	carcass.set_script(load("res://items/carcass.gd"))
	parent.add_child(carcass)
	carcass.chapter = chapter_id
	carcass.species_id = id
	carcass.display_name = name
	carcass.global_position = pos
	carcass._build()
	return carcass


## What this specimen is, for the study code (player/study.gd asks duck-typed:
## any node with these three methods is examinable).
func study_chapter() -> String:
	return chapter


func study_id() -> String:
	return species_id


func study_name() -> String:
	return display_name


func _ready() -> void:
	add_to_group("specimen")
	# The light stays on it: a corpse in the dark should still be findable.
	_build_light()


func _process(delta: float) -> void:
	_age += delta
	if _age > SPECIMEN_TIME:
		queue_free()


func _build() -> void:
	## Low body, darker head, stiff legs: enough to read as "the remains of" at a
	## glance and to look like the animal it was, in the animal's colour.
	var colour: Color = SPECIMEN_COLOURS.get(species_id, Color(0.45, 0.42, 0.38))
	var dark := colour.darkened(0.35)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.22, 0.28)
	body.mesh = bm
	body.material_override = _material(colour)
	body.position.y = 0.12
	add_child(body)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.2, 0.18, 0.2)
	head.mesh = hm
	head.material_override = _material(dark)
	head.position = Vector3(0.36, 0.14, 0.0)
	add_child(head)
	for i in 3:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.1, 0.05)
		leg.mesh = lm
		leg.material_override = _material(dark)
		leg.position = Vector3(-0.18 + i * 0.18, 0.05, 0.1 * (1 if i % 2 == 0 else -1))
		add_child(leg)
	# A small shape to be aimed at: the ray must be able to land on the remains.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.3, 0.4)
	shape.shape = box
	shape.position.y = 0.15
	add_child(shape)


func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	return mat


func _build_light() -> void:
	## A faint warm glow so a specimen can be found after dark.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.75)
	light.light_energy = 0.6
	light.omni_range = 4.0
	light.position.y = 0.4
	add_child(light)