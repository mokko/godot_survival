extends Node3D
## Death puff: expanding gray smoke spheres + flopp sound; frees itself.

const LIFE := 0.8

var _t := 0.0

@onready var _snd: AudioStreamPlayer = $Sound


func _ready() -> void:
	if _snd:
		_snd.play()


func _process(delta: float) -> void:
	_t += delta
	var s: float = 0.5 + _t * 3.0
	for child in get_children():
		if child is MeshInstance3D:
			child.scale = Vector3.ONE * s
			var m := child as MeshInstance3D
			if m.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = (m.material_override as StandardMaterial3D).duplicate()
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = maxf(1.0 - _t / LIFE, 0.0)
				m.material_override = mat
	if _t >= LIFE:
		queue_free()
