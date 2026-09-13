extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const START_LIFE = 40
const LIFE_DRAIN_PER_SEC = 1.0
const SUNBULB_HEAL = 15.0
const SAVEGAME := preload("res://world/savegame.gd")
const MOUSE_SENSITIVITY = 0.002
const ZOOM_SPEED = 5.0
const FOV_MIN = 50.0
const FOV_MAX = 150.0
const FOV_DEFAULT = 75.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var life: float = START_LIFE
var _drain_accum: float = 0.0
var _game_over: bool = false
var sunbulbs_collected: int = 0
var _held_block: MovableBlock = null
const InventoryScene := preload("res://ui/inventory.tscn")
@onready var inventory: Control = get_tree().get_first_node_in_group("inventory")
@onready var equipment: Node3D = $Equipment
@onready var combat: Node3D = $Combat

var _snd_jump: AudioStreamPlayer
var _snd_land: AudioStreamPlayer
var _snd_slash: AudioStreamPlayer
var _snd_step: AudioStreamPlayer
var _snd_grab: AudioStreamPlayer
var _snd_drop: AudioStreamPlayer
var _was_on_floor := true
var _step_accum := 0.0

const STEP_INTERVAL := 0.35   # seconds between footsteps while walking

func _make_snd(path: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func save_state() -> Dictionary:
	## Everything a Continue needs to restore.
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"life": life,
		"sunbulbs": sunbulbs_collected,
		"items": inventory.slots.duplicate() if inventory != null else [],
		"counts": inventory.counts.duplicate() if inventory != null else [],
		"equipped": inventory.equipped_slot if inventory != null else -1,
		"armor": combat.armor_id,
		"armor_durability": combat.armor_durability,
	}


func load_state(data: Dictionary) -> void:
	## Restore from a savegame Dictionary (missing/invalid keys ignored).
	life = float(data.get("life", START_LIFE))
	sunbulbs_collected = int(data.get("sunbulbs", data.get("orbs", 0)))
	var pos: Array = data.get("pos", [])
	if pos.size() == 3:
		global_position = Vector3(pos[0], pos[1], pos[2])
		velocity = Vector3.ZERO
	if inventory != null:
		var items: Array = data.get("items", [])
		var cnts: Array = data.get("counts", [])
		inventory.restore(items, cnts)
		inventory.equipped_slot = -1
		var eq := int(data.get("equipped", -1))
		if eq >= 0 and eq < inventory.SLOTS and inventory.slots[eq] != "":
			inventory.equip(eq)
		else:
			inventory.refresh()
		var saved_armor := str(data.get("armor", ""))
		if saved_armor != "":
			combat.load_armor_state(saved_armor,
					float(data.get("armor_durability", 0.0)))
			inventory.wear_armor(saved_armor, combat.armor_durability)
			inventory.refresh()
	_update_hud()


func _ready() -> void:
	_snd_jump = _make_snd("res://sounds/jump.wav", -8.0)
	_snd_land = _make_snd("res://sounds/land.wav", -6.0)
	_snd_step = _make_snd("res://sounds/step.wav", -18.0)
	_snd_grab = _make_snd("res://sounds/grab.wav", -10.0)
	_snd_slash = _make_snd("res://sounds/slash.wav", -6.0)
	_snd_drop = _make_snd("res://sounds/drop.wav", -10.0)
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = FOV_DEFAULT
	if pause_menu != null:
		pause_requested.connect(pause_menu.open)
	if inventory != null:
		inventory.armor_changed.connect(_on_armor_changed)
		inventory.item_equipped.connect(_on_item_equipped)
	combat.armor_changed.connect(_on_combat_armor_changed)
	# Continue flow: restore a saved game exactly once, when launched from
	# the splash screen's Continue button.
	if SAVEGAME.take_pending_load():
		load_state(SAVEGAME.read())


@onready var life_label: Label = get_tree().get_first_node_in_group("life_label")
@onready var game_over_label: CanvasItem = get_tree().get_first_node_in_group("game_over_label")
@onready var sunbulb_label: Label = get_tree().get_first_node_in_group("sunbulb_label")
@onready var camera: Camera3D = $Camera3D
@onready var pickup_sound: AudioStreamPlayer = $AudioStreamPlayer
@onready var game_over_sound: AudioStreamPlayer = $GameOverSound
@onready var fade_in: CanvasLayer = get_node_or_null("../FadeIn")
@onready var pause_menu: Control = get_node_or_null("../HUD/PauseMenu")

var _input_locked := false

signal pause_requested
signal equipped_item_changed(item_id: String)


func add_item(item_id: String) -> bool:
	## Pickups call this: insert into the first free inventory slot.
	if inventory == null:
		# Fallback: HUD wasn't ready yet — create it under the HUD layer.
		var hud: CanvasLayer = get_node_or_null("../HUD")
		if hud != null:
			inventory = InventoryScene.instantiate()
			hud.add_child(inventory)
	if inventory == null:
		return false
	var ok: bool = inventory.add_item(item_id)
	if ok:
		if _snd_grab:
			_snd_grab.play()
	return ok


func get_equipped_item() -> String:
	if inventory != null:
		return inventory.get_equipped_item()
	return ""

func _lock_check() -> bool:
	# Live check: the fade overlay clears its own flag when done.
	if fade_in != null:
		_input_locked = fade_in.input_locked
	return _input_locked


func _unhandled_input(event: InputEvent) -> void:
	if _lock_check():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw the player (rotate around Y).
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Pitch the camera (rotate around X), clamp to avoid flipping.
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)

	# Scroll wheel zoom.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = max(camera.fov - ZOOM_SPEED, FOV_MIN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = min(camera.fov + ZOOM_SPEED, FOV_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if get_equipped_item() == "sword":
				do_slash()
			else:
				_toggle_grab()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_begin_draw_bow()
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_release_bow()

	# ESC: restart on the death screen, otherwise open the pause menu.
	if event.is_action_pressed("ui_cancel"):
		if _game_over:
			_restart()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			pause_requested.emit()


## Crosshair interaction: grab or release the block under the crosshair.
func _toggle_grab() -> void:
	if _held_block != null:
		_held_block.release()
		_held_block = null
		_snd_drop.play()
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			camera.global_position,
			camera.global_position - camera.global_transform.basis.z * 5.0)
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider is MovableBlock:
		_held_block = collider
		_held_block.grab(camera)
		_snd_grab.play()

## ----------------------------------------------------------------- katana slash

const SlashScene := preload("res://player/slash.gd")

func do_slash() -> void:
	combat.try_slash()


func play_slash_sound() -> void:
	if _snd_slash:
		_snd_slash.play()


# --------------------------------------------------------------------- bow shooting

func _on_item_equipped(slot: int) -> void:
	if equipment != null and inventory != null:
		equipment.show_for_equipped(inventory.get_equipped_item())
		equipment.play_flourish()


func _on_armor_changed(armor_id: String, durability: float) -> void:
	## UI path: inventory emits when the player presses E on an armor slot.
	combat.load_armor_state(armor_id, durability)


func _on_combat_armor_changed(armor_id: String, durability: float) -> void:
	## Combat node armor state changed (degraded/broken/equipped): sync visuals.
	if equipment != null:
		equipment.show_armor(armor_id != "")
		equipment.play_flourish()
	if inventory != null:
		inventory.worn_armor_id = armor_id
	_update_hud()


func has_bow() -> bool:
	return combat.has_bow()


func has_arrows() -> bool:
	return combat.has_arrows()


func equip_armor(item_id: String) -> bool:
	return combat.equip_armor(item_id)


func armor_status() -> Dictionary:
	return combat.armor_status()


func _begin_draw_bow() -> void:
	combat.begin_draw_bow()


func _release_bow() -> void:
	combat.release_bow()


func play_grab_sound() -> void:
	if _snd_grab:
		_snd_grab.play()


func _physics_process(delta: float) -> void:
	if _game_over:
		# Dead: show game-over screen, wait for ESC to restart at spawn.
		return

	# Drain 1 life point per second.
	_drain_accum += delta
	while _drain_accum >= 1.0:
		life -= LIFE_DRAIN_PER_SEC
		_drain_accum -= 1.0
		if life <= 0.0:
			life = 0.0
			_trigger_game_over()
	_update_hud()

	# Fell off the map (into the sea / off the terrain): die immediately
	# and respawn at the start point. Ground is never below y = -4, and the
	# seafloor sits around -3.5, so anything under -8 is off the map.
	if global_position.y < -8.0:
		_fall_death()

	# Apply gravity when airborne.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump with Space.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _lock_check():
		velocity.y = JUMP_VELOCITY
		_snd_jump.play()

	# WASD movement relative to player facing direction.
	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()

	var current_speed := SPEED
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed = SPEED * 2.0

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

	# Landing sound: transition from airborne to on-floor.
	if is_on_floor() and not _was_on_floor and velocity.y <= 0.0:
		_snd_land.play()
	_was_on_floor = is_on_floor()

	# Footsteps while moving on the ground.
	if is_on_floor() and direction.length() > 0.1:
		_step_accum += delta * (2.0 if current_speed > SPEED else 1.0)
		if _step_accum >= STEP_INTERVAL:
			_step_accum = 0.0
			_snd_step.play()
	else:
		_step_accum = STEP_INTERVAL   # ready to step immediately on move


func damage(amount: float) -> void:
	## Player damage route: armor (combat node) soaks its share first.
	var through: float = combat.absorb(amount)
	_apply_damage(through)


func _apply_damage(amount: float) -> void:
	if _game_over:
		return
	life = maxf(life - amount, 0.0)
	if life <= 0.0:
		_trigger_game_over()
	else:
		_update_hud()


func heal(amount: float) -> void:
	## Restore life only. Collection counting happens in collect_sunbulb().
	life += amount
	if pickup_sound:
		pickup_sound.play()
	_update_hud()


func collect_sunbulb() -> void:
	## Pickup path: heal + count the collection (sunbulb.tscn calls this).
	heal(SUNBULB_HEAL)
	sunbulbs_collected += 1
	_update_hud()


func _trigger_game_over() -> void:
	_game_over = true
	velocity = Vector3.ZERO
	# Death penalty: you lose everything you were carrying.
	if inventory != null:
		inventory.clear_all()
	# Drop the saved items too: a fresh run must start empty.
	SaveGame.clear()
	if game_over_label:
		game_over_label.visible = true
	if game_over_sound:
		game_over_sound.play()
	# Free the mouse so player can click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_hud()


func _fall_death() -> void:
	## Fell off the map: show the game-over screen; ESC restarts at spawn.
	life = 0.0
	_trigger_game_over()


func _restart() -> void:
	_game_over = false
	life = START_LIFE
	_drain_accum = 0.0
	sunbulbs_collected = 0
	velocity = Vector3.ZERO
	camera.fov = FOV_DEFAULT
	# Respawn at the game's starting point on the SW cape.
	var spawn: Vector3 = Ezo.spawn_point()
	global_position = spawn + Vector3(0.0, 0.5, 0.0)   # small clearance so we land, not clip
	if game_over_label:
		game_over_label.visible = false
	# Re-capture mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Respawn all pickups (sunbulbs).
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.respawn()
	_update_hud()


var _armor_label: Label


func _update_hud() -> void:
	if life_label:
		life_label.text = "Life: %d" % int(ceil(life))
	if _armor_label == null:
		var hud: CanvasLayer = get_node_or_null("../HUD")
		if hud != null:
			_armor_label = Label.new()
			_armor_label.position = Vector2(10, 40)
			_armor_label.add_theme_font_size_override("font_size", 14)
			hud.add_child(_armor_label)
	if _armor_label != null:
		var st: Dictionary = combat.armor_status()
		if st["id"] != "" and st["durability"] > 0.0:
			var pretty: String = str(st["id"]).replace("_", " ").capitalize()
			_armor_label.text = "Armor: %s (%d%%)" % [pretty, int(st["durability"])]
			_armor_label.visible = true
		else:
			_armor_label.visible = false
	if sunbulb_label:
		sunbulb_label.text = "Sunbulbs: %d" % sunbulbs_collected
