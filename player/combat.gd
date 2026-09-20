extends Node3D
## Combat node for the player: katana slash, bow shooting, worn-armor state.
## Lives under the player scene; the player delegates left/right click here
## and routes incoming damage through `absorb()`. Inventory access goes
## through the player (`player.inventory`).

const SlashScene := preload("res://player/slash.gd")
const ArrowScene := preload("res://items/arrow_projectile.tscn")
const ARMOR := preload("res://items/armor.gd")
const WEAPON := preload("res://items/weapon.gd")

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
		hit_list.append(node)
	for node in hit_list:
		node.damage(WEAPON.damage_of(item_id))
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

func equip_armor(item_id: String) -> bool:
	## Programmatic equip (tests, savegame load). UI path: inventory key E.
	if player.inventory == null:
		return false
	var stats: Dictionary = ARMOR.STATS.get(item_id, {})
	if stats.is_empty():
		return false
	for i in player.inventory.SLOTS:
		if player.inventory.slots[i] == item_id:
			armor_id = item_id
			armor_durability = float(stats.get("durability", 100.0))
			player.inventory.wear_armor(item_id, armor_durability)
			armor_changed.emit(item_id, armor_durability)
			return true
	return false


func absorb(amount: float) -> float:
	## Armor soaks its share first, degrading. Returns damage that passes
	## through; emits armor_changed when durability drops or armor breaks.
	if armor_id == "" or armor_durability <= 0.0:
		return amount
	var stats: Dictionary = ARMOR.STATS.get(armor_id, {})
	var absorption: float = float(stats.get("absorption", 0.0))
	var eaten: float = clampf(amount * absorption, 0.0, amount)
	armor_durability = maxf(armor_durability - eaten * 0.5, 0.0)
	if armor_durability <= 0.0:
		armor_id = ""   # armor broke
		# Only signal on a real state change. Emitting per hit made the equip
		# flourish fire on every scratch; the HUD reads durability straight
		# from armor_status() each frame, so it still ticks down normally.
		armor_changed.emit(armor_id, armor_durability)
	return amount - eaten


func armor_status() -> Dictionary:
	return {"id": armor_id, "durability": armor_durability}


func load_armor_state(id: String, durability: float) -> void:
	armor_id = id
	armor_durability = durability
	armor_changed.emit(id, durability)