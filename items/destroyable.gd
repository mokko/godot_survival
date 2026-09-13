class_name Destroyable
extends Node3D
## Base for anything with 50 life points that can be destroyed by arrows:
## dies in a puff of smoke with a flopp sound when life hits 0.
## Flora/fauna scripts extend this instead of Node3D directly.

const MAX_LIFE := 50.0
const DeathPuff := preload("res://items/death_puff.tscn")

var life: float = MAX_LIFE


func _enter_tree() -> void:
	add_to_group("damageable")


func damage(amount: float) -> void:
	life -= amount
	if life <= 0.0:
		_die()


func _die() -> void:
	## Default death: puff of smoke + flopp where we stood, then vanish.
	var pos := global_position
	var puff: Node3D = DeathPuff.instantiate()
	if get_parent():
		get_parent().add_child(puff)
		puff.global_position = pos
	queue_free()
