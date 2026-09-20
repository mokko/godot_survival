extends Control
## The study meter: how far the drone has got drawing the species in front of it.
## A progress bar with the subject's name over it, shown only while something is
## being studied; when the entry is drawn it flips to the confirmation line and
## fades out on its own.
##
## Built in code and parented to the HUD (like the hurt flash and the hit marker),
## so an editor save of world/main.tscn cannot clobber it.

const BAR_SIZE := Vector2(260, 8)
const LABEL_SIZE := Vector2(320, 24)

var subject := ""        ## what is being studied right now
var progress := 0.0      ## seconds held, 0..STUDY_TIME
var total := 1.0         ## STUDY_TIME, handed in by the caller
var done_text := ""      ## non-empty while the "Drawn!" line is showing

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
	done_text = ""
	_fade = 1.0
	visible = true
	_refresh()


func show_done(subject_name: String) -> void:
	subject = subject_name
	progress = total
	done_text = "Drawn: %s" % subject_name
	_fade = 1.0
	visible = true
	_refresh()


func fade_out(delta: float, rate: float) -> void:
	## Dim after the "Drawn!" line has had its moment; hides at zero.
	if done_text == "":
		return
	_fade = maxf(_fade - delta * rate, 0.0)
	modulate.a = _fade
	if _fade <= 0.0:
		visible = false


func _refresh() -> void:
	if _label == null:
		return
	_label.text = done_text if done_text != "" else "Studying %s" % subject
	queue_redraw()


func _draw() -> void:
	# Frame, dark trough, light fill.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.16, 0.75), true)
	var fill: float = clampf(progress / total, 0.0, 1.0)
	if fill > 0.0:
		var colour := Color(0.45, 0.85, 0.55) if done_text == "" \
				else Color(0.95, 0.85, 0.45)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * fill, size.y)), colour, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.8, 0.88, 0.8), false, 1.0)