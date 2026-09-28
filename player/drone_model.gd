extends Node3D
## The drone itself: the three families — legs, torso, head — plus the arms.
##
## **This is the one builder.** `player/equipment.gd` (the machine the player steers) and
## `ui/editor.gd` (the picture in the Robo Editor) each instantiate one of these, so the drone on
## the bench cannot drift from the drone on the beach: the same three scripts build it in both
## places, from the same three ids, and a part added to a family appears in the picture the moment
## it appears on the player.
##
## The machine's own space, which every family keeps: the origin is on the ground, the drone faces
## **-Z** (its eye, chest lens, arms and claws are all on that side), and it stands about 1.25 m
## tall. A picture of it therefore has to be taken from **-Z** to show its face.
##
## The arms are the one part of the body with no catalogue: they are the same on every fit, so they
## are built here rather than in a family. `player/equipment.gd` animates them by asking for their
## pivots (`arm_pivots()`); this node only builds them.

const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")

## Where the arms hang from: just above the blue chest band, outside the body's half-width. The
## same shoulder for every fit — see `player/equipment.gd::set_torso()` for why the arms do not
## move with the torso (yet).
const ARM_SHOULDER_Y := 0.72
const ARM_SHOULDER_X := 0.36

var _legs: Node3D = null
var _torso: Node3D = null
var _head: Node3D = null
var _arm_pivots: Array[Node3D] = []


func _ready() -> void:
	if get_child_count() == 0:
		build()


func build(legs_id := Legs.STOCK, torso_id := Torsos.STOCK, head_id := Heads.STOCK) -> void:
	## Assemble the machine, part by part. Each id is set **before** its node enters the tree, so
	## the family's own `_ready` does not build a second copy on top of the one asked for.
	_legs = _add_family(Legs, "Legs", legs_id)
	_torso = _add_family(Torsos, "Torso", torso_id)
	_head = _add_family(Heads, "Head", head_id)
	_build_arms()


func set_part(kind: String, part_id: String) -> bool:
	## Swap one family's part. False for an unknown kind or an id that family does not know, so a
	## caller cannot fit a part by guessing. The head is not special here: `eye()` re-reads the
	## lens every time it is asked, so a swap cannot leave the caller holding the old one.
	var node := _node_of(kind)
	if node == null:
		return false
	return node.set_part(part_id)


func fitted(kind: String) -> String:
	## Which part of that kind is on the machine right now; "" for an unknown kind.
	var node := _node_of(kind)
	if node == null:
		return ""
	return str(node.part())


func name_of(kind: String, part_id: String) -> String:
	## What to call a part — the family's own name for it, so no caller keeps a second table.
	var catalogue: GDScript = _catalogue(kind)
	if catalogue == null:
		return part_id
	return str(catalogue.NAMES.get(part_id, part_id))


func eye() -> MeshInstance3D:
	## The emissive lens the hurt flash dims. Every head builds one named `Eye`
	## (`player/heads.gd`'s contract), and this is the only way to reach it, so a swapped head can
	## never be paired with the lens that left with the old one.
	if _head == null:
		return null
	return _head.get_node_or_null("Eye") as MeshInstance3D


func arm_pivots() -> Array[Node3D]:
	## Left and right shoulder joints, in that order, for whoever animates the gait.
	return _arm_pivots


func _node_of(kind: String) -> Node3D:
	match kind:
		"legs":
			return _legs
		"torso":
			return _torso
		"head":
			return _head
	return null


func _catalogue(kind: String) -> GDScript:
	match kind:
		"legs":
			return Legs
		"torso":
			return Torsos
		"head":
			return Heads
	return null


func _add_family(catalogue: GDScript, node_name: String, part_id: String) -> Node3D:
	var node: Node3D = catalogue.new()
	node.name = node_name
	node.set_part(part_id)
	add_child(node)
	return node


## ---- arms ---------------------------------------------------------------
## Two thin arms off the body sides: ball shoulder, upper arm, blue cuff,
## forearm and a two-finger claw. Each arm hangs from its own pivot Node3D so
## the player can swing it as a unit.

func _build_arms() -> void:
	var white := _mat(Color(0.88, 0.9, 0.92), 0.3, 0.45)
	var blue := _mat(Color(0.16, 0.32, 0.62), 0.4, 0.4)
	var dark := _mat(Color(0.12, 0.13, 0.15), 0.5, 0.6)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0.0 else "ArmR"
		pivot.position = Vector3(side * ARM_SHOULDER_X, ARM_SHOULDER_Y, 0.0)
		pivot.rotation.z = side * 0.10     # splay the arms slightly outward
		add_child(pivot)
		_arm_pivots.append(pivot)

		# Shoulder ball.
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.07
		bm.height = 0.14
		ball.mesh = bm
		ball.material_override = dark
		pivot.add_child(ball)

		# Upper arm.
		var upper := MeshInstance3D.new()
		var um := BoxMesh.new()
		um.size = Vector3(0.09, 0.26, 0.10)
		upper.mesh = um
		upper.position.y = -0.15
		upper.material_override = white
		pivot.add_child(upper)

		# Elbow joint.
		var elbow := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.045
		em.bottom_radius = 0.045
		em.height = 0.11
		elbow.mesh = em
		elbow.position.y = -0.29
		elbow.rotation.z = PI / 2           # axle across the arm
		elbow.material_override = dark
		pivot.add_child(elbow)

		# Blue cuff, then the forearm below it.
		var cuff := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.105, 0.06, 0.115)
		cuff.mesh = cm
		cuff.position.y = -0.34
		cuff.material_override = blue
		pivot.add_child(cuff)

		var fore := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.075, 0.20, 0.085)
		fore.mesh = fm
		fore.position.y = -0.46
		fore.material_override = white
		pivot.add_child(fore)

		# Two-finger claw: small dark paddles angled open.
		for finger in [-1.0, 1.0]:
			var claw := MeshInstance3D.new()
			var km := BoxMesh.new()
			km.size = Vector3(0.025, 0.10, 0.03)
			claw.mesh = km
			claw.position = Vector3(finger * 0.04, -0.60, 0.0)
			claw.rotation.z = finger * 0.28
			claw.material_override = dark
			pivot.add_child(claw)


func _mat(colour: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = metallic
	m.roughness = roughness
	return m
