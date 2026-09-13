extends Node3D
## Equipment visuals: builds a drone body (core + rotor arms) and shows/
## hides weapon + armor props as the player equips things. Attached to the
## player; props are plain meshes parented at fixed offsets — no animation.

const ItemDB := preload("res://items/item_db.gd")

var _rotors: Array = []
var _spin := 0.0
var _props := {}         # item id -> Node3D
var _flourish := 0.0     # counts down while the equip flourish plays
var _eye: MeshInstance3D = null
var _sword_pivot: Node3D = null
var _trail: MeshInstance3D = null


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


func refresh_visuals(equipped_item_id: String) -> void:
	## Public wrapper: re-show props for the given equipped item id.
	show_for_equipped(equipped_item_id)
