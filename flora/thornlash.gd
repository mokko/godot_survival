extends "res://items/destroyable_area.gd"
## Thornlash — ambush hazard (plants.md #7). Anything warm within 3 units
## takes a lash; then the tendril re-coils and cannot hit again for 3 s.
## Destroyable behaviour (life total, death puff) comes from the base script.

const HIT_COOLDOWN := 3.0
const LASH_DAMAGE := 8.0

var _cooldown := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _cooldown <= 0.0:
		body.damage(LASH_DAMAGE)
		_cooldown = HIT_COOLDOWN

