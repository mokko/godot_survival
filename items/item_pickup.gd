extends Area3D
## Generic item pickup: walks into it and it goes to the first free
## inventory slot. Item id is set by the scene/script that places it.
##
## **Being in the `pickup` group means a death puts this back**
## (`player/player.gd::_restart` asks every member to `respawn()`). The group is opt-in on
## purpose: a flint shard or a robot part stays picked up, because only the things a death
## should give back are listed. A sunbulb respawns somewhere else on the island
## (`flora/sunbulb.gd`); a sword comes back exactly where it lay.

const ItemDB := preload("res://items/item_db.gd")

@export var item_id: String = "flint"

var _collected := false
## Where the scene placed it. `respawn()` puts it back exactly here — a katana returns to
## its own spot on the cape, not to a random one.
var _home := Transform3D()


func _ready() -> void:
	_home = global_transform
	_apply_look()
	body_entered.connect(_on_body_entered)


func respawn() -> void:
	## Back where it was and collectable again, for the deaths that should not cost the
	## player the walk: the sword on the spawn beach, and anything else the `pickup` group
	## is asked to put back. Idempotent, so a death while it is still lying there is free.
	_collected = false
	global_transform = _home
	visible = true
	$CollisionShape3D.set_deferred("disabled", false)


func _apply_look() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh.material_override.duplicate()
		mat.albedo_color = ItemDB.item_color(item_id)
		mat.emission_enabled = true
		mat.emission = ItemDB.item_color(item_id)
		mat.emission_energy_multiplier = 0.35
		mesh.material_override = mat


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	if not body.has_method("add_item"):
		return
	if body.add_item(item_id):
		_collected = true
		visible = false
		$CollisionShape3D.set_deferred("disabled", true)
