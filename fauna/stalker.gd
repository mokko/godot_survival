extends "res://items/destroyable.gd"
## Dusk Stalker — patrol-chase NPC (fauna/animals.md #5). The island's only real
## danger. Patrols 2 points inside a territory; chases the player when they
## are within sight radius AND inside the territory; contact does damage
## with a grace cooldown; gives up outside territory or after CHASE_TIME.

const Island := preload("res://world/island.gd")

const PATROL_SPEED := 2.0
const CHASE_SPEED := 7.5
const SIGHT_RADIUS := 10.0
const TERRITORY_RADIUS := 30.0
const CHASE_TIME := 8.0
const CONTACT_RANGE := 1.2
const DAMAGE := 5.0
const HIT_COOLDOWN := 1.0
const BODY_Y := 0.5
const PATROL_SPAN := 9.0   ## metres between the two patrol legs
const ATTACK_RANGE := 1.9  ## inside this, it stops and winds up a bite
const WINDUP_TIME := 0.4   ## the telegraph: long enough to back out
const HIT_SLACK := 0.6     ## the bite still lands if you are this close
const FLASH_TIME := 0.18   ## white-hot hit flash on the body

enum State { PATROL, CHASE, RETURN, WINDUP }

var territory_center := Vector2.ZERO  ## set by the spawner, else adopted
var patrol_a := Vector3.ZERO
var patrol_b := Vector3.ZERO

var _state: int = State.PATROL
var _target := Vector3.ZERO
var _patrol_t := 0.0   # 0..1 leg progress toward patrol_b
var _chase_left := 0.0
var _hit_cd := 0.0
var _windup := 0.0      ## counts down while the bite is telegraphed
var _flash := 0.0       ## counts down while the body is flash-lit
var _rng := RandomNumberGenerator.new()

var _body_mesh: MeshInstance3D = null
var _snd_growl: AudioStreamPlayer = null
var _snd_hit: AudioStreamPlayer = null
const GROWL := preload("res://sounds/growl.wav")
const BITE := preload("res://sounds/hit.wav")


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	if not is_configured():
		# Hand-placed in the editor, or baked by an older spawner that never set
		# a territory: adopt wherever we are standing. Without this every
		# stalker in the shipped world treated world origin as home and simply
		# walked there, so the one enemy in the game never actually hunted.
		var here := Vector2(global_position.x, global_position.z)
		configure(here, global_position, _patrol_point(here))
	_target = patrol_b
	_body_mesh = get_node_or_null("Body") as MeshInstance3D
	if _body_mesh != null and _body_mesh.material_override is StandardMaterial3D:
		# Own copy: the hit flash writes emission, and the shared sub-resource
		# would light up every stalker in the scene at once.
		_body_mesh.material_override = (_body_mesh.material_override as StandardMaterial3D).duplicate()
	_snd_growl = _make_snd(GROWL)
	_snd_hit = _make_snd(BITE)


func _make_snd(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


func is_configured() -> bool:
	return territory_center != Vector2.ZERO or patrol_a != Vector3.ZERO \
			or patrol_b != Vector3.ZERO


func configure(center: Vector2, a: Vector3, b: Vector3) -> void:
	## Claim a territory and two patrol legs. Called by the spawner (before or
	## after _ready) and by _ready's fallback.
	territory_center = center
	patrol_a = a
	patrol_b = b
	_target = b
	_state = State.PATROL
	_patrol_t = 0.0
	_chase_left = 0.0


func state_name() -> String:
	## Readable state for tests and debug output.
	match _state:
		State.CHASE:
			return "CHASE"
		State.RETURN:
			return "RETURN"
		State.WINDUP:
			return "WINDUP"
		_:
			return "PATROL"


func _patrol_point(center: Vector2) -> Vector3:
	## A second patrol leg PATROL_SPAN out, searched in deterministic directions
	## so a stalker never patrols into the sea.
	var r := RandomNumberGenerator.new()
	r.seed = 20260907 + str(name).hash()
	var base := r.randf() * TAU
	for i in 8:
		var ang: float = base + i * TAU / 8.0
		var p := center + Vector2(cos(ang), sin(ang)) * PATROL_SPAN
		if Island.is_land(p.x, p.y):
			return Vector3(p.x, Island.height_at(p.x, p.y) + BODY_Y, p.y)
	return Vector3(center.x, Island.height_at(center.x, center.y) + BODY_Y, center.y)


func _physics_process(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_tick_flash(delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var dist := INF
	if player:
		dist = Vector2(global_position.x, global_position.z).distance_to(
				Vector2(player.global_position.x, player.global_position.z))
	var in_territory := territory_center.distance_to(
			Vector2(player.global_position.x, player.global_position.z)) \
			<= TERRITORY_RADIUS if player else false

	match _state:
		State.PATROL:
			if player and dist < SIGHT_RADIUS and in_territory:
				_start_chase()
			else:
				_patrol_t += delta * PATROL_SPEED / 15.0
				if _patrol_t >= 1.0:
					_patrol_t = 0.0
					_target = patrol_b if _target == patrol_a else patrol_a
				_steer_to(_target, PATROL_SPEED, delta)
		State.CHASE:
			_chase_left -= delta
			if player and in_territory and _chase_left > 0.0:
				_steer_to(player.global_position, CHASE_SPEED, delta)
				# No instant damage: stop, telegraph, then bite. The player can
				# read the wind-up and walk out of reach.
				if dist < ATTACK_RANGE and _hit_cd <= 0.0:
					_begin_windup()
			else:
				_state = State.RETURN
		State.WINDUP:
			_windup -= delta
			_body_lunge(1.0 - _windup / WINDUP_TIME)
			if player:
				_steer_to(player.global_position, PATROL_SPEED, delta)
			if _windup <= 0.0:
				_bite(player, dist)
		State.RETURN:
			if player and dist < SIGHT_RADIUS and in_territory:
				_start_chase()
			elif _arrive_home():
				_state = State.PATROL


func _start_chase() -> void:
	_state = State.CHASE
	_chase_left = CHASE_TIME
	if _snd_growl != null:
		_snd_growl.play()   # aggro cue: you are being hunted


func _begin_windup() -> void:
	_state = State.WINDUP
	_windup = WINDUP_TIME


func _bite(player: Node3D, dist: float) -> void:
	## The telegraph has elapsed: land the bite if the player is still close.
	if player != null and dist <= ATTACK_RANGE + HIT_SLACK:
		player.damage(DAMAGE)
		if _snd_hit != null:
			_snd_hit.play()
	_hit_cd = HIT_COOLDOWN
	_body_lunge(0.0)
	_state = State.CHASE


func _body_lunge(t: float) -> void:
	## Shove the body forward (-Z is forward) so the bite visibly reaches.
	if _body_mesh != null:
		_body_mesh.position.z = -0.1 - 0.3 * maxf(0.0, t)


func _tick_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(_flash - delta, 0.0)
	if _body_mesh == null or not (_body_mesh.material_override is StandardMaterial3D):
		return
	var mat: StandardMaterial3D = _body_mesh.material_override
	mat.emission_enabled = _flash > 0.0
	mat.emission = Color(1.0, 0.85, 0.6)
	mat.emission_energy_multiplier = 4.0 * (_flash / FLASH_TIME)


func damage(amount: float) -> void:
	## Being hit is now legible: white flash on the body plus a shove away from
	## whoever swung, so a landed hit reads as a hit even from behind.
	super.damage(amount)
	if is_queued_for_deletion() or life <= 0.0:
		# Dead: no flash and no shove, so the death puff stays where it fell
		# (and so knockback cannot carry a corpse away from its own corpse).
		return
	_flash = FLASH_TIME
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		knockback_from(player.global_position, 1.4)


func _steer_to(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var dir := to.normalized()
	var p := global_position + dir * speed * delta
	# Stalkers never step into the sea.
	if Island.height_at(p.x, p.z) < Island.WATER_LEVEL + 0.3:
		return
	p.y = Island.height_at(p.x, p.z) + BODY_Y
	global_position = p
	var look := global_position + dir
	if global_position.distance_squared_to(look) > 0.0001:
		look_at(look, Vector3.UP)


func _arrive_home() -> bool:
	var home := patrol_a if _target == patrol_a else patrol_b
	var to := home - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return true
	_steer_to(home, PATROL_SPEED, get_physics_process_delta_time())
	return false

