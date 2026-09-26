extends StaticBody3D
## A service bench — where the drone is re-fitted, and the only way into the
## Frame screen (ui/editor.gd).
##
## One is hidden on every island, and **nothing records where**: no HUD marker, no
## Pedia entry, no save flag. Finding it is the player's job and remembering it is
## the player's memory (README, Decisions: "No minimap — the world is the map").
## That is the whole of "found", so placement is the only thing that makes a bench
## a discovery — see tools/build_benches.gd for where each one sits.
##
## Pressing E beside it opens the editor *through the pause menu*
## (`PauseMenu.open_editor`), which is what keeps one owner for ESC. The bench
## never handles that key itself.
##
## The whole bench is one merged, vertex-coloured mesh (world/prop_mesh.gd) plus a
## lit lamp, for the same draw-call reason as the boat.

## Set per placed instance by tools/build_benches.gd.
@export var island: String = ""

const USE_RADIUS := 4.0        ## metres from the bench the player can press E in

const STEEL := Color(0.34, 0.37, 0.39)
const PANEL := Color(0.42, 0.44, 0.45)
const IRON := Color(0.24, 0.25, 0.27)
const BRASS := Color(0.72, 0.55, 0.24)
const LAMP := Color(1.0, 0.78, 0.44)

const PropMesh := preload("res://world/prop_mesh.gd")

## The bench's own idle prompt, parented to the HUD (built in code, like the boat's).
var _hint: Label = null
var _hint_timer := 0.0


func _ready() -> void:
	add_to_group("bench")     # tests and anything else find benches through this
	_build_visuals()
	_build_collision()
	_hint = _make_hint_label()


func use_radius() -> float:
	## How close the player has to be to service the frame here.
	return USE_RADIUS


func frame_menu() -> Node:
	## The pause menu, which owns the Frame screen and the ESC key.
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("HUD/PauseMenu")


func can_be_used_by(player: Node3D) -> bool:
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= USE_RADIUS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# The boat's contract, kept: while the UI has the mouse, E belongs to the UI.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var player := get_tree().get_first_node_in_group("player")
	if use_for_test(player):
		# One press, one thing: stop the same E event reaching whoever else listens.
		get_viewport().set_input_as_handled()


func use_for_test(player: Node3D) -> bool:
	## Test seam: the same path E takes once its guards have passed, without
	## synthesising input events — headless cannot capture the mouse, so the E path
	## itself is unreachable from a test (the boat carries the same seam). True when
	## the frame screen opened.
	if not can_be_used_by(player):
		return false
	var menu := frame_menu()
	if menu == null or not menu.has_method("open_editor"):
		return false
	menu.open_editor(self)
	return true


func _physics_process(delta: float) -> void:
	_tick_hint(delta)


# ------------------------------------------------------------------- visuals

func _build_visuals() -> void:
	## A bench you could actually work at: a slab on two end panels, a brace, a
	## backboard with a few tools hung on it, a vice on the near edge. Merged to one
	## surface with per-part vertex colours.
	##
	## **The working face is +Z** (slab, vice, hung tools) — tools/build_benches.gd
	## yaws each placed instance so that face looks at the shore the player walks up
	## from. Keep new parts on that side of the prop.
	var top := BoxMesh.new()
	top.size = Vector3(1.8, 0.12, 0.8)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.12, 0.9, 0.7)
	var brace := BoxMesh.new()
	brace.size = Vector3(1.6, 0.1, 0.1)
	var back := BoxMesh.new()
	back.size = Vector3(1.8, 0.7, 0.08)
	var vice := BoxMesh.new()
	vice.size = Vector3(0.26, 0.18, 0.22)
	var screw := CylinderMesh.new()
	screw.top_radius = 0.04
	screw.bottom_radius = 0.04
	screw.height = 0.3
	screw.radial_segments = 6
	screw.rings = 1
	var peg := BoxMesh.new()
	peg.size = Vector3(0.06, 0.3, 0.06)
	var parts := [
		[top, Transform3D(Basis(), Vector3(0, 0.95, 0)), STEEL],
		[leg, Transform3D(Basis(), Vector3(-0.8, 0.45, 0)), PANEL],
		[leg, Transform3D(Basis(), Vector3(0.8, 0.45, 0)), PANEL],
		[brace, Transform3D(Basis(), Vector3(0, 0.35, 0)), IRON],
		[back, Transform3D(Basis(), Vector3(0, 1.36, -0.36)), PANEL],
		[vice, Transform3D(Basis(), Vector3(-0.58, 1.1, 0.2)), IRON],
		[screw, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.58, 1.1, 0.36)), BRASS],
		# Tools hung on the backboard: two pegs and a spanner-ish bar.
		[peg, Transform3D(Basis(), Vector3(0.35, 1.34, -0.3)), BRASS],
		[peg, Transform3D(Basis(), Vector3(0.52, 1.34, -0.3)), BRASS],
		[screw, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 1.34, -0.3)), IRON],
	]
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = PropMesh.merge(parts)
	body.material_override = PropMesh.paint()
	add_child(body)

	# A lamp over the bench, so it is findable after dark. Deliberately NOT in the
	# "glow_plants" group: that group's contract is authored emission the day cycle
	# scales, and it is queried by index in tests. This is simply lit.
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var cage := BoxMesh.new()
	cage.size = Vector3(0.22, 0.12, 0.22)
	lamp.mesh = cage
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = LAMP
	lamp_mat.emission_enabled = true
	lamp_mat.emission = LAMP
	lamp_mat.emission_energy_multiplier = 2.2
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0, 1.86, -0.3)
	add_child(lamp)


func _build_collision() -> void:
	## Solid, so the bench cannot be walked through — and tall enough to include the
	## backboard, so the player cannot stand inside it while working.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.0, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)


# --------------------------------------------------------------------- hints

func _make_hint_label() -> Label:
	## The boat's pattern: a label built in code and parented to the HUD, because a
	## 3D node has no business drawing text of its own.
	var scene := get_tree().current_scene
	var hud: CanvasLayer = scene.get_node_or_null("HUD") if scene != null else null
	if hud == null:
		return null
	var label := Label.new()
	label.name = "BenchHint"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-190, -70)
	label.custom_minimum_size = Vector2(380, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.visible = false
	hud.add_child(label)
	return label


func _say(text: String, seconds := 4.0) -> void:
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = true
	_hint_timer = seconds


func _tick_hint(delta: float) -> void:
	if _hint == null:
		return
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint.visible = false
		return
	# Idle prompt, so the player knows a bench can be used at all.
	var player := get_tree().get_first_node_in_group("player")
	if player == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_hint.visible = false
		return
	if can_be_used_by(player):
		_hint.text = "E — service the frame"
		_hint.visible = true
	else:
		_hint.visible = false