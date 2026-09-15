class_name DestroyableArea
extends Area3D
## Destroyable base for scripts that must stay an Area3D — the flora with
## pickup/hit sensors (sunbulb, thornlash). Mirrors items/destroyable.gd: same
## life total and the same shared death puff, but it cannot extend that script
## because that one is Node3D-based.

## Life total is defined once, in the Node3D base.
var life: float = Destroyable.MAX_LIFE


func _enter_tree() -> void:
	add_to_group("damageable")


func damage(amount: float) -> void:
	life -= amount
	if life <= 0.0:
		Destroyable.spawn_puff(get_parent(), global_position)
		queue_free()