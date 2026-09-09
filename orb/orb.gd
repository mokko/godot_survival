extends Area3D

const RESPAWN_DELAY: float = 5.0
const MAP_RADIUS: float = 90.0

var _base_y: float
var _respawn_timer: float = 0.0
var _waiting: bool = false


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _waiting:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# Gentle spin and bob for visual appeal.
	rotation.y += delta * 2.0
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.002) * 0.15


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.heal(body.ORB_HEAL)
		# Hide and disable, start respawn timer.
		visible = false
		$CollisionShape3D.set_deferred("disabled", true)
		_waiting = true
		_respawn_timer = RESPAWN_DELAY


func respawn() -> void:
	_waiting = false
	visible = true
	$CollisionShape3D.set_deferred("disabled", false)
	_move_to_random_position()


func _respawn() -> void:
	respawn()


func _move_to_random_position() -> void:
	var angle := randf() * TAU
	var dist := sqrt(randf()) * MAP_RADIUS
	position.x = cos(angle) * dist
	position.z = sin(angle) * dist
	_base_y = position.y
