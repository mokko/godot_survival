extends Area3D
## Shot arrow: flies along its launch direction with slight drop, sticks
## into whatever it touches (or the ground), despawns after a while.

const SPEED := 30.0
const GRAVITY := 4.0          # mild arc, not full physics
const LIFETIME := 60.0
const DAMAGE := 12.0

var _velocity := Vector3.ZERO
var _stuck := false
var _age := 0.0


func launch(from: Vector3, dir: Vector3) -> void:
	global_position = from
	_velocity = dir.normalized() * SPEED
	# Point the shaft along the flight direction.
	if _velocity.length_squared() > 0.0001:
		look_at(from + _velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _stuck:
		_age += delta
		if _age > LIFETIME:
			queue_free()
		return
	_velocity.y -= GRAVITY * delta
	var motion := _velocity * delta
	global_position += motion
	# Keep the shaft aligned with travel.
	if _velocity.length_squared() > 0.0001:
		var to := global_position + _velocity
		if not global_position.is_equal_approx(to):
			look_at(to, Vector3.UP)


const Destroyable := preload("res://items/destroyable.gd")
const Weapon := preload("res://items/weapon.gd")

const ARROW_DAMAGE := 15.0

func _on_body_entered(body: Node) -> void:
	if _stuck or body.is_in_group("player"):
		return
	_stuck = true
	if body is Destroyable:
		body.damage(ARROW_DAMAGE)
	elif body.has_method("damage"):
		body.damage(ARROW_DAMAGE)   # composed destroyables (Area3D-based flora)
	set_deferred("monitoring", false)
