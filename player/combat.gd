extends Node3D
## Combat node for the player: katana slash, bow shooting, worn-armor state.
## Lives under the player scene; the player delegates left/right click here
## and routes incoming damage through `absorb()`. Inventory access goes
## through the player (`player.inventory`).

const SlashScene := preload("res://player/slash.gd")
const ArrowScene := preload("res://items/arrow_projectile.tscn")
const ARMOR := preload("res://items/armor.gd")
const WEAPON := preload("res://items/weapon.gd")
const Sight := preload("res://world/sight.gd")

const SLASH_RANGE := 2.2
const SLASH_HALF_ANGLE := 0.7
const SLASH_ITEM := "sword"   # damage comes from the weapon table
const PUNCH_RANGE := 1.8      ## shorter than the katana: reach is the katana's edge
const PUNCH_HALF_ANGLE := 0.6
const PUNCH_ITEM := ""        ## bare hands: the default branch of Weapon.damage_of (5.0)
const PUNCH_COOLDOWN := 0.4   ## seconds between jabs, so a held click is not a drill

var player: CharacterBody3D = null   ## resolved from the scene tree in _ready

var _slash: Node3D = null
var _punch_cd := 0.0          ## counts down; a jab on cooldown does not swing
var armor_id := ""            ## equipped armor item id, "" = none
var armor_durability := 0.0
## item id -> how much of that piece is left. Armour is worn out by being hit; it is
## not repaired by being taken off, which is what the E path used to do by handing
## out the table's pristine durability on every wear.
var _wear := {}


signal armor_changed(armor_id: String, durability: float)


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	assert(player != null, "combat must be a direct child of the player")


func _process(delta: float) -> void:
	_punch_cd = maxf(_punch_cd - delta, 0.0)


## ------------------------------------------------------------------- katana

func try_slash() -> void:
	_ensure_slash()
	if _slash != null and not _slash.can_slash():
		return
	player.play_slash_sound()
	_slash.slash()


func _ensure_slash() -> void:
	if _slash != null or player.equipment == null:
		return
	_slash = Node3D.new()
	_slash.set_script(SlashScene)
	add_child(_slash)
	_slash.setup(player.equipment.get_sword_pivot(), player.equipment.get_trail(),
			_slash_damage)


func _slash_damage() -> void:
	_strike(SLASH_RANGE, SLASH_HALF_ANGLE, SLASH_ITEM)


## -------------------------------------------------------------- bare hands

func try_punch() -> bool:
	## Unarmed left click. Returns true when the drone actually swings, so the
	## caller plays the jab and the thump only when it landed in the world's
	## time as well as in its own. The jab was visual-only at first, which read
	## as "this animal cannot be hurt": the punch now runs the katana's cone
	## check with the bare-hand damage from the weapon table.
	if _punch_cd > 0.0:
		return false
	_punch_cd = PUNCH_COOLDOWN
	_strike(PUNCH_RANGE, PUNCH_HALF_ANGLE, PUNCH_ITEM)
	return true


func _strike(range_m: float, half_angle: float, item_id: String) -> int:
	## Cone check in front of the drone: scan the "damageable" group only,
	## filter by distance + half-angle, then hit in one pass. Returns how many
	## things took the blow (tests read it; the swing sound does not depend on
	## it, because a whiff still has to sound like a swing).
	var dir: Vector3 = -player.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	var hit_list: Array = []
	for node in player.get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(node) or node == player:
			continue
		var to: Vector3 = node.global_position - player.global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > range_m:
			continue
		if dist > 0.01 and dir.angle_to(to.normalized()) > half_angle:
			continue
		# The cone is measured on the ground plane, so a hill, a boulder or a tree
		# between us and the target has to be checked for separately: without this
		# a swing cut plants through the terrain between them.
		if not Sight.clear(player, node as Node3D):
			continue
		hit_list.append(node)
	if hit_list.is_empty():
		return 0   # a whiff shows nothing at the crosshair
	for node in hit_list:
		# The item id goes with the blow: a blade leaves a specimen, an arrow or a
		# fist does not (items/weapon.gd has_blade, fauna/fauna_base.gd _die).
		node.damage(WEAPON.damage_of(item_id), item_id)
	player.show_hit_marker()
	return hit_list.size()


## --------------------------------------------------------------------- bow

func has_bow() -> bool:
	if player.inventory == null:
		return false
	for i in player.inventory.SLOTS:
		if player.inventory.slots[i] == "bow":
			return true
	return false


func has_arrows() -> bool:
	return _find_arrow_stack() >= 0


func begin_draw_bow() -> void:
	if player._game_over:
		return
	if has_bow() and has_arrows():
		set_meta("bow_drawn", true)


func release_bow() -> void:
	if not get_meta("bow_drawn", false):
		return
	set_meta("bow_drawn", false)
	if not has_arrows() or player._game_over:
		return
	var idx := _find_arrow_stack()
	if idx >= 0:
		# Consume straight from the arrow stack: equipping it here used to
		# silently swap the held weapon to "arrows" on every shot, so the
		# next left-click grabbed blocks instead of slashing.
		player.inventory.consume_one(idx)
	var dir: Vector3 = -player.camera.global_transform.basis.z
	var arrow: Area3D = ArrowScene.instantiate()
	player.get_tree().current_scene.add_child(arrow)
	arrow.launch(player.camera.global_position + dir * 0.5, dir)
	player.play_grab_sound()


func _find_arrow_stack() -> int:
	if player.inventory == null:
		return -1
	for i in player.inventory.SLOTS:
		if player.inventory.slots[i] == "arrows" and player.inventory.counts[i] > 0:
			return i
	return -1


## ------------------------------------------------------------------- armor
##
## Wear is tracked here, **per item id**, not per inventory slot: the inventory owns
## slots and the UI, combat owns what a piece has left. Every path that wears a piece
## reads `_wear` rather than `ARMOR.STATS`, which is what stops armour repairing
## itself — pressing E twice used to hand out a fresh piece every time.

func durability_of(item_id: String) -> float:
	## What is left of this piece: the table's value only until it has been worn,
	## because being hit is what wears armour out.
	var stats: Dictionary = ARMOR.STATS.get(item_id, {})
	return float(_wear.get(item_id, float(stats.get("durability", 100.0))))


func reset_wear(item_id: String) -> void:
	## A newly picked-up piece starts whole. Wear is kept per item id, so this is the
	## only thing that tells a fresh piece apart from the broken one already in the
	## bag (a per-instance model would need the inventory to carry the number too).
	if ARMOR.STATS.has(item_id):
		_wear.erase(item_id)


func equip_armor(item_id: String) -> bool:
	## Programmatic equip (tests, savegame load). UI path: inventory key E.
	if player.inventory == null:
		return false
	if ARMOR.STATS.get(item_id, {}).is_empty():
		return false
	for i in player.inventory.SLOTS:
		if player.inventory.slots[i] == item_id:
			_wear_armour(item_id)
			return true
	return false


func wear_from_inventory(item_id: String) -> bool:
	## The inventory's E key. It knows which slot was pressed but not what the piece
	## has left — that is ours — so the durability it carries is advisory and ignored.
	## Wearing a broken piece is allowed and simply absorbs nothing; the HUD shows 0.
	if item_id == "" or item_id == armor_id:
		# Empty slot, or the piece already on: E means take it off.
		if armor_id == "":
			return false
		take_off_armor()
		return true
	if ARMOR.STATS.get(item_id, {}).is_empty():
		return false
	_wear_armour(item_id)
	return true


func take_off_armor() -> void:
	armor_id = ""
	armor_durability = 0.0
	armor_changed.emit("", 0.0)


func _wear_armour(item_id: String) -> void:
	armor_id = item_id
	armor_durability = durability_of(item_id)
	# set_worn(), not the inventory's own wear call: the inventory's armor_changed
	# signal comes back here through player._on_armor_changed, so an emitting call
	# would recurse.
	if player.inventory != null:
		player.inventory.set_worn(item_id)
	armor_changed.emit(item_id, armor_durability)


func absorb(amount: float) -> float:
	## Armour soaks its share first and wears down as it does; the wear is remembered
	## so taking the piece off cannot undo it. Returns the damage that passes through,
	## and emits armor_changed only on a real state change (a break) — never per hit,
	## because the HUD reads armor_status() every frame for the number.
	if armor_id == "" or armor_durability <= 0.0:
		return amount
	var stats: Dictionary = ARMOR.STATS.get(armor_id, {})
	var absorption: float = float(stats.get("absorption", 0.0))
	var eaten: float = clampf(amount * absorption, 0.0, amount)
	armor_durability = maxf(armor_durability - eaten * 0.5, 0.0)
	_wear[armor_id] = armor_durability
	if armor_durability <= 0.0:
		armor_id = ""   # it broke: what is left in the bag is a dead piece
		armor_changed.emit(armor_id, armor_durability)
	return amount - eaten


func armor_status() -> Dictionary:
	return {"id": armor_id, "durability": armor_durability}


func load_armor_state(id: String, durability: float) -> void:
	## Restoring a save. The saved durability *is* what that piece has left, so it is
	## remembered for a later re-wear instead of being treated as a new piece.
	armor_id = id
	armor_durability = durability
	if id != "":
		_wear[id] = durability
	armor_changed.emit(id, durability)