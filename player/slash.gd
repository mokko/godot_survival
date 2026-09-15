extends Node3D
## Katana slash: an arc sweep of the equipped blade prop. Plays a short
## swing animation on the sword (and a trail arc mesh), damages destroyables
## in a cone in front of the drone at the moment of mid-swing.

# Damage, range and cone angle live in player/combat.gd. This script only
# plays the swing animation and fires the damage callback it is handed.

var _swinging := false
var _t := 0.0
var _sword_pivot: Node3D = null
var _trail: MeshInstance3D = null
var _hit_done := false
var _damage_callback: Callable


func setup(sword_pivot: Node3D, trail: MeshInstance3D, damage_callback: Callable) -> void:
	_sword_pivot = sword_pivot
	_trail = trail
	_damage_callback = damage_callback
	if _trail:
		_trail.visible = false


func can_slash() -> bool:
	return _sword_pivot != null and not _swinging


func slash() -> void:
	if not can_slash():
		return
	_swinging = true
	_t = 0.0
	_hit_done = false
	if _trail:
		_trail.visible = true


func _process(delta: float) -> void:
	if not _swinging:
		return
	_t += delta / 0.35   # 0.35 s swing
	var t: float = minf(_t, 1.0)
	# Wind up (-0.9 rad) then sweep through to +0.9 rad.
	if _sword_pivot:
		_sword_pivot.rotation.y = -0.9 + t * 1.8
	# Trail fades in/out over the swing.
	if _trail:
		var mat := _trail.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 0.55 * sin(t * PI)
	# Damage lands at mid-swing.
	if not _hit_done and t >= 0.5:
		_hit_done = true
		if _damage_callback.is_valid():
			_damage_callback.call()
	if _t >= 1.0:
		_swinging = false
		if _sword_pivot:
			_sword_pivot.rotation.y = 0.0
		if _trail:
			_trail.visible = false
