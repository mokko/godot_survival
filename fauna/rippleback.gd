extends "res://fauna/fauna_base.gd"
## Rippleback — the caldera mystery (fauna/animals.md #6). Swims a rounded-triangle
## loop under the lake surface; every 40-70 s surfaces for 5 s, then dives.
## Pure ambiance: never interacts with the player.
## Provoked: it comes up and rams — the only animal that fights inside the lake,
## and the only one that cannot follow you out of it.

const Island := preload("res://world/island.gd")

const SWIM_SPEED := 2.0
const SWIM_Y := -1.2
const SURFACE_Y := -0.15
const LOOP_WAYPOINTS := 3
const SURFACE_RISE := 1.2   ## m/s it rises toward the surface when provoked
const EDGE_INSET := 1.5     ## metres it keeps inside the lake shore

var _waypoints: Array[Vector3] = []
var _wp := 0
var _surfaced := false
var _surfacing := false
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func species_name() -> String:
	return "Rippleback"


func aggro_speed() -> float:
	return 5.0   ## more than twice its patrol swim

func aggro_damage() -> float:
	return 8.0   ## whatever it is, it is big

func aggro_cooldown() -> float:
	return 2.0

func aggro_reach() -> float:
	return 2.4


func _aggro_move(delta: float, player: Node3D, _dist: float) -> void:
	## It can only swim, so the charge stays inside the lake and the ram happens at
	## the water's edge — the back plates break the surface, as in its surfacing
	## state. A player who climbs out is simply out of its world (see below).
	var to := player.global_position - global_position
	to.y = 0.0
	var p := global_position
	if to.length() > 0.05:
		p += to.normalized() * aggro_speed() * delta
	var off := Vector2(p.x, p.z) - Island.CALDERA_CENTER
	var limit := Island.LAKE_RADIUS - EDGE_INSET
	if off.length() > limit:
		var edge := Island.CALDERA_CENTER + off.normalized() * limit
		p.x = edge.x
		p.z = edge.y
	p.y = move_toward(global_position.y, SURFACE_Y, SURFACE_RISE * delta)
	global_position = p
	if to.length() > 0.05:
		_face(Vector3(to.x, 0.0, to.z).normalized())


func _cannot_reach(player: Node3D) -> bool:
	## Terrain above the lake surface is dry land: it can never follow you ashore,
	## so the fight ends the moment you climb out.
	var p := player.global_position
	return Island.height_at(p.x, p.z) > Island.LAKE_LEVEL - 0.5


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
	if aggro_frame(delta):
		return   # the fight owns the frame; no lake loop while it lasts
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

