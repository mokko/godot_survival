extends Node3D
## Equipment visuals: builds a drone body (treads, core, dome head) and shows/
## hides weapon + armor props as the player equips things. Attached to the
## player; props are plain meshes parented at fixed offsets — no animation.

const ItemDB := preload("res://items/item_db.gd")

var _props := {}         # item id -> Node3D
var _flourish := 0.0     # counts down while the equip flourish plays
var _eye: MeshInstance3D = null
var _sword_pivot: Node3D = null
var _trail: MeshInstance3D = null
var _arm_pivots: Array[Node3D] = []   # left, right — shoulder joints
var _arm_time := 0.0                  # seconds, drives the arm gait


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
		_arm_pivots[i].rotation.x = idle + lift + mirror * swing


const FLOURISH_TIME := 0.6


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

	# Treads (WALL-E): two dark track boxes left and right.
	for side in [-1.0, 1.0]:
		var tread := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.16, 0.3, 0.62)
		tread.mesh = tm
		tread.position = Vector3(side * 0.32, 0.22, 0)
		tread.material_override = dark
		add_child(tread)
		# Hub caps (R2-style silver circles on the tread sides).
		for zz in [-0.2, 0.0, 0.2]:
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.05
			hm.bottom_radius = 0.05
			hm.height = 0.02
			hub.mesh = hm
			hub.position = Vector3(side * 0.41, 0.22, zz)
			hub.rotation.z = PI / 2
			var hub_mat := StandardMaterial3D.new()
			hub_mat.albedo_color = Color(0.75, 0.77, 0.8)
			hub_mat.metallic = 0.8
			hub_mat.roughness = 0.25
			hub.material_override = hub_mat
			add_child(hub)

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


## ---- props ---------------------------------------------------------------

func _build_props() -> void:
	_props["sword"] = _make_katana()
	_props["bow"] = _make_bow()
	_props["dagger"] = _make_dagger()
	_props["leather_armor"] = _make_armor_plates()
	for id in _props:
		_props[id].visible = false
	_build_trail()


func _build_trail() -> void:
	## Translucent arc shown mid-swing, centered on the drone, facing -Z.
	_trail = MeshInstance3D.new()
	var arc := CylinderMesh.new()
	arc.top_radius = 2.0
	arc.bottom_radius = 2.0
	arc.height = 0.05
	arc.radial_segments = 12
	# Half-open cylinder would be nicer; a thin ring slice reads fine:
	_trail.mesh = arc
	_trail.position = Vector3(0, 1.0, -0.6)
	_trail.rotation.x = PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail.material_override = mat
	add_child(_trail)
	_trail.visible = false


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
	## Weapon props: visible when equipped (katana on hip, bow at side).
	for id in ["sword", "bow", "dagger"]:
		if _props.has(id):
			_props[id].visible = (id == item_id)


func show_armor(worn: bool) -> void:
	if _props.has("leather_armor"):
		_props["leather_armor"].visible = worn


func get_sword_pivot() -> Node3D:
	return _sword_pivot


func get_trail() -> MeshInstance3D:
	return _trail
