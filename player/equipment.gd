extends Node3D
## Equipment visuals: builds a drone body (core + rotor arms) and shows/
## hides weapon + armor props as the player equips things. Attached to the
## player; props are plain meshes parented at fixed offsets — no animation.

const ItemDB := preload("res://items/item_db.gd")

var _rotors: Array = []
var _spin := 0.0
var _props := {}         # item id -> Node3D


func _ready() -> void:
	_build_drone_body()
	_build_props()


func _process(delta: float) -> void:
	_spin += delta * 12.0
	for r in _rotors:
		r.rotation.y = _spin


## ---- body ---------------------------------------------------------------

func _build_drone_body() -> void:
	# Core: rounded box body, replaces the old capsule look.
	var core := MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.55, 0.28, 0.55)
	core.mesh = core_mesh
	core.position.y = 1.0
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.75, 0.78, 0.82)
	core_mat.metallic = 0.6
	core_mat.roughness = 0.35
	core.material_override = core_mat
	add_child(core)

	# Sensor eye: small emissive sphere at the front.
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.08
	eye_mesh.height = 0.16
	eye.mesh = eye_mesh
	eye.position = Vector3(0, 1.05, -0.3)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.2, 0.9, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.2, 0.9, 1.0)
	eye.material_override = eye_mat
	add_child(eye)

	# Four rotor arms.
	for i in 4:
		var arm_dir := Vector3(cos(TAU * i / 4.0 + PI / 4), 0, sin(TAU * i / 4.0 + PI / 4))
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.45, 0.05, 0.05)
		arm.mesh = arm_mesh
		arm.position = arm_dir * 0.28 + Vector3(0, 1.12, 0)
		arm.rotation.y = atan2(arm_dir.z, arm_dir.x)
		arm.material_override = core_mat
		add_child(arm)

		var rotor := MeshInstance3D.new()
		var rotor_mesh := BoxMesh.new()
		rotor_mesh.size = Vector3(0.38, 0.012, 0.04)
		rotor.mesh = rotor_mesh
		rotor.position = arm_dir * 0.5 + Vector3(0, 1.16, 0)
		var rotor_mat := StandardMaterial3D.new()
		rotor_mat.albedo_color = Color(0.3, 0.32, 0.36)
		rotor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rotor_mat.albedo_color.a = 0.55
		rotor.material_override = rotor_mat
		add_child(rotor)
		_rotors.append(rotor)


## ---- props ---------------------------------------------------------------

func _build_props() -> void:
	_props["sword"] = _make_katana()
	_props["bow"] = _make_bow()
	_props["dagger"] = _make_dagger()
	_props["leather_armor"] = _make_armor_plates()
	for id in _props:
		_props[id].visible = false


func _make_katana() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.35, 0.95, 0.1)   # right side, blade down-back
	root.rotation.z = 0.5
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
	root.position = Vector3(-0.32, 0.95, 0.12)   # slung on the back-left
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
	root.position = Vector3(-0.35, 0.85, 0.05)   # left hip
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
	for cfg in [[Vector3(0, 1.05, -0.3), Vector3(0.45, 0.4, 0.04)],
			[Vector3(-0.3, 1.0, 0), Vector3(0.04, 0.35, 0.4)],
			[Vector3(0.3, 1.0, 0), Vector3(0.04, 0.35, 0.4)]]:
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
