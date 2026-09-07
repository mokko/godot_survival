extends Area3D
## Sunbulb — the heal pickup (plants.md #2). Mirrors orb.gd: hide + disable
## + timed respawn at a new nearby spot on dry, vegetated ground.

const Island := preload("res://island.gd")

const RESPAWN_DELAY: float = 5.0
const MIN_INLAND := 3.0  # signed-distance: stay off the beach band

var _respawn_timer: float = 0.0
var _waiting: bool = false
var _rng := RandomNumberGenerator.new()
var _bulb_mesh: MeshInstance3D


func _ready() -> void:
	_rng.seed = 20260906 + str(name).hash()
	_bulb_mesh = get_node_or_null("Bulb")
	# Sub-resources are shared between instances — duplicate so picking one
	# bulb doesn't dim every bulb on the island.
	if _bulb_mesh and _bulb_mesh.material_override:
		_bulb_mesh.material_override = _bulb_mesh.material_override.duplicate()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _waiting:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.heal(body.ORB_HEAL)
		visible = false
		$CollisionShape3D.set_deferred("disabled", true)
		_waiting = true
		_respawn_timer = RESPAWN_DELAY
		if _bulb_mesh:
			_set_glow(false)


func respawn() -> void:
	_waiting = false
	visible = true
	$CollisionShape3D.set_deferred("disabled", false)
	if _bulb_mesh:
		_set_glow(true)
	_move_to_new_spot()


func _move_to_new_spot() -> void:
	for _attempt in 25:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(10.0, 30.0)
		var np := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if Island.is_land(np.x, np.z) \
				and Island.signed_distance(Vector2(np.x, np.z)) > MIN_INLAND:
			np.y = Island.height_at(np.x, np.z)
			global_position = np
			return
	# Keep old position as fallback.


func _set_glow(on: bool) -> void:
	var mesh := _bulb_mesh as MeshInstance3D
	if mesh == null:
		return
	var mat := mesh.material_override as StandardMaterial3D
	if mat:
		mat.emission_enabled = on
