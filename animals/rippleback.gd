extends Node3D
## Rippleback — the caldera mystery (animals.md #6). Swims a rounded-triangle
## loop under the lake surface; every 40-70 s surfaces for 5 s, then dives.
## Pure ambiance: never interacts with the player.

const Island := preload("res://island.gd")

const SWIM_SPEED := 2.0
const SWIM_Y := -1.2
const SURFACE_Y := -0.15
const LOOP_WAYPOINTS := 3

var _waypoints: Array[Vector3] = []
var _wp := 0
var _surfaced := false
var _surfacing := false
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	var center: Vector2 = Island.CALDERA_CENTER
	var radius: float = Island.LAKE_RADIUS - 2.0
	var a0 := _rng.randf() * TAU
	for i in LOOP_WAYPOINTS:
		var a := a0 + TAU * float(i) / float(LOOP_WAYPOINTS)
		_waypoints.append(Vector3(
				center.x + cos(a) * radius, SWIM_Y, center.y + sin(a) * radius))
	global_position = _waypoints[0]
	_timer = _rng.randf_range(40.0, 70.0)


func _physics_process(delta: float) -> void:
	if _surfacing or _surfaced:
		_timer -= delta
		var target_y := SURFACE_Y if _surfacing else SWIM_Y
		global_position.y = move_toward(global_position.y, target_y, delta * 1.2)
		if _surfacing and global_position.y <= SURFACE_Y + 0.01:
			_surfacing = false
			_surfaced = true
			_timer = 5.0
		elif _surfaced and _timer <= 0.0:
			_surfaced = false  # dive back down; loop resumes below
		return

	_timer -= delta
	if _timer <= 0.0:
		_surfacing = true
		return

	var target := _waypoints[_wp]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_wp = (_wp + 1) % _waypoints.size()
		return
	var dir := to.normalized()
	var p := global_position + dir * SWIM_SPEED * delta
	p.y = SWIM_Y + sin(Time.get_ticks_msec() * 0.001) * 0.1
	global_position = p
	var look := p + dir
	if p.distance_squared_to(look) > 0.0001:
		look_at(look, Vector3.UP)
