extends Node3D
## Lantern Drifter — slow wind drift + vertical bob, ignores the player
## (animals.md #3). Softly steers back toward the wetlands when it drifts
## over the coast or out to sea.

const Island := preload("res://world/island.gd")

const DRIFT_SPEED := 0.5
const WIND_TURN := 0.02  # rad/s, each drifter has its own slowly turning wind

var _angle := 0.0
var _alt_base := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_angle = _rng.randf() * TAU
	_alt_base = _rng.randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
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
