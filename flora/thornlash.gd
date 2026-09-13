extends Area3D
## Destroyable composition: 50 life, dies in a puff (Destroyable is Node3D-based,
## so thornlash reuses its death via a small delegate).
const DestroyableScene := preload("res://items/death_puff.tscn")
var life := 50.0

func _enter_tree() -> void:
	add_to_group("damageable")

func damage(amount: float) -> void:
	life -= amount
	if life <= 0.0:
		var pos := global_position
		var puff: Node3D = DestroyableScene.instantiate()
		if get_parent():
			get_parent().add_child(puff)
			puff.global_position = pos
		queue_free()
## Thornlash — ambush hazard (plants.md #7). Anything warm within 3 units
## takes a lash; then the tendril re-coils and cannot hit again for 3 s.

const HIT_COOLDOWN := 3.0
const DAMAGE := 8.0

var _cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _cooldown <= 0.0:
		body.damage(DAMAGE)
		_cooldown = HIT_COOLDOWN

