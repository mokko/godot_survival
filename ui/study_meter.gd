extends Control
## The study meter: how far the drone has got drawing the species in front of it.
## Two states, one control:
##
##  - **holding** — a progress bar with "Studying <subject>" over it, while a
##    subject is being examined;
##  - **message** — a single line with no bar ("Drawn: X", "Spotted: X, 12 m",
##    "Kill it with a blade first"), which fades out on its own.
##
## Built in code and parented to the HUD (like the hurt flash and the hit marker),
## so an editor save of world/main.tscn cannot clobber it.

const BAR_SIZE := Vector2(260, 8)
const LABEL_SIZE := Vector2(360, 24)

var subject := ""      ## what is being studied right now
var progress := 0.0    ## seconds held, 0..STUDY_TIME
var total := 1.0       ## STUDY_TIME, handed in by the caller
var message := ""      ## non-empty while a one-line note is showing

var _label: Label = null
var _fade := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = LABEL_SIZE
	# Centred over the bar, not over the control's origin: the name sits above the
	# trough it belongs to.
	_label.position = Vector2((BAR_SIZE.x - LABEL_SIZE.x) * 0.5,
			-LABEL_SIZE.y - 4.0)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE


func set_state(subject_name: String, held: float, total_seconds: float) -> void:
	subject = subject_name
	progress = held
	total = maxf(total_seconds, 0.001)
	message = ""
	_fade = 1.0
	visible = true
	modulate.a = 1.0
	_refresh()


func show_message(text: String) -> void:
	## A note rather than a hold: "Drawn: X", "Spotted: X, 12 m", a refusal.
	message = text
	progress = 0.0
	_fade = 1.0
	visible = true
	modulate.a = 1.0
	_refresh()


func fade_out(delta: float, rate: float) -> void:
	## Notes fade; a hold does not (it is replaced or cancelled by the caller).
	if message == "":
		return
	_fade = maxf(_fade - delta * rate, 0.0)
	modulate.a = _fade
	if _fade <= 0.0:
		visible = false


func _refresh() -> void:
	if _label == null:
		return
	_label.text = message if message != "" else "Studying %s" % subject
	queue_redraw()


func _draw() -> void:
	if message != "":
		return   # a note is words only; a bar under "Spotted" would imply progress
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.16, 0.75), true)
	var fill: float = clampf(progress / total, 0.0, 1.0)
	if fill > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)),
				Color(0.45, 0.85, 0.55), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.8, 0.88, 0.8), false, 1.0)