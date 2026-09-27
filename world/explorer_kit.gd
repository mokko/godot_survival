extends StaticBody3D
## The Explorer's Kit — the crate the drone's survey gear is found in.
##
## A new run begins with **nothing at all** (`player.gd`'s `STARTING_ITEMS` is empty):
## the katana and the four instruments are found in the world instead. This crate is
## where the instruments wait, a short walk from where the drone wakes on Ezo's SW
## cape — `world/main.tscn` places it, and `tests/test_explorer_kit.gd` pins it to the
## terrain there and to the spawn point. The katana lies out on the cape on its own.
##
## E opens it (the boat's and the bench's key, `interact`) and the contents go straight
## to the inventory. Finding it is also one of the run's **screens**: the crate asks the
## HUD's milestone story screen to play `explorer_kit` (`ui/story_text.gd`) the moment it
## is emptied, so the kit narrates itself instead of being a silent box. Three rules keep
## the crate itself honest:
##
##  - **Nothing is handed out twice.** An item the drone already carries is left alone,
##    which is what makes a reloaded save safe: without it the crate would refill a bag
##    that already holds all four.
##  - **A bag that is full keeps the crate shut**, so the gear is come back for rather
##    than lost (the crate opens the moment everything fits or is already carried).
##  - **What has been opened lives in the save**, not in the scene
##    (`player.opened_containers`), so an emptied crate still reads as emptied after
##    Load Game instead of looking shut and offering what the drone already has.
##
## Like the boat and the bench it is one merged, vertex-coloured mesh
## (`world/prop_mesh.gd`) on a `StaticBody3D`, so it cannot be walked through. The lid
## is a second mesh on a pivot: it tips back when the crate is emptied, which is the
## only trace in the world that this crate has been opened.

const PropMesh := preload("res://world/prop_mesh.gd")

## What is inside, in the order it goes into the bag. The Pedia notebook leads: it is
## the thing the other three write into. Ids are `items/item_db.gd`'s.
const CONTENTS := ["notebook", "pen", "magnifying_glass", "binoculars"]

## How close the drone has to be to press E — the bench's own radius.
const USE_RADIUS := 3.5

## The id this crate is remembered by (`player.open_container`). Per placed instance,
## so a second crate is a second entry rather than the same one emptied twice.
@export var container_id: String = "explorer_kit"

## Crate colours: a plank box with iron bands and a brass latch, and one lit mark on
## the front — cyan, the drone's own eye — until the crate is emptied. The iron is
## darker than it looks on paper: with the sky's ambient on up-facing surfaces, its
## first value (0.28) rendered as pale grey straps rather than iron.
const WOOD := Color(0.42, 0.29, 0.17)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const IRON := Color(0.16, 0.17, 0.19)
const BRASS := Color(0.72, 0.55, 0.24)
const GLOW := Color(0.35, 0.85, 0.9)

## The lid hangs on its back top edge, so it swings open away from whoever pressed E,
## and the angle is where it rests: tipped back past upright, the way a chest lid is.
const LID_PIVOT := Vector3(0.0, 0.48, -0.28)
const LID_OPEN_ANGLE := -1.9   ## radians

var _opened := false
var _lid: Node3D = null
var _glow: MeshInstance3D = null
var _hint: Label = null


func _ready() -> void:
	add_to_group("explorer_kit")     # tests and anything else find crates through this
	# Keeps ticking while the tree is paused, so the prompt can clear itself the moment
	# a menu takes the mouse — the bench's reason, and the same one line.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visuals()
	_build_collision()
	_hint = _make_hint_label()
	# Whether this crate was emptied earlier in the run lives on the player, and the
	# player's own _ready is what restores the save; a deferred call is the first
	# moment that is true for every node in the scene.
	_sync_from_player.call_deferred()


func contents() -> Array:
	## What the crate holds. Read by tests and by anything listing it.
	return CONTENTS


func is_open() -> bool:
	return _opened


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
	if use_for_test(get_tree().get_first_node_in_group("player")):
		# One press, one thing: stop the same E event reaching whoever else listens.
		get_viewport().set_input_as_handled()


func use_for_test(player: Node3D) -> bool:
	## Test seam: the same path E takes once its guards have passed, without
	## synthesising input events — headless cannot capture the mouse, so the E path
	## itself is unreachable from a test (the boat and the bench carry the same seam).
	return use(player)


func use(player: Node3D) -> bool:
	## Hand the contents over. True when the crate did something: it opened now, or it
	## was already open (the "the drone has one of those already" case, which must not
	## read as a failure to a test). Out of reach, or a full bag that would drop gear
	## on the ground, is a false and leaves the crate as it was.
	if player == null or not player.has_method("add_item") \
			or not player.has_method("has_item"):
		return false
	if not can_be_used_by(player):
		return false
	if _opened:
		return true
	var refused := false
	for item_id in CONTENTS:
		if player.has_item(item_id):
			continue               # carried already: never a second copy
		if not player.add_item(item_id):
			refused = true         # the bag is full — the rest is come back for
	if refused:
		return false
	_set_open()
	if player.has_method("open_container"):
		player.open_container(container_id)
	# Finding the kit is a *screen* (ui/story_text.gd's `explorer_kit` milestone): the
	# crate narrates itself rather than being a silent container. Played here, on the
	# opening path only — a crate a save remembers as already emptied stands open and
	# says nothing, which is `_sync_from_player`'s job and not this one's.
	var story := story_screen()
	if story != null and story.has_method("play_milestone"):
		story.play_milestone("explorer_kit")
	return true


func story_screen() -> Node:
	## The milestone story screen, a child of the HUD (`world/main.tscn`). The crate asks
	## it to play a page and never handles a key or draws text itself — the bench's rule
	## for the Frame screen, and the same shape: one owner, reached through a lookup.
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("HUD/StoryScreen")


func _set_open() -> void:
	## The emptied crate: lid tipped back, mark dark. Idempotent, because a save that
	## remembers this crate has to land in exactly the same state as pressing E does.
	if _opened:
		return
	_opened = true
	if _lid != null:
		_lid.rotation.x = LID_OPEN_ANGLE
	if _glow != null:
		_glow.visible = false


func _sync_from_player() -> void:
	## A save keeps the crate emptied, so ask the player what it has already opened
	## once the scene is up. Nothing else about the crate is remembered: it is a prop,
	## not a Pedia entry, and there is no marker for it anywhere.
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("has_opened_container") \
			and player.has_opened_container(container_id):
		_set_open()


func _physics_process(_delta: float) -> void:
	_tick_hint()


# ------------------------------------------------------------------- visuals

func _build_visuals() -> void:
	## A crate you could carry: a plank box, two iron bands, a brass latch and a lit
	## mark on the front. Everything but the lid is merged into one surface
	## (`world/prop_mesh.gd`), the way the boat and the bench are.
	var body := BoxMesh.new()
	body.size = Vector3(0.8, 0.44, 0.56)
	var band := BoxMesh.new()
	band.size = Vector3(0.07, 0.46, 0.6)
	var latch := BoxMesh.new()
	latch.size = Vector3(0.16, 0.1, 0.05)
	var hasp := BoxMesh.new()
	hasp.size = Vector3(0.1, 0.14, 0.03)
	var parts := [
		[body, Transform3D(Basis(), Vector3(0, 0.22, 0)), WOOD],
		[band, Transform3D(Basis(), Vector3(-0.24, 0.22, 0)), IRON],
		[band, Transform3D(Basis(), Vector3(0.24, 0.22, 0)), IRON],
		# Brass latch plate on the front (+Z), which is the face the drone walks up
		# to: the crate is placed unrotated on the cape, south of it is the spawn.
		[latch, Transform3D(Basis(), Vector3(0, 0.26, 0.285)), BRASS],
		[hasp, Transform3D(Basis(), Vector3(0, 0.13, 0.285)), BRASS],
	]
	var shell := MeshInstance3D.new()
	shell.name = "Body"
	shell.mesh = PropMesh.merge(parts)
	shell.material_override = PropMesh.paint()
	add_child(shell)

	# The mark: lit while the crate is shut, dark once it is emptied — the crate's own
	# "there is something in here" at night, without a light in the scene budget.
	_glow = MeshInstance3D.new()
	_glow.name = "Mark"
	var mark := BoxMesh.new()
	mark.size = Vector3(0.22, 0.12, 0.02)
	_glow.mesh = mark
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = GLOW
	glow_mat.emission_enabled = true
	glow_mat.emission = GLOW
	# Dim on purpose: at 1.6 with the project's bloom (glow_intensity 0.6) the mark
	# blew out to a white rectangle and read as a hole in the crate rather than as a
	# small lit plate. It wants to be visible at night, not to be the brightest thing
	# on the cape.
	glow_mat.emission_energy_multiplier = 0.9
	_glow.material_override = glow_mat
	_glow.position = Vector3(0, 0.38, 0.29)
	add_child(_glow)

	# The lid, on its own pivot so it can be tipped back.
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = LID_PIVOT
	add_child(_lid)
	var plank := BoxMesh.new()
	plank.size = Vector3(0.84, 0.08, 0.6)
	var edge := BoxMesh.new()
	edge.size = Vector3(0.86, 0.06, 0.06)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.name = "LidMesh"
	# Built around the pivot in +Z: the lid's far edge is the one that lifts.
	lid_mesh.mesh = PropMesh.merge([
		[plank, Transform3D(Basis(), Vector3(0, 0, 0.28)), WOOD],
		[edge, Transform3D(Basis(), Vector3(0, 0.01, 0.57)), WOOD_DARK],
	])
	lid_mesh.material_override = PropMesh.paint()
	_lid.add_child(lid_mesh)


func _build_collision() -> void:
	## Solid, so the crate cannot be walked through — the boat's and the bench's rule
	## for anything the player is meant to stand next to rather than inside.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.84, 0.52, 0.6)
	shape.shape = box
	shape.position = Vector3(0, 0.26, 0)
	add_child(shape)


# --------------------------------------------------------------------- hints

func _make_hint_label() -> Label:
	## The boat's and the bench's pattern: a label built in code and parented to the
	## HUD, because a 3D node has no business drawing text of its own. The same line
	## on screen as the bench's prompt — only one of the two can ever be in reach.
	var scene := get_tree().current_scene
	var hud: CanvasLayer = scene.get_node_or_null("HUD") if scene != null else null
	if hud == null:
		return null
	var label := Label.new()
	label.name = "KitHint"
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-190, -150)
	label.custom_minimum_size = Vector2(380, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.visible = false
	hud.add_child(label)
	return label


func _tick_hint() -> void:
	## Idle prompt, so the player knows a crate can be opened at all. Only while the
	## world has the mouse: with a menu or the inventory up, E is not the crate's — and
	## only while it is still shut, because an emptied crate has nothing to say.
	if _hint == null:
		return
	_hint.visible = false
	if _opened or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var player := get_tree().get_first_node_in_group("player")
	_hint.visible = can_be_used_by(player)
	if _hint.visible:
		_hint.text = "E — open the Explorer's Kit"