extends Node3D
## Dusk Stalker — patrol-chase NPC (animals.md #5). The island's only real
## danger. Patrols 2 points inside a territory; chases the player when they
## are within sight radius AND inside the territory; contact does damage
## with a grace cooldown; gives up outside territory or after CHASE_TIME.

const Island := preload("res://island.gd")

const PATROL_SPEED := 2.0
const CHASE_SPEED := 7.5
const SIGHT_RADIUS := 10.0
const TERRITORY_RADIUS := 30.0
const CHASE_TIME := 8.0
const CONTACT_RANGE := 1.2
const DAMAGE := 5.0
const HIT_COOLDOWN := 1.0
const BODY_Y := 0.5

enum State { PATROL, CHASE, RETURN }

var territory_center := Vector2.ZERO  ## set by the spawner
var patrol_a := Vector3.ZERO
var patrol_b := Vector3.ZERO

var _state: int = State.PATROL
var _target := Vector3.ZERO
var _patrol_t := 0.0   # 0..1 leg progress toward patrol_b
var _chase_left := 0.0
var _hit_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_target = patrol_b


func _physics_process(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)
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
				_state = State.CHASE
				_chase_left = CHASE_TIME
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
				if dist < CONTACT_RANGE and _hit_cd <= 0.0:
					player.damage(DAMAGE)
					_hit_cd = HIT_COOLDOWN
			else:
				_state = State.RETURN
		State.RETURN:
			if player and dist < SIGHT_RADIUS and in_territory:
				_state = State.CHASE
				_chase_left = CHASE_TIME
			elif _arrive_home():
				_state = State.PATROL


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
