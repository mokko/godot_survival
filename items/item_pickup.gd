extends Area3D
## Generic item pickup: walks into it and it goes to the first free
## inventory slot. Item id is set by the scene/script that places it.

const ItemDB := preload("res://items/item_db.gd")

@export var item_id: String = "flint"

var _collected := false


func _ready() -> void:
	_apply_look()
	body_entered.connect(_on_body_entered)


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
