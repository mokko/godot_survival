extends Node3D
## The drone's head: what sits on the neck, including the **eye**.
##
## Same shape as `player/legs.gd` and `player/torsos.gd`: `STOCK` is the R2 dome the drone has
## always had, `PARTS` is the catalogue in the order the Robo Editor cycles it, `NAMES` names
## them, `COLOURS` is what one looks like lying in the world, and the meshes are Godot primitives
## parented here and nowhere else.
##
## **The contract with `player/equipment.gd`: every head has a child named `Eye`.** That single
## emissive lens is the drone's face — equipment keeps a reference to it and dims it for the hurt
## flash — so a head that built no eye would leave the drone expressionless and the flash with
## nothing to dim. `_eye(pos)` builds it, and every part below calls it.
##
## Space: the drone's origin is on the ground, the neck tops out around y 0.95 (see
## `player/torsos.gd::neck_y()`), and the drone faces **-Z**. A head sits from about y 0.95 up and
## keeps |x| and |z| inside ~0.3.

## The head the drone is built with. Not a part to find.
const STOCK := "head_dome"

## The catalogue, in the order the Robo Editor cycles through it.
const PARTS := ["head_visor", "head_twin", "head_dish"]

const NAMES := {
	"head_dome": "Dome head",
	"head_visor": "Visor head",
	"head_twin": "Twin-lens head",
	"head_dish": "Dish head",
}

const COLOURS := {
	"head_dome": Color(0.88, 0.90, 0.92),
	"head_visor": Color(0.70, 0.74, 0.78),
	"head_twin": Color(0.30, 0.34, 0.38),
	"head_dish": Color(0.86, 0.88, 0.90),
}

var _part := STOCK


func _ready() -> void:
	if get_child_count() == 0:
		set_part(STOCK)


func part() -> String:
	return _part


func name_of(id: String) -> String:
	return str(NAMES.get(id, id))


func set_part(id: String) -> bool:
	## Swap the head. False for an unknown id. The old one leaves the tree now, so a frame never
	## shows two heads — and equipment re-reads `Eye` afterwards (`equipment.gd::_refresh_eye()`).
	if not NAMES.has(id):
		return false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_part = id
	match id:
		"head_dome":
			_build_dome()
		"head_visor":
			_build_visor()
		"head_twin":
			_build_twin()
		"head_dish":
			_build_dish()
	return true


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

func _dome(radius: float, height: float, y: float,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 24
	s.rings = 12
	var m := MeshInstance3D.new()
	m.mesh = s
	m.position = Vector3(0, y, 0)
	m.material_override = mat
	add_child(m)
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var m := MeshInstance3D.new()
	m.mesh = b
	m.position = pos
	m.material_override = mat
	add_child(m)
	return m


func _ring(inner: float, outer: float, y: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	var m := MeshInstance3D.new()
	m.mesh = t
	m.position = Vector3(0, y, 0)
	m.material_override = mat
	add_child(m)
	return m


func _tube(radius: float, height: float, pos: Vector3, rot: Basis,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 14
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	m.transform = Transform3D(rot, pos)
	m.material_override = mat
	add_child(m)
	return m


func _eye(pos: Vector3, radius := 0.06, colour := Color(0.2, 0.9, 1.0)) -> MeshInstance3D:
	## The face. **Named `Eye` on purpose** — see the header: equipment reaches for this name
	## after every head swap, so it is part of the part's contract, not a detail.
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	var m := MeshInstance3D.new()
	m.name = "Eye"
	m.mesh = s
	m.position = pos
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = colour
	eye_mat.emission_enabled = true
	eye_mat.emission = colour
	m.material_override = eye_mat
	add_child(m)
	return m


# -------------------------------------------------------------------- the parts

func _build_dome() -> void:
	## R2's dome with the blue panel stripe: the head the drone has always had, moved here from
	## `player/equipment.gd` so every head lives in one file.
	var white := _white()
	_dome(0.22, 0.44, 1.08, white)
	_ring(0.19, 0.225, 1.06, _blue())
	_eye(Vector3(0, 1.1, -0.2))


func _build_visor() -> void:
	## A flattened dome with a wide dark visor slot across the front — the eye sits *inside* the
	## slot, so the face is a lit slit rather than a lens on a shell.
	var white := _white()
	_dome(0.22, 0.26, 1.04, _mat(Color(0.72, 0.76, 0.80)))
	_box(Vector3(0.34, 0.09, 0.06), Vector3(0, 1.06, -0.19), _dark())
	_box(Vector3(0.38, 0.03, 0.20), Vector3(0, 0.99, -0.06), _dark())
	_eye(Vector3(0, 1.06, -0.215), 0.045, Color(0.45, 1.0, 0.75))
	# A short antenna, so the silhouette is not just a squashed dome.
	_tube(0.012, 0.20, Vector3(0.14, 1.22, 0.02), Basis(Vector3.RIGHT, 0.18), _silver())


func _build_twin() -> void:
	## A squat dark sensor block with **two** lenses and a hood over them: the machine-looking
	## head. The right-hand lens is `Eye`; the left one is its twin, built as a plain mesh, so
	## equipment's hurt-flash still dims the one it knows.
	var block := _mat(Color(0.26, 0.30, 0.34), 0.4, 0.5)
	_box(Vector3(0.32, 0.20, 0.30), Vector3(0, 1.06, -0.02), block)
	_box(Vector3(0.36, 0.04, 0.34), Vector3(0, 1.17, -0.02), _dark())
	for side in [-1.0, 1.0]:
		_tube(0.045, 0.05, Vector3(side * 0.09, 1.07, -0.19), Basis(Vector3.BACK, PI * 0.5),
				_dark() if side < 0.0 else _silver())
	_eye(Vector3(0.09, 1.07, -0.21), 0.038, Color(0.2, 0.9, 1.0))
	_tube(0.02, 0.16, Vector3(-0.12, 1.24, 0.0), Basis(), block)


func _build_dish() -> void:
	## The plain dome with a tilted dish on a short post — a survey drone's head, which is what
	## this machine is here to do.
	var white := _white()
	_dome(0.21, 0.42, 1.07, white)
	_ring(0.16, 0.20, 0.99, _silver())
	_tube(0.018, 0.14, Vector3(0.0, 1.30, 0.02), Basis(), _dark())
	var dish := CylinderMesh.new()
	dish.top_radius = 0.15
	dish.bottom_radius = 0.13
	dish.height = 0.03
	dish.radial_segments = 18
	dish.rings = 1
	var plate := MeshInstance3D.new()
	plate.name = "Dish"
	plate.mesh = dish
	plate.transform = Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.0, 1.38, -0.03))
	plate.material_override = _silver()
	add_child(plate)
	_eye(Vector3(0, 1.08, -0.19), 0.055, Color(0.9, 0.75, 0.3))
