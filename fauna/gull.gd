extends Node3D
## Windvane Gull — orbits a fixed anchor point (animals.md #4).
## Never lands; flocks circle landmarks (massif, caldera). The integrator
## sets anchor / orbit_radius / orbit_height / angular_speed per gull.

const Island := preload("res://world/island.gd")

@export var anchor := Vector2.ZERO  ## (x, z) of the orbit center
@export var orbit_radius := 30.0
@export var angular_speed := 0.12  ## rad/s — linear speed ~3 at r=25
@export var orbit_height := 14.0

var _angle := 0.0


func _ready() -> void:
	_angle = randf() * TAU  # phase only; placement stays deterministic


func _physics_process(delta: float) -> void:
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
