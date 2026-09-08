extends CanvasLayer
## Fade-in overlay: shown on game start, fades a black ColorRect out over
## FADE_TIME seconds, then disables itself. While fading, the player's
## input is ignored (player checks `input_locked`).

const FADE_TIME := 0.75

@onready var rect: ColorRect = $Rect

var input_locked := true


func _ready() -> void:
	rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, FADE_TIME)
	tween.finished.connect(_on_done)


func _on_done() -> void:
	input_locked = false
	rect.visible = false
	set_process(false)
