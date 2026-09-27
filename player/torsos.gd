extends Node3D
## The drone's torso: the box the head sits on and the legs carry, as a swappable part.
##
## Same shape as `player/legs.gd`, deliberately: `STOCK` is what the drone was built with (so a
## fresh run looks exactly as it always did), `PARTS` is the catalogue in order, `NAMES` is the
## one place a part is named, `COLOURS` is what it looks like lying in the world, and every part
## is a plain tree of Godot primitives parented here and nowhere else.
##
## **Nothing about a part does anything yet** (Maurice, 27 Sep): they are cosmetics, chosen in the
## Robo Editor, and the same file is where a part's effect will live — the numbers that matter to
## the body (arm shoulder height, chest lens position, the neck's height) are exposed as
## functions rather than consts, so a future part can answer differently without the arms or the
## camera being told twice.
##
## The body's own space: the drone's origin is on the ground, the torso spans about y 0.35 to
## 0.9, and the drone faces **-Z** (eye, chest lens and arms are on that side). Every part keeps
## that: a torso that ignored it would put the chest lens round the back.

## The torso the drone is built with. Not a part to find.
const STOCK := "torso_stock"

## The catalogue, in the order the Robo Editor cycles through it.
const PARTS := ["torso_slim", "torso_plated", "torso_round"]

const NAMES := {
	"torso_stock": "Stock body",
	"torso_slim": "Slim body",
	"torso_plated": "Plated body",
	"torso_round": "Barrel body",
}

const COLOURS := {
	"torso_stock": Color(0.88, 0.90, 0.92),
	"torso_slim": Color(0.80, 0.86, 0.90),
	"torso_plated": Color(0.68, 0.72, 0.76),
	"torso_round": Color(0.90, 0.90, 0.94),
}

var _part := STOCK


func _ready() -> void:
	## Built here, like the legs: a Torso node dropped into a scene stands on its own.
	if get_child_count() == 0:
		set_part(STOCK)


func part() -> String:
	return _part


func name_of(id: String) -> String:
	return str(NAMES.get(id, id))


func set_part(id: String) -> bool:
	## Swap the part. False for an id we do not know. The old set leaves the tree *now*, so
	## nothing counting the body's meshes ever sees two torsos at once.
	if not NAMES.has(id):
		return false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_part = id
	match id:
		"torso_stock":
			_build_stock()
		"torso_slim":
			_build_slim()
		"torso_plated":
			_build_plated()
		"torso_round":
			_build_round()
	return true


func shoulder_y() -> float:
	## Where the arms hang from, for this torso. The arms are `player/equipment.gd`'s, and they
	## are built against *this* number rather than a constant of their own, so a shorter or taller
	## body does not leave the arms floating.
	match _part:
		"torso_slim":
			return 0.84
		"torso_plated":
			return 0.66
		"torso_round":
			return 0.70
	return 0.72


func shoulder_x() -> float:
	## How far out the shoulders sit: the half-width of this torso plus a little.
	match _part:
		"torso_slim":
			return 0.28
		"torso_plated":
			return 0.40
		"torso_round":
			return 0.34
	return 0.36


func neck_y() -> float:
	## The top of the torso, where the neck is built. The head then sits above it.
	match _part:
		"torso_slim":
			return 0.94
		"torso_plated":
			return 0.86
		"torso_round":
			return 0.90
	return 0.95


# ------------------------------------------------------------------ materials

func _mat(colour: Color, metallic := 0.3, roughness := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = metallic
	m.roughness = roughness
	return m


func _white() -> StandardMaterial3D:
	return _mat(Color(0.88, 0.9, 0.92))


func _blue() -> StandardMaterial3D:
	return _mat(Color(0.16, 0.32, 0.62), 0.4, 0.4)


func _dark() -> StandardMaterial3D:
	return _mat(Color(0.12, 0.13, 0.15), 0.5, 0.6)


func _silver() -> StandardMaterial3D:
	return _mat(Color(0.75, 0.77, 0.8), 0.8, 0.25)


# --------------------------------------------------------------- construction

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var m := MeshInstance3D.new()
	m.mesh = b
	m.position = pos
	m.material_override = mat
	add_child(m)
	return m


func _tube(radius: float, height: float, pos: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.position = pos
	m.material_override = mat
	add_child(m)
	return m


func _ring(inner: float, outer: float, pos: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	var m := MeshInstance3D.new()
	m.mesh = t
	m.position = pos
	m.material_override = mat
	add_child(m)
	return m


func _lens(pos: Vector3) -> MeshInstance3D:
	## The chest "life display", on the front face of every torso: it is the drone's own light,
	## and a torso without one would look like a box rather than like this machine.
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.11
	var m := MeshInstance3D.new()
	m.mesh = s
	m.position = pos
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.25, 0.7, 1.0)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.25, 0.7, 1.0)
	m.material_override = lens_mat
	add_child(m)
	return m


# -------------------------------------------------------------------- the parts

func _build_stock() -> void:
	## WALL-E's box with R2's blue band: the body the drone has always had, moved here from
	## `player/equipment.gd` so every torso lives in one file.
	var white := _white()
	_box(Vector3(0.56, 0.5, 0.44), Vector3(0, 0.62, 0), white)
	_box(Vector3(0.58, 0.14, 0.46), Vector3(0, 0.68, 0), _blue())
	_lens(Vector3(0.0, 0.62, -0.25))
	_tube(0.06, 0.16, Vector3(0, 0.95, 0), _dark())


func _build_slim() -> void:
	## Narrower and taller, with the blue band low like a waist: a lighter machine, and the
	## silhouette that reads most differently from the stock body at a glance.
	var white := _white()
	_box(Vector3(0.42, 0.56, 0.34), Vector3(0, 0.62, 0), white)
	_box(Vector3(0.44, 0.07, 0.36), Vector3(0, 0.74, 0), _blue())
	_box(Vector3(0.46, 0.05, 0.38), Vector3(0, 0.40, 0), _silver())
	_lens(Vector3(0.0, 0.60, -0.20))
	_tube(0.05, 0.14, Vector3(0, 0.93, 0), _dark())


func _build_plated() -> void:
	## Wide and low with armour plates down the sides and a dark belt: the heavy one. The plates
	## are proud of the body so the width reads as *plating* and not as a fatter box.
	var white := _white()
	_box(Vector3(0.54, 0.44, 0.46), Vector3(0, 0.60, 0), white)
	_box(Vector3(0.56, 0.12, 0.48), Vector3(0, 0.66, 0), _blue())
	_box(Vector3(0.60, 0.06, 0.50), Vector3(0, 0.42, 0), _dark())
	for side in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.34, 0.40), Vector3(side * 0.30, 0.62, 0), _silver())
		_box(Vector3(0.05, 0.05, 0.30), Vector3(side * 0.30, 0.44, 0), _blue())
	_lens(Vector3(0.0, 0.60, -0.26))
	_tube(0.065, 0.14, Vector3(0, 0.86, 0), _dark())


func _build_round() -> void:
	## A barrel: a cylinder body with a ring round its top and a small domed cap, so the third
	## torso is a different *kind* of shape rather than another rectangle.
	var white := _white()
	_tube(0.25, 0.48, Vector3(0, 0.62, 0), white)
	_ring(0.24, 0.27, Vector3(0, 0.82, 0), _blue())
	_tube(0.16, 0.06, Vector3(0, 0.88, 0), _silver())
	_box(Vector3(0.30, 0.06, 0.20), Vector3(0, 0.40, 0), _dark())
	_lens(Vector3(0.0, 0.62, -0.24))
	_tube(0.055, 0.12, Vector3(0, 0.95, 0), _dark())
