class_name Destroyable
extends Node3D
## Base for anything with 50 life points that can be destroyed by arrows:
## dies in a puff of smoke with a flopp sound when life hits 0.
## Flora/fauna scripts extend this instead of Node3D directly.

const MAX_LIFE := 50.0
const DeathPuff := preload("res://items/death_puff.tscn")

var life: float = MAX_LIFE


static func spawn_puff(parent: Node, pos: Vector3) -> void:
	## Shared death effect. Used by this Node3D base and by the Area3D-based
	## destroyables (items/destroyable_area.gd) so the puff logic lives once.
	var puff: Node3D = DeathPuff.instantiate()
	if parent != null:
		parent.add_child(puff)
		puff.global_position = pos


func _enter_tree() -> void:
	add_to_group("damageable")
	_unfreeze_body()


func _unfreeze_body() -> void:
	## AnimatableBody3D defaults to sync_to_physics = true, which hands the
	## transform to the physics server: the direct global_position writes every
	## fauna script does in _physics_process are then silently discarded, so all
	## six species stood frozen where they spawned (the stalker could never
	## reach the player, the drifter never drifted). Turning the flag off keeps
	## the body solid — it still blocks and pushes the player — while letting
	## the scripts own their own position.
	##
	## The property is set through set() because this base class is a Node3D:
	## naming sync_to_physics directly would be a static "not found" error.
	var node := self as Node3D
	if node is AnimatableBody3D and node.get("sync_to_physics"):
		node.set("sync_to_physics", false)


func damage(amount: float) -> void:
	life -= amount
	if life <= 0.0:
		_die()


func _die() -> void:
	## Default death: puff of smoke + flopp where we stood, then vanish.
	spawn_puff(get_parent(), global_position)
	queue_free()
