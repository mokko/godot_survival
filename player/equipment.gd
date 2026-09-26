extends Node3D
## Equipment visuals: builds a drone body (legs, core, dome head) and shows/
## hides weapon + armor props as the player equips things. Attached to the
## player; props are plain meshes parented at fixed offsets — no animation.
##
## What the drone stands on is a child `Legs` node (`player/legs.gd`), not meshes
## built here: the fit is swappable, and that node is the only thing allowed to
## parent leg meshes onto the body. The stock fit is the twin treads, so a fresh run
## is unchanged.

const ItemDB := preload("res://items/item_db.gd")
const Legs := preload("res://player/legs.gd")

var _legs: Node3D = null

var _props := {}         # item id -> Node3D
var _flourish := 0.0     # counts down while the equip flourish plays
var _eye: MeshInstance3D = null
var _sword_pivot: Node3D = null
var _trail: MeshInstance3D = null
var _arm_pivots: Array[Node3D] = []   # left, right — shoulder joints
var _arm_time := 0.0                  # seconds, drives the arm gait
var _punch := 0.0                     # counts down while a jab plays


func _ready() -> void:
	_build_drone_body()
	_build_props()


func _process(delta: float) -> void:
	# Whole-body bob: quick hop while the flourish plays.
	if _flourish > 0.0:
		_flourish = maxf(_flourish - delta, 0.0)
		var t := 1.0 - _flourish / FLOURISH_TIME   # 0..1
		position.y = 0.35 * sin(t * PI)            # up and back down
		# Eye flashes brighter during the flourish.
		if _eye != null and _eye.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = _eye.material_override
			m.emission_energy_multiplier = 1.0 + 2.0 * sin(t * PI)
	else:
		position.y = 0.0
	_animate_arms(delta)


func _animate_arms(delta: float) -> void:
	## Arm life: opposite-phase swing while rolling, a slow idle sway, and a
	## two-armed raise during the equip flourish. Pivot rotation.x is the only
	## axis touched — positive tips the hanging arm forward (the drone faces -Z).
	if _arm_pivots.is_empty():
		return
	_arm_time += delta
	_punch = maxf(_punch - delta, 0.0)
	var speed := 0.0
	var body := get_parent() as CharacterBody3D
	if body != null:
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	# Gait: swing amplitude scales with ground speed, so a parked drone
	# doesn't march in place.
	var gait := clampf(speed / 4.0, 0.0, 1.0)
	var swing := 0.45 * gait * sin(_arm_time * 6.0)
	var idle := 0.05 * sin(_arm_time * 1.5)
	var lift := 0.0
	if _flourish > 0.0:
		lift = 1.1 * sin((1.0 - _flourish / FLOURISH_TIME) * PI)
	for i in _arm_pivots.size():
		var mirror := 1.0 if i == 0 else -1.0
		# Unarmed jab: the right arm (appended second) drives forward and snaps
		# back; the left counter-rotates slightly so it reads as a body action,
		# not a floating limb.
		var jab := 0.0
		var counter := 0.0
		if _punch > 0.0:
			var punch_t := sin((1.0 - _punch / PUNCH_TIME) * PI)
			if i == 1:
				jab = JAB_ANGLE * punch_t
			else:
				counter = -0.25 * JAB_ANGLE * punch_t
		_arm_pivots[i].rotation.x = idle + lift + mirror * swing + jab + counter


const FLOURISH_TIME := 0.6
const PUNCH_TIME := 0.34        # full jab: extend and snap back
const JAB_ANGLE := 1.5          # radians; +x tips the hanging arm forward


func play_punch() -> void:
	## Unarmed attack flourish: a quick one-two with the right arm.
	_punch = PUNCH_TIME


func play_flourish() -> void:
	## Brief rotor burst + bob: "look at my drone" moment on equip changes.
	_flourish = FLOURISH_TIME


## ---- body ---------------------------------------------------------------
## Design: smallish droid between R2-D2 and WALL-E.
## - Wall-E side: boxy main body, twin tank treads, telescopic neck
## - R2 side: white/blue dome head with panel rings, silver accents

func _build_drone_body() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.88, 0.9, 0.92)
	white.roughness = 0.45
	white.metallic = 0.3
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.16, 0.32, 0.62)
	blue.roughness = 0.4
	blue.metallic = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.15)
	dark.roughness = 0.6
	dark.metallic = 0.5

	# Legs (the fit lives in player/legs.gd, including this stock one). Part set
	# before it enters the tree, so its own _ready does not build a second fit.
	_legs = Legs.new()
	_legs.name = "Legs"
	_legs.set_part(Legs.STOCK)
	add_child(_legs)

	# Body (WALL-E box + R2 white barrel): rounded box in white with a blue
	# panel band across the chest.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.56, 0.5, 0.44)
	body.mesh = bm
	body.position.y = 0.62
	body.material_override = white
	add_child(body)

	var band := MeshInstance3D.new()
	var bandm := BoxMesh.new()
	bandm.size = Vector3(0.58, 0.14, 0.46)
	band.mesh = bandm
	band.position.y = 0.68
	band.material_override = blue
	add_child(band)

	# Chest "life display": small emissive blue lens on the front.
	var lens := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.055
	lm.height = 0.11
	lens.mesh = lm
	lens.position = Vector3(0.0, 0.62, -0.25)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.25, 0.7, 1.0)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.25, 0.7, 1.0)
	lens.material_override = lens_mat
	add_child(lens)

	# Neck (WALL-E telescopic): short dark cylinder between body and head.
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.06
	nm.bottom_radius = 0.06
	nm.height = 0.16
	neck.mesh = nm
	neck.position.y = 0.95
	neck.material_override = dark
	add_child(neck)

	# Dome head (R2): half-sphere in white, blue panel stripe.
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.22
	dm.height = 0.44
	dome.mesh = dm
	dome.position.y = 1.08
	dome.material_override = white
	add_child(dome)

	var stripe := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.19
	sm.outer_radius = 0.225
	stripe.mesh = sm
	stripe.position.y = 1.06
	stripe.material_override = blue
	add_child(stripe)

	# Eye: single emissive lens on the front of the dome (the "face").
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.06
	em.height = 0.12
	eye.mesh = em
	eye.position = Vector3(0, 1.1, -0.2)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.2, 0.9, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.2, 0.9, 1.0)
	eye.material_override = eye_mat
	add_child(eye)
	_eye = eye

	_build_arms(white, blue, dark)


## ---- arms ---------------------------------------------------------------
## Two thin arms off the body sides: ball shoulder, upper arm, blue cuff,
## forearm and a two-finger claw. Each arm hangs from its own pivot Node3D so
## _animate_arms can swing it as a unit.

const ARM_SHOULDER_Y := 0.72   # just above the blue chest band
const ARM_SHOULDER_X := 0.36   # outside the body half-width (0.28)

func _build_arms(white: StandardMaterial3D, blue: StandardMaterial3D,
		dark: StandardMaterial3D) -> void:
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


const TRAIL_RADIUS := 1.25
const TRAIL_HALF_ANGLE := 0.96   ## radians either side of forward (~55 deg)
const TRAIL_WIDTH := 0.32        ## ribbon width at the middle of the arc
const TRAIL_SEGMENTS := 14


## ---- props ---------------------------------------------------------------

func _build_props() -> void:
	_props["sword"] = _make_katana()
	_props["bow"] = _make_bow()
	_props["dagger"] = _make_dagger()
	_props["binoculars"] = _make_binoculars()
	_props["magnifying_glass"] = _make_magnifier()
	_props["leather_armor"] = _make_armor_plates()
	for id in _props:
		_props[id].visible = false
	_build_trail()


func _build_trail() -> void:
	## Crescent blade trail: an arc ribbon in front of the drone, swept in yaw
	## by player/slash.gd. It replaced a full 4 m disc that sat in the air and
	## read as a hit indicator rather than as a swing.
	_trail = MeshInstance3D.new()
	_trail.mesh = _make_crescent_mesh()
	_trail.position = Vector3(0, 1.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A flat ribbon seen edge-on would vanish with backface culling.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = mat
	add_child(_trail)
	_trail.visible = false


func _make_crescent_mesh() -> ArrayMesh:
	## Arc ribbon: TRAIL_SEGMENTS quads spanning TRAIL_HALF_ANGLE either side of
	## straight ahead, tapered so the blade is thin at both tips. Built as an
	## ArrayMesh rather than a primitive because Godot's torus/cylinder meshes
	## are always full rings.
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in TRAIL_SEGMENTS + 1:
		var t := float(i) / float(TRAIL_SEGMENTS)
		var ang: float = lerpf(-TRAIL_HALF_ANGLE, TRAIL_HALF_ANGLE, t)
		# Thin at the tips, widest through the middle of the sweep.
		var w: float = TRAIL_WIDTH * (0.2 + 0.8 * sin(t * PI))
		var dir := Vector3(sin(ang), 0.0, -cos(ang))   # 0 rad = straight ahead
		verts.append(dir * (TRAIL_RADIUS - w * 0.5))
		verts.append(dir * (TRAIL_RADIUS + w * 0.5))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
	for i in TRAIL_SEGMENTS:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_katana() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.38, 0.7, 0.1)   # right side, blade down-back
	root.rotation.z = 0.5
	_sword_pivot = root
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.75, 0.008)
	blade.mesh = bm
	blade.position.y = -0.45
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.87, 0.92)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.15
	blade.material_override = blade_mat
	root.add_child(blade)
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.035, 0.16, 0.035)
	grip.mesh = gm
	grip.position.y = 0.05
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.1, 0.1, 0.12)
	grip.material_override = grip_mat
	root.add_child(grip)
	add_child(root)
	return root


func _make_bow() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(-0.34, 0.72, 0.12)   # slung on the back-left
	root.rotation.z = -0.6
	# Limb: thin curved arc approximated by 3 angled segments.
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.3, 0.14)
	for i in 3:
		var seg := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.025, 0.22, 0.02)
		seg.mesh = sm
		seg.position.y = 0.2 - i * 0.2
		seg.rotation.z = (1 - i) * 0.4
		seg.material_override = wood_mat
		root.add_child(seg)
	var string := MeshInstance3D.new()
	var sm2 := BoxMesh.new()
	sm2.size = Vector3(0.004, 0.62, 0.004)
	string.mesh = sm2
	string.position.x = -0.06
	var str_mat := StandardMaterial3D.new()
	str_mat.albedo_color = Color(0.9, 0.9, 0.9)
	str_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	str_mat.albedo_color.a = 0.7
	string.material_override = str_mat
	root.add_child(string)
	add_child(root)
	return root


func _make_dagger() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(-0.36, 0.6, 0.05)   # left hip
	root.rotation.z = 0.9
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.3, 0.008)
	blade.mesh = bm
	blade.position.y = -0.2
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.85, 0.87, 0.92)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.15
	blade.material_override = blade_mat
	root.add_child(blade)
	add_child(root)
	return root


func _make_binoculars() -> Node3D:
	## Two barrels raised at the eye, lenses forward: what the drone looks through
	## while it fills the notebook (player/study.gd). Held high so the equip
	## flourish reads as lifting them into place.
	var root := Node3D.new()
	root.position = Vector3(0.26, 1.0, -0.16)
	root.rotation.x = -0.12
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.22, 0.24, 0.28)
	body_mat.roughness = 0.5
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.4, 0.62, 0.8)
	glass_mat.metallic = 0.6
	glass_mat.roughness = 0.1
	for side in [-1, 1]:
		var barrel := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.2)
		barrel.mesh = bm
		barrel.position = Vector3(0.05 * side, 0, 0)
		barrel.material_override = body_mat
		root.add_child(barrel)
		var lens := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.035
		lm.bottom_radius = 0.035
		lm.height = 0.02
		lens.mesh = lm
		lens.rotation.x = PI * 0.5   # face forward
		lens.position = Vector3(0.05 * side, 0, -0.11)
		lens.material_override = glass_mat
		root.add_child(lens)
	var bridge := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.05, 0.03, 0.12)
	bridge.mesh = gm
	bridge.position = Vector3(0, 0, 0.02)
	bridge.material_override = body_mat
	root.add_child(bridge)
	add_child(root)
	return root


func _make_magnifier() -> Node3D:
	## A loupe held up in front of the lens: a dark rim, a glass disc, a short
	## handle angled back. The tool the notebook's plants are drawn with
	## (player/study.gd).
	var root := Node3D.new()
	root.position = Vector3(0.26, 0.98, -0.22)
	root.rotation.x = -0.1
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.22, 0.24, 0.28)
	rim_mat.roughness = 0.5
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.62, 0.78, 0.88, 0.55)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.metallic = 0.4
	glass_mat.roughness = 0.05
	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.1
	rm.bottom_radius = 0.1
	rm.height = 0.016
	rim.mesh = rm
	rim.rotation.x = PI * 0.5   # the lens faces forward
	rim.material_override = rim_mat
	root.add_child(rim)
	var glass := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.088
	gm.bottom_radius = 0.088
	gm.height = 0.006
	glass.mesh = gm
	glass.rotation.x = PI * 0.5
	glass.position.z = -0.008
	glass.material_override = glass_mat
	root.add_child(glass)
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.014
	hm.height = 0.16
	handle.mesh = hm
	handle.position = Vector3(0.0, -0.09, 0.07)
	handle.rotation.x = 0.5
	handle.material_override = rim_mat
	root.add_child(handle)
	add_child(root)
	return root


func _make_armor_plates() -> Node3D:
	var root := Node3D.new()
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.5, 0.36, 0.22)
	plate_mat.roughness = 0.8
	# Chest plate + two side plates hugging the drone core.
	for cfg in [[Vector3(0, 0.68, -0.26), Vector3(0.5, 0.44, 0.04)],
			[Vector3(-0.3, 0.62, 0), Vector3(0.04, 0.4, 0.48)],
			[Vector3(0.3, 0.62, 0), Vector3(0.04, 0.4, 0.48)]]:
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = cfg[1]
		plate.mesh = pm
		plate.position = cfg[0]
		plate.material_override = plate_mat
		root.add_child(plate)
	add_child(root)
	return root


## ---- wiring ---------------------------------------------------------------

func show_for_equipped(item_id: String) -> void:
	## Held props: visible when equipped (katana on hip, bow at side, binoculars and
	## the loupe raised at the eye).
	for id in ["sword", "bow", "dagger", "binoculars", "magnifying_glass"]:
		if _props.has(id):
			_props[id].visible = (id == item_id)


func show_armor(worn: bool) -> void:
	if _props.has("leather_armor"):
		_props["leather_armor"].visible = worn


func set_legs(part_id: String) -> bool:
	## The one way to change what the drone stands on — the Frame screen calls this
	## (`player/legs.gd` holds the catalogue and builds the geometry). False when the
	## id is not a fit we know.
	if _legs == null:
		return false
	return _legs.set_part(part_id)


func fitted_legs() -> String:
	## Which fit is on the drone, for saving and for anything showing it.
	if _legs == null:
		return ""
	return _legs.part()


func get_sword_pivot() -> Node3D:
	return _sword_pivot


func get_trail() -> MeshInstance3D:
	return _trail
