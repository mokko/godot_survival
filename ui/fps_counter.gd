extends Label
## FPS counter — top-left under Life. Reads show_fps from options.gd every
## frame so toggling in the menu takes effect immediately.

var _enabled: bool = true
var _accum := 0.0
var _frames := 0


func _ready() -> void:
	_enabled = load("res://ui/options.gd").get_option("show_fps")
	visible = _enabled


func _process(delta: float) -> void:
	var opt = load("res://ui/options.gd").get_option("show_fps")
	if opt != _enabled:
		_enabled = opt
		visible = _enabled
	if not _enabled:
		return
	_accum += delta
	_frames += 1
	if _accum >= 0.5:   # update twice a second
		text = "FPS: %d" % roundi(_frames / _accum)
		_accum = 0.0
		_frames = 0
