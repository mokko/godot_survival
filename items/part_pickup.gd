extends Area3D
## A robot part lying in the world: walk into it and it goes **straight onto the drone's
## own list** (`player/robot_parts.gd`), never into the inventory — see that file for why.
## The part id is set by whatever places it (`tools/build_parts.gd`, which bakes
## `world/parts_placed.tscn`).
##
## The prop is the part's own colour rather than the generic item cube, and it turns
## slowly so it catches the eye: a leg part should look like something you would bolt to a
## machine, or finding one reads as picking up another rock. `player/legs.gd` owns both
## the names and the colours, so what a part is called out here is what it is called in
## the Frame screen.

const Legs := preload("res://player/legs.gd")

@export var part_id: String = ""

const SPIN := 0.7          ## radians per second
const PROMPT_RANGE := 8.0  ## metres the idle prompt shows within

var _collected := false
var _hint: Label = null
var _hint_timer := 0.0


func _ready() -> void:
	add_to_group("part_pickup")
	# Keeps ticking while the tree is paused so the prompt clears the moment a menu takes
	# the mouse — otherwise it freezes mid-prompt behind the open Frame screen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	_apply_look()
	_hint = _make_hint_label()


func _process(delta: float) -> void:
	# The spin belongs to play, so it waits for the game to be running again rather than
	# turning slowly inside a pause.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(SPIN * delta)
	_tick_hint(delta)


func part_name() -> String:
	## What to call this part on screen.
	return str(Legs.NAMES.get(part_id, part_id))


func _apply_look() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var colour: Color = Legs.COLOURS.get(part_id, Legs.DEFAULT_COLOUR)
	if mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh.material_override.duplicate()
		mat.albedo_color = colour
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = 0.4
		mesh.material_override = mat


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	if not body.has_method("collect_part"):
		return
	if body.collect_part(part_id):
		_collected = true
		visible = false
		$CollisionShape3D.set_deferred("disabled", true)
		say("Found: %s — bolt it on at a service bench" % part_name())


# --------------------------------------------------------------------- hints

func _make_hint_label() -> Label:
	## Built in code and parented to the HUD, the way the boat and the bench do it — a
	## 3D node has no business drawing text of its own.
	var scene := get_tree().current_scene
	var hud: CanvasLayer = scene.get_node_or_null("HUD") if scene != null else null
	if hud == null:
		return null
	var label := Label.new()
	label.name = "PartHint"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Clear of the inventory bar along the bottom, and above the bench prompt (which sits
	# at -150), so a find and a prompt can both be on screen without touching.
	label.position = Vector2(-260, -195)
	label.custom_minimum_size = Vector2(520, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.visible = false
	hud.add_child(label)
	return label


func say(text: String, seconds := 4.0) -> void:
	## Flash a line, the way the boat says "Ashore". Used for the moment it is picked up,
	## while the prompt below is the idle state.
	if _hint == null:
		return
	_hint.text = text
	_hint.visible = true
	_hint_timer = seconds


func _tick_hint(delta: float) -> void:
	if _hint == null:
		return
	# While the mouse is loose a menu owns the screen, so nothing this pickup draws goes
	# over it — not the prompt, and not a flash left over from a find. The flash still
	# expires on its own clock, so it does not come back when the menu closes.
	var playing := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _hint_timer > 0.0:
		_hint_timer = maxf(_hint_timer - delta, 0.0)
		_hint.visible = playing
		return
	if not playing or _collected:
		_hint.visible = false
		return
	# Idle prompt, so a part lying in the world says what it is for.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.global_position.distance_to(global_position) <= PROMPT_RANGE:
		_hint.text = "%s — bolt it on at a service bench" % part_name()
		_hint.visible = true
	else:
		_hint.visible = false