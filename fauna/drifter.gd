extends "res://fauna/fauna_base.gd"
## Lantern Drifter — slow wind drift + vertical bob, ignores the player
## (fauna/animals.md #3). Softly steers back toward the wetlands when it drifts
## over the coast or out to sea.
## Provoked: the tendrils reach — it drifts at you and sinks to head height.

const Island := preload("res://world/island.gd")

const DRIFT_SPEED := 0.5
const WIND_TURN := 0.02  # rad/s, each drifter has its own slowly turning wind
const SINK_SPEED := 2.0  # m/s it drops toward the player once provoked

var _angle := 0.0
var _alt_base := 3.0
var _rng := RandomNumberGenerator.new()


func species_name() -> String:
	return "Lantern Drifter"


func aggro_speed() -> float:
	return 3.0   ## six times its drift: a provoked drifter is a different animal

func aggro_damage() -> float:
	return 3.0

func aggro_cooldown() -> float:
	return 1.6

func aggro_reach() -> float:
	return 1.6


func _aggro_move(delta: float, player: Node3D, _dist: float) -> void:
	## The wind itself turns on the player: point the drift straight at them and
	## drop to just above head height. Nothing to snap back afterwards — the
	## ambient drift simply carries on in this direction.
	var away := Vector2(player.global_position.x - global_position.x,
			player.global_position.z - global_position.z)
	if away.length() > 0.05:
		_angle = atan2(away.y, away.x)
	var dir := Vector3(cos(_angle), 0.0, sin(_angle))
	var p := global_position + dir * aggro_speed() * delta
	p.y = move_toward(global_position.y, player.global_position.y + 1.1, SINK_SPEED * delta)
	global_position = p
	_face(dir)


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_angle = _rng.randf() * TAU
	_alt_base = _rng.randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
	if aggro_frame(delta):
		return   # the fight owns the frame; no ambient drift while it lasts
	_angle += WIND_TURN * delta
	var dir := Vector3(cos(_angle), 0.0, sin(_angle))
	var p := global_position + dir * DRIFT_SPEED * delta

	# Soft steer back toward the wetlands near/over the coast.
	var s := Island.signed_distance(Vector2(p.x, p.z))
	if s < 2.0:
		var home: Vector2 = Island.BIOMES["wetlands"][0][0]
		var back := Vector3(home.x - p.x, 0.0, home.y - p.z)
		if back.length_squared() > 0.01:
			dir = (dir + back.normalized()).normalized()
			p = global_position + dir * DRIFT_SPEED * delta

	p.y = Island.height_at(p.x, p.z) + _alt_base \
			+ sin(Time.get_ticks_msec() * 0.0015 + _angle) * 0.3
	global_position = p
	if dir.length_squared() > 0.0001:
		var look := p + dir
		if p.distance_squared_to(look) > 0.0001:
			look_at(look, Vector3.UP)

