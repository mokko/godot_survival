extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const START_LIFE = 40
const LIFE_DRAIN_PER_SEC = 1.0
const ORB_HEAL = 15.0
const MOUSE_SENSITIVITY = 0.002
const ZOOM_SPEED = 5.0
const FOV_MIN = 50.0
const FOV_MAX = 150.0
const FOV_DEFAULT = 75.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var life: float = START_LIFE
var _drain_accum: float = 0.0
var _game_over: bool = false
var orbs_collected: int = 0
var _held_block: MovableBlock = null

var _snd_jump: AudioStreamPlayer
var _snd_land: AudioStreamPlayer
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


func _ready() -> void:
	_snd_jump = _make_snd("res://sounds/jump.wav", -8.0)
	_snd_land = _make_snd("res://sounds/land.wav", -6.0)
	_snd_step = _make_snd("res://sounds/step.wav", -18.0)
	_snd_grab = _make_snd("res://sounds/grab.wav", -10.0)
	_snd_drop = _make_snd("res://sounds/drop.wav", -10.0)
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = FOV_DEFAULT


@onready var life_label: Label = get_tree().get_first_node_in_group("life_label")
@onready var game_over_label: CanvasItem = get_tree().get_first_node_in_group("game_over_label")
@onready var orb_label: Label = get_tree().get_first_node_in_group("orb_label")
@onready var camera: Camera3D = $Camera3D
@onready var pickup_sound: AudioStreamPlayer = $AudioStreamPlayer
@onready var game_over_sound: AudioStreamPlayer = $GameOverSound
@onready var fade_in: CanvasLayer = get_node_or_null("../FadeIn")

var _input_locked := false

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
			_toggle_grab()

	# ESC frees the mouse (or triggers restart during game over).
	if event.is_action_pressed("ui_cancel"):
		if _game_over:
			_restart()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	if _game_over:
		return
	life = maxf(life - amount, 0.0)
	if life <= 0.0:
		_trigger_game_over()
	else:
		_update_hud()


func heal(amount: float) -> void:
	life += amount
	orbs_collected += 1
	if pickup_sound:
		pickup_sound.play()
	_update_hud()


func _trigger_game_over() -> void:
	_game_over = true
	velocity = Vector3.ZERO
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
	orbs_collected = 0
	velocity = Vector3.ZERO
	camera.fov = FOV_DEFAULT
	# Respawn at the game's starting point on the SW cape.
	var island = load("res://world/island.gd")
	var spawn: Vector3 = island.spawn_point()
	global_position = spawn + Vector3(0.0, 0.5, 0.0)   # small clearance so we land, not clip
	if game_over_label:
		game_over_label.visible = false
	# Re-capture mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Respawn all orbs.
	for orb in get_tree().get_nodes_in_group("orb"):
		orb.respawn()
	_update_hud()


func _update_hud() -> void:
	if life_label:
		life_label.text = "Life: %d" % int(ceil(life))
	if orb_label:
		orb_label.text = "Sunbulbs: %d" % orbs_collected
