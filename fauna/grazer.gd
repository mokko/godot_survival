extends Node3D
## Velvetback Grazer — wander-flee NPC (fauna/animals.md #1).
## IDLE 2-6 s -> walk to a nearby point 3-8 units away -> repeat.
## Player within 6 units: flee directly away at 2x walk speed for 4 s.

const Island := preload("res://world/island.gd")

const WALK_SPEED := 2.0
const FLEE_SPEED := 4.0
const FLEE_RADIUS := 6.0
const FLEE_TIME := 4.0
const BODY_Y := 0.55

enum State { IDLE, WALK, FLEE }

var _state: int = State.IDLE
var _timer := 2.0
var _target := Vector3.ZERO
var _flee_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_timer = _rng.randf_range(1.0, 5.0)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var dist := INF
	if player:
		dist = Vector2(global_position.x, global_position.z).distance_to(
				Vector2(player.global_position.x, player.global_position.z))
	match _state:
		State.IDLE:
			_timer -= delta
			if player and dist < FLEE_RADIUS:
				_start_flee()
			elif _timer <= 0.0:
				_state = State.WALK
				var a := _rng.randf() * TAU
				var r := _rng.randf_range(3.0, 8.0)
				_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		State.WALK:
			if player and dist < FLEE_RADIUS:
				_start_flee()
				return
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.3:
				_state = State.IDLE
				_timer = _rng.randf_range(2.0, 6.0)
			else:
				_move(to.normalized(), WALK_SPEED, delta)
		State.FLEE:
			_flee_left -= delta
			if player:
				var away := global_position - player.global_position
				away.y = 0.0
				if away.length() > 0.01:
					_move(away.normalized(), FLEE_SPEED, delta)
			if _flee_left <= 0.0:
				_state = State.IDLE
				_timer = _rng.randf_range(2.0, 6.0)


func _start_flee() -> void:
	_state = State.FLEE
	_flee_left = FLEE_TIME


func _move(dir: Vector3, speed: float, delta: float) -> void:
	var p := global_position + dir * speed * delta
	p.y = Island.height_at(p.x, p.z) + BODY_Y
	global_position = p
	if dir.length_squared() > 0.0001:
		var look := global_position + dir
		if global_position.distance_squared_to(look) > 0.0001:
			look_at(look, Vector3.UP)
