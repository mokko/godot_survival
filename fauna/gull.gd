extends "res://fauna/fauna_base.gd"
## Windvane Gull — orbits a fixed anchor point (fauna/animals.md #4).
## Never lands; flocks circle landmarks (massif, caldera). The integrator
## sets anchor / orbit_radius / orbit_height / angular_speed per gull.
## Provoked: it stoops — see fauna/fauna_base.gd.

const Island := preload("res://world/island.gd")

@export var anchor := Vector2.ZERO  ## (x, z) of the orbit center
@export var orbit_radius := 30.0
@export var angular_speed := 0.12  ## rad/s — linear speed ~3 at r=25
@export var orbit_height := 14.0

var _angle := 0.0


func species_name() -> String:
	return "Windvane Gull"


func aggro_speed() -> float:
	return 9.0   ## a stoop, not a stroll

func aggro_damage() -> float:
	return 4.0

func aggro_cooldown() -> float:
	return 1.5

func aggro_reach() -> float:
	return 1.8


func _aggro_move(delta: float, player: Node3D, _dist: float) -> void:
	## Come down to just above the player's head and stay on them. It still never
	## lands: the swoop is the whole gesture.
	var target := player.global_position + Vector3(0.0, 0.8, 0.0)
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if to.length() > 0.05:
		global_position += to.normalized() * aggro_speed() * delta
		_face(to.normalized())
	global_position.y = move_toward(global_position.y, target.y, aggro_speed() * 0.7 * delta)


func _on_calm() -> void:
	## Rejoin the orbit at the nearest point of its circle rather than snapping
	## back to wherever the fight found it.
	_angle = atan2(global_position.z - anchor.y, global_position.x - anchor.x)


func _ready() -> void:
	_angle = randf() * TAU  # phase only; placement stays deterministic


func _physics_process(delta: float) -> void:
	if aggro_frame(delta):
		return   # the fight owns the frame; no orbit while it lasts
	_angle += angular_speed * delta
	var p := Vector3(
			anchor.x + cos(_angle) * orbit_radius,
			0.0,
			anchor.y + sin(_angle) * orbit_radius)
	p.y = maxf(Island.height_at(p.x, p.z) + 8.0, orbit_height) \
			+ sin(Time.get_ticks_msec() * 0.001 + _angle * 3.0) * 0.4
	var next := Vector3(
			anchor.x + cos(_angle + 0.05) * orbit_radius,
			p.y,
			anchor.y + sin(_angle + 0.05) * orbit_radius)
	global_position = p
	if p.distance_squared_to(next) > 0.0001:
		look_at(next, Vector3.UP)

