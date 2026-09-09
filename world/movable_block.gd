class_name MovableBlock
extends RigidBody3D
## A block the player can grab with the crosshair and move around.
## Left-click on it (aim at it, it must be within GRAB_RANGE) to grab;
## it then floats in front of the camera. Left-click again to release;
## the block keeps its momentum from your movement while held.

const GRAB_RANGE := 5.0          # max distance to grab
const HOLD_DISTANCE := 3.0       # how far in front of the camera it floats
const LERP_SPEED := 12.0         # how snappily it follows the aim point
const MAX_ANGULAR := 4.0         # keep it from spinning wildly while held

var _held_by: Node3D = null      # the camera holding it, or null
var _gravity_scale_backup := 1.0


func _physics_process(delta: float) -> void:
	if _held_by == null:
		return
	# Float at the aim point: HOLD_DISTANCE along the camera's forward ray.
	var target: Vector3 = _held_by.global_position \
			+ _held_by.global_transform.basis.z * -HOLD_DISTANCE
	var to_target := target - global_position
	# Follow with a velocity proportional to the gap — feels like dragging.
	linear_velocity = to_target * LERP_SPEED
	# Damp rotation while held.
	angular_velocity = angular_velocity.limit_length(MAX_ANGULAR * delta * 60.0)


func grab(camera: Node3D) -> void:
	_held_by = camera
	_gravity_scale_backup = gravity_scale
	gravity_scale = 0.0
	freeze = false
	angular_damp = 4.0


func release() -> void:
	if _held_by == null:
		return
	_held_by = null
	gravity_scale = _gravity_scale_backup
	angular_damp = 1.0
	# Keep the velocity it had so you can throw it by moving while released.
