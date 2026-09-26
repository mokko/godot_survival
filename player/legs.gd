extends Node3D
## The drone's legs: what it stands and rolls on, as swappable parts.
##
## **The stock fit is `tread_plain`** — the twin treads the body has always worn, so
## a fresh run looks exactly as it did before legs existed. `PARTS` is the catalogue
## of parts the player can fit at a service bench (the Frame screen will list them),
## and `NAMES` is the one place any of them is given a name — including the stock
## fit, so a screen showing "what is on now" needs no second table.
##
## Every set is built at the drone's own scale: the body spans y 0.37 to 0.87 and the
## player's origin sits on the ground, so a set fills y 0 to ~0.45 and stays inside
## |x| 0.45, |z| 0.4. The drone faces **-Z** (its eye, chest lens and arms are all on
## that side), so front-facing parts use -Z too.
##
## A set is a plain tree of MeshInstance3D children, built only from Godot primitives
## — no imported models (art canon). This node owns the current fit and rebuilds it,
## which is why it is a node with a script rather than a bare container: nothing else
## may parent leg meshes onto the body, or a swap would leave them behind.

## The legs the drone is built with. Not a part to find.
const STOCK := "tread_plain"

## The parts in catalogue order — "three different leg parts" (Maurice, 26 Sep).
const PARTS := ["tread_triangle", "legs_three", "legs_telescope"]

## Every fit, stock included, with the name to show for it.
const NAMES := {
	"tread_plain": "Twin treads",
	"tread_triangle": "Triangle treads",
	"legs_three": "Three legs",
	"legs_telescope": "Telescope legs",
}

var _part := STOCK


func _ready() -> void:
	## Built here rather than by the caller, so a Legs node dropped into a scene
	## without touching it still stands on something.
	if get_child_count() == 0:
		set_part(STOCK)


func part() -> String:
	## Which fit is on the drone right now.
	return _part


func name_of(id: String) -> String:
	return str(NAMES.get(id, id))


func set_part(id: String) -> bool:
	## Swap the fit. True when the id is one we know. The old set is removed from the
	## tree *now* rather than at the end of the frame, so nothing that counts the
	## body's meshes sees both fits at once.
	if not NAMES.has(id):
		return false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_part = id
	match id:
		"tread_plain":
			_build_tread_plain()
		"tread_triangle":
			_build_tread_triangle()
		"legs_three":
			_build_legs_three()
		"legs_telescope":
			_build_legs_telescope()
	return true


# ------------------------------------------------------------------ materials

func _mat(colour: Color, metallic := 0.3, roughness := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = metallic
	m.roughness = roughness
	return m


func _white() -> StandardMaterial3D:
	return _mat(Color(0.88, 0.9, 0.92), 0.3, 0.45)


func _blue() -> StandardMaterial3D:
	return _mat(Color(0.16, 0.32, 0.62), 0.4, 0.4)


func _dark() -> StandardMaterial3D:
	return _mat(Color(0.12, 0.13, 0.15), 0.5, 0.6)


func _silver() -> StandardMaterial3D:
	return _mat(Color(0.75, 0.77, 0.8), 0.8, 0.25)


# --------------------------------------------------------------- construction

func _piece(mesh: Mesh, pos: Vector3, mat: StandardMaterial3D,
		rot := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.transform = Transform3D(rot, pos)
	m.material_override = mat
	add_child(m)
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D,
		rot := Basis()) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _piece(b, pos, mat, rot)


func _disc(radius: float, width: float, pos: Vector3, mat: StandardMaterial3D,
		segments := 12) -> MeshInstance3D:
	## A cylinder lying across the drone: axis along X, which is the axle every
	## wheel, hub and ankle joint on this body turns on.
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = width
	c.radial_segments = segments
	c.rings = 1
	return _piece(c, pos, mat, Basis(Vector3.BACK, PI * 0.5))


func _tube(radius: float, height: float, pos: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	## An upright cylinder — a leg segment, not a wheel.
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 1
	return _piece(c, pos, mat)


func _bar(a: Vector3, b: Vector3, width: float, thickness: float,
		mat: StandardMaterial3D) -> MeshInstance3D:
	## A flat bar from a to b in the YZ plane: a track belt segment, or any strut
	## that has to run at an angle. The box is long in Z and turned about X, since
	## legs only ever rake fore-and-aft, never sideways.
	var d := b - a
	var ang := atan2(-d.y, d.z)
	var bm := BoxMesh.new()
	bm.size = Vector3(width, thickness, d.length())
	return _piece(bm, (a + b) * 0.5, mat, Basis(Vector3.RIGHT, ang))


# ------------------------------------------------------------------- the fits

func _build_tread_plain() -> void:
	## The stock fit: two dark track boxes with silver hub caps. Unchanged from the
	## body's original treads — it moved here so every fit lives in one file.
	var dark := _dark()
	var silver := _silver()
	for side in [-1.0, 1.0]:
		_box(Vector3(0.16, 0.3, 0.62), Vector3(side * 0.32, 0.22, 0), dark)
		for zz in [-0.2, 0.0, 0.2]:
			_disc(0.05, 0.02, Vector3(side * 0.41, 0.22, zz), silver)


func _build_tread_triangle() -> void:
	## A track running around a triangular frame — flat on the ground, apex up — so
	## the silhouette reads as a delta rather than a box. Three wheels with the belt
	## laid on the *outside* of them, which is what makes the triangle legible: put
	## the belt through the wheel centres and the whole unit reads as a blob. The
	## bottom wheels are set so the belt's outer face sits exactly on the ground.
	const R := 0.06                       # small rollers…
	const WIDTH := 0.19                   # …inside a wide belt, which is what makes
	const BELT := 0.07                    # the triangle the thing you see, not the wheels
	const OFFSET := R + BELT * 0.5
	const YB := OFFSET + BELT * 0.5       # bottom wheel height, belt bottom on y=0
	var belt_mat := _dark()
	var wheel_mat := _mat(Color(0.35, 0.37, 0.40), 0.45, 0.5)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.32
		var front := Vector3(x, YB, -0.24)
		var back := Vector3(x, YB, 0.24)
		var top := Vector3(x, 0.42, 0.0)
		_belt(front, back, top, OFFSET, WIDTH, BELT, belt_mat)
		_belt(back, top, front, OFFSET, WIDTH, BELT, belt_mat)
		_belt(top, front, back, OFFSET, WIDTH, BELT, belt_mat)
		for centre in [front, back, top]:
			_disc(R, WIDTH - 0.04, centre, wheel_mat)
			# Hub cap proud of the outer face, so the wheels read as wheels.
			_disc(0.035, 0.02, centre + Vector3(side * (WIDTH * 0.5 - 0.01), 0.0, 0.0),
					_silver(), 10)


func _belt(a: Vector3, b: Vector3, apex: Vector3, offset: float, width: float,
		thickness: float, mat: StandardMaterial3D) -> void:
	## One segment of the track, pushed out along the side of the triangle that faces
	## away from the third wheel so the belt wraps the frame instead of cutting
	## through it. Each segment is overrun by half its thickness at both ends, so the
	## three of them meet in a clean corner instead of leaving notches.
	var mid := (a + b) * 0.5
	var d := b - a
	var n := Vector3(0.0, -d.z, d.y).normalized()
	if mid.distance_to(apex) < (mid + n).distance_to(apex):
		n = -n
	var u := d.normalized() * thickness * 0.5
	_bar(a + n * offset - u, b + n * offset + u, width, thickness, mat)


func _build_legs_three() -> void:
	## R2-D2's stance: a shoulder and a raked strut either side, plus the **third,
	## centre leg** R2 drops at the front — the detail that makes "three legs" mean
	## three rather than two.
	var white := _white()
	var blue := _blue()
	var dark := _dark()
	for side in [-1.0, 1.0]:
		var x: float = side * 0.30
		_box(Vector3(0.12, 0.24, 0.16), Vector3(x, 0.42, 0.0), white)
		_box(Vector3(0.13, 0.05, 0.17), Vector3(x, 0.29, 0.0), blue)
		_box(Vector3(0.13, 0.28, 0.17), Vector3(side * 0.33, 0.18, 0.02), white)
		_disc(0.055, 0.17, Vector3(side * 0.33, 0.05, 0.02), dark, 10)
		_box(Vector3(0.17, 0.05, 0.36), Vector3(side * 0.33, 0.025, -0.02), dark)
	# The centre leg, forward of the other two (the drone faces -Z).
	_box(Vector3(0.11, 0.30, 0.13), Vector3(0.0, 0.24, -0.08), white)
	_box(Vector3(0.12, 0.04, 0.14), Vector3(0.0, 0.31, -0.08), blue)
	_box(Vector3(0.15, 0.045, 0.20), Vector3(0.0, 0.022, -0.10), dark)


func _build_legs_telescope() -> void:
	## Two legs of nested tubes: each stage is thinner than the one above it and steps
	## out and down, with a bright collar at every joint. The collars are the point —
	## without them the stages merge into one grey stick and the leg stops reading as
	## a telescope at all.
	var white := _white()
	var silver := _silver()
	var dark := _dark()
	# Thinner and lower at each step: radius, centre height, length, colour.
	var stages := [
		[0.075, 0.325, 0.13, silver],
		[0.058, 0.215, 0.12, dark],
		[0.042, 0.115, 0.11, silver],
	]
	for side in [-1.0, 1.0]:
		_tube(0.09, 0.05, Vector3(side * 0.30, 0.40, 0.0), white)
		var x: float = 0.30
		for stage in stages:
			var radius: float = stage[0]
			var y: float = stage[1]
			var length: float = stage[2]
			x += 0.016
			_tube(radius, length, Vector3(side * x, y, 0.0), stage[3])
			# The joint collar, proud of both stages it joins.
			_tube(radius + 0.014, 0.022, Vector3(side * x, y - length * 0.5, 0.0), silver)
		_tube(0.10, 0.05, Vector3(side * x, 0.026, 0.0), dark)