extends StaticBody3D
## The Explorer's Kit — the satchel the drone's survey gear is found in, and the bag it
## carries from then on.
##
## A new run begins with **nothing at all** (`player.gd`'s `STARTING_ITEMS` is empty):
## the katana and the four instruments are found in the world instead. This satchel is
## where the instruments wait, a short walk from where the drone wakes on Ezo's SW
## cape — `world/main.tscn` places it, and `tests/test_explorer_kit.gd` pins it to the
## terrain there and to the spawn point. The katana lies out on the cape on its own.
##
## E opens it (the boat's and the bench's key, `interact`) and the contents go straight
## to the inventory. Finding it is also one of the run's **screens**: the satchel asks
## the HUD's milestone story screen to play `explorer_kit` (`ui/story_text.gd`) the
## moment it is emptied, so the kit narrates itself instead of being a silent box.
##
## **The satchel is the drone's bag, so it moves.** This is the one container in the
## game that does. Emptying it puts it on the drone's shoulder
## (`player/equipment.gd`'s `show_satchel`) and takes it out of the grass: the player
## is never shown two of them, and the bag being *worn* is what tells a returning
## player that this run has been here before. It is why this node hides itself instead
## of tipping a lid back and staying put — an emptied satchel is not lying on the cape,
## it is on the drone.
##
## Three rules keep the container itself honest:
##
##  - **Nothing is handed out twice.** An item the drone already carries is left alone,
##    which is what makes a reloaded save safe: without it the satchel would refill a
##    bag that already holds all four.
##  - **A bag that is full keeps the satchel shut**, so the gear is come back for rather
##    than lost (it opens the moment everything fits or is already carried).
##  - **What has been opened lives in the save**, not in the scene
##    (`player.opened_containers`), so a loaded run lands on the same state a fresh
##    emptying does: bag on the drone, nothing in the grass.
##
## Like the boat and the bench it is one merged, vertex-coloured mesh
## (`world/prop_mesh.gd`) on a `StaticBody3D`, so it cannot be walked through. When it
## is emptied its shape is disabled as well as hidden, so no invisible volume is left
## standing on the cape where the satchel lay.

const PropMesh := preload("res://world/prop_mesh.gd")

## What is inside, in the order it goes into the bag. The Pedia notebook leads: it is
## the thing the other three write into. Ids are `items/item_db.gd`'s.
const CONTENTS := ["notebook", "pen", "magnifying_glass", "binoculars"]

## How close the drone has to be to press E — the bench's own radius.
const USE_RADIUS := 3.5

## The id this satchel is remembered by (`player.open_container`). Per placed instance,
## so a second satchel is a second entry rather than the same one emptied twice.
@export var container_id: String = "explorer_kit"

## Satchel colours: a leather bag, a darker flap over the front, a brass buckle and the
## strap folded across the top, with one lit mark on the flap — cyan, the drone's own
## eye — until it is emptied. The leather is a warm mid-brown on purpose: a dark value
## renders as a grey lump under the sky's ambient on up-facing surfaces — the trap the
## old iron colour fell into at 0.28.
const LEATHER := Color(0.44, 0.29, 0.16)
const LEATHER_DARK := Color(0.29, 0.18, 0.10)
const BRASS := Color(0.72, 0.55, 0.24)
const GLOW := Color(0.35, 0.85, 0.9)

var _opened := false
var _shape: CollisionShape3D = null
var _glow: MeshInstance3D = null
var _hint: Label = null


func _ready() -> void:
	add_to_group("explorer_kit")     # tests and anything else find them through this
	# Keeps ticking while the tree is paused, so the prompt can clear itself the moment
	# a menu takes the mouse — the bench's reason, and the same one line.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visuals()
	_build_collision()
	_hint = _make_hint_label()
	# Whether this satchel was emptied earlier in the run lives on the player, and the
	# player's own _ready is what restores the save; a deferred call is the first
	# moment that is true for every node in the scene.
	_sync_from_player.call_deferred()


func contents() -> Array:
	## What the satchel holds. Read by tests and by anything listing it.
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
	## Hand the contents over. True when the satchel did something: it opened now, or it
	## was already open (the "the drone has one of those already" case, which must not
	## read as a failure to a test). Out of reach, or a full bag that would drop gear
	## on the ground, is a false and leaves the satchel as it was.
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
	_wear_satchel(player)
	# Finding the kit is a *screen* (ui/story_text.gd's `explorer_kit` milestone): the
	# satchel narrates itself rather than being a silent container. Played here, on the
	# opening path only — a satchel a save remembers as already emptied is on the
	# drone's shoulder and says nothing, which is `_sync_from_player`'s job, not this
	# one's.
	var story := story_screen()
	if story != null and story.has_method("play_milestone"):
		story.play_milestone("explorer_kit")
	return true


func _wear_satchel(player: Node3D) -> void:
	## The other half of emptying it: the four instruments went into this satchel, and
	## the satchel goes onto the drone (`player/equipment.gd`'s `show_satchel`), so the
	## bag the drone carries is the bag that was lying on the cape.
	##
	## A loaded run gets the same bag without this call — the equipment asks the
	## player's opened-container list for itself, the same question this node asks in
	## `_sync_from_player`.
	var equipment: Node = player.get_node_or_null("Equipment")
	if equipment != null and equipment.has_method("show_satchel"):
		equipment.show_satchel(true)


func story_screen() -> Node:
	## The milestone story screen, a child of the HUD (`world/main.tscn`). The satchel asks
	## it to play a page and never handles a key or draws text itself — the bench's rule
	## for the Frame screen, and the same shape: one owner, reached through a lookup.
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("HUD/StoryScreen")


func _set_open() -> void:
	## The emptied satchel: it is the drone's bag from here on, so it leaves the world
	## and turns up on the drone's shoulder (`player/equipment.gd`). Idempotent,
	## because a save that remembers this container has to land in exactly the state
	## pressing E does.
	if _opened:
		return
	_opened = true
	visible = false
	if _shape != null:
		# Hidden is not enough on its own: an invisible StaticBody3D still stops the
		# drone, and a wall you cannot see where a satchel used to lie is worse than
		# the open lid it replaces.
		_shape.set_deferred("disabled", true)


func _sync_from_player() -> void:
	## A save keeps the satchel emptied and worn, so ask the player what it has already
	## opened once the scene is up. Nothing else about it is remembered: it is a prop,
	## not a Pedia entry, and there is no marker for it anywhere.
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("has_opened_container") \
			and player.has_opened_container(container_id):
		_set_open()


func _physics_process(_delta: float) -> void:
	_tick_hint()


# ------------------------------------------------------------------- visuals

func _build_visuals() -> void:
	## A satchel lying shut on the cape: a leather body, a darker flap down its front
	## with a brass buckle, and the strap folded across the top. Everything is merged
	## into one surface (`world/prop_mesh.gd`), the way the boat and the bench are.
	##
	## Built to the ground, base at y = 0: `world/main.tscn` places the node on
	## `island.gd`'s height field, and `tests/test_explorer_kit.gd` fails if it floats.
	var body := BoxMesh.new()
	body.size = Vector3(0.62, 0.30, 0.44)
	var rim := BoxMesh.new()
	rim.size = Vector3(0.66, 0.05, 0.46)
	var flap := BoxMesh.new()
	flap.size = Vector3(0.50, 0.20, 0.04)
	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.10, 0.09, 0.03)
	var strap := BoxMesh.new()
	strap.size = Vector3(0.78, 0.032, 0.10)
	# The strap lies across the satchel turned off the axis: a strap parallel to the
	# edges reads as a second plank rather than as something thrown down.
	var strap_turn := Basis(Vector3.UP, 0.42)
	var parts := [
		[body, Transform3D(Basis(), Vector3(0, 0.15, 0)), LEATHER],
		[rim, Transform3D(Basis(), Vector3(0, 0.325, 0)), LEATHER_DARK],
		# The flap hangs down the front (+Z), which is the face the drone walks up to:
		# the satchel is placed unrotated on the cape, south of it is the spawn.
		[flap, Transform3D(Basis(), Vector3(0, 0.24, 0.225)), LEATHER_DARK],
		[buckle, Transform3D(Basis(), Vector3(0, 0.17, 0.245)), BRASS],
		[strap, Transform3D(strap_turn, Vector3(0, 0.35, 0.02)), LEATHER_DARK],
	]
	var shell := MeshInstance3D.new()
	shell.name = "Body"
	shell.mesh = PropMesh.merge(parts)
	shell.material_override = PropMesh.paint()
	add_child(shell)

	# The mark: lit while the satchel is still shut, and gone with it once it is
	# emptied — the "there is something in here" at night, without a light in the
	# scene budget.
	_glow = MeshInstance3D.new()
	_glow.name = "Mark"
	var mark := BoxMesh.new()
	mark.size = Vector3(0.18, 0.08, 0.02)
	_glow.mesh = mark
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = GLOW
	glow_mat.emission_enabled = true
	glow_mat.emission = GLOW
	# Dim on purpose: at 1.6 with the project's bloom (glow_intensity 0.6) the mark
	# blew out to a white rectangle and read as a hole in the satchel rather than as a
	# small lit plate. It wants to be visible at night, not to be the brightest thing
	# on the cape.
	glow_mat.emission_energy_multiplier = 0.9
	_glow.material_override = glow_mat
	# On the flap above the buckle, proud of the leather by a few millimetres so the
	# flap it sits on cannot swallow it.
	_glow.position = Vector3(0, 0.285, 0.253)
	add_child(_glow)


func _build_collision() -> void:
	## Solid, so the satchel cannot be walked through — the boat's and the bench's rule
	## for anything the player is meant to stand next to rather than inside. A little
	## taller than the bag itself, so the rim and the strap are inside it too.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.66, 0.38, 0.48)
	shape.shape = box
	shape.position = Vector3(0, 0.19, 0)
	add_child(shape)
	_shape = shape


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
	## Idle prompt, so the player knows the satchel can be opened at all. Only while the
	## world has the mouse: with a menu or the inventory up, E is not the satchel's — and
	## only while it is still shut, because an emptied satchel has nothing to say.
	if _hint == null:
		return
	_hint.visible = false
	if _opened or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var player := get_tree().get_first_node_in_group("player")
	_hint.visible = can_be_used_by(player)
	if _hint.visible:
		_hint.text = "E — open the Explorer's Kit"