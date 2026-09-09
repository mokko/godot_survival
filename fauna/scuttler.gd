extends Node3D
## Pebble Scuttler — hop-scuttle NPC, body always facing the player
## (fauna/animals.md #2). Picks a random point 2-5 units away, scuttles sideways
## to it with a little hop, pauses, repeats. Flees within 3 units.

const Island := preload("res://world/island.gd")

const WALK_SPEED := 1.5
const FLEE_SPEED := 4.5
const FLEE_RADIUS := 3.0
const BODY_Y := 0.25

var _target := Vector3.ZERO
var _moving := false
var _pause := 1.0
var _hop_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_pause = _rng.randf_range(1.0, 3.0)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D

	# A crab always faces the player (yaw only).
	if player:
		var fp := player.global_position
		var face := Vector3(fp.x, global_position.y, fp.z)
		if global_position.distance_squared_to(face) > 0.0001:
			look_at(face, Vector3.UP)

	var dist := INF
	if player:
		dist = Vector2(global_position.x, global_position.z).distance_to(
				Vector2(player.global_position.x, player.global_position.z))

	if player and dist < FLEE_RADIUS:
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.01:
			_step(away.normalized(), FLEE_SPEED, delta)
	elif _moving:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.2:
			_moving = false
			_pause = _rng.randf_range(1.0, 3.0)
		else:
			_step(to.normalized(), WALK_SPEED, delta)
	else:
		_pause -= delta
		if _pause <= 0.0:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(2.0, 5.0)
			_target = global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
			_moving = true


func _step(dir: Vector3, speed: float, delta: float) -> void:
	_hop_t += delta * 8.0
	var p := global_position + dir * speed * delta
	p.y = Island.height_at(p.x, p.z) + BODY_Y + absf(sin(_hop_t)) * 0.08
	global_position = p
