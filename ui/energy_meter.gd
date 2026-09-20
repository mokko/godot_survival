extends Control
## Robot energy meter — the top-left HUD display: four batteries standing in
## for the drone's charge, the hearts of this game. Each battery is a quarter
## of the tank and is drawn full, half or empty, so "eight half-charges" reads
## at a glance without a number.
##
## Life is pushed in by player._update_hud() on every physics frame, so
## set_energy() only repaints when what is *drawn* changes — the half-battery
## count, not the raw float, or the slow drain would repaint every frame. A
## steady frame must cost nothing (the same rule the HUD labels follow).
##
## The half/full rule lives in the statics so the headless test can check it
## without a renderer.

const BATTERIES := 4
const BODY := Vector2(34.0, 18.0)      ## battery shell, in HUD pixels
const NUB := Vector2(4.0, 8.0)         ## positive terminal on the right
const GAP := 6.0
const ORIGIN := Vector2(12.0, 13.0)    ## where the first battery sits
const OUTLINE_W := 2.0

const SHELL := Color(0.08, 0.09, 0.11)
const EMPTY := Color(0.18, 0.19, 0.23)
const CHARGE := Color(0.35, 0.85, 0.95)     ## the drone's own cyan
const EDGE := Color(0.6, 0.65, 0.7)

var energy := 0.0
var max_energy := 0.0

var _lit := -1   ## half-batteries drawn last time (-1 = nothing drawn yet)


static func filled_halves(value: float, max_value: float) -> int:
	## How many half-batteries are lit, 0 .. BATTERIES*2. Charge rounds UP to
	## the next half-battery — the hearts rule: one point of energy left still
	## shows half a battery, so a battery only reads empty when that quarter of
	## the tank is really gone.
	var half := max_value / float(BATTERIES * 2)
	if half <= 0.0:
		return 0
	return int(ceil(clampf(value, 0.0, max_value) / half))


static func charge_of(value: float, max_value: float, index: int) -> float:
	## How full battery `index` (0-based, left to right) is: 1.0 full, 0.5 half
	## or 0.0 empty.
	return clampf(float(filled_halves(value, max_value) - index * 2) / 2.0, 0.0, 1.0)


func set_energy(value: float, max_value: float) -> void:
	var lit := filled_halves(value, max_value)
	if lit == _lit and max_value == max_energy:
		return
	_lit = lit
	energy = value
	max_energy = max_value
	queue_redraw()


func _draw() -> void:
	for i in BATTERIES:
		var body := Rect2(ORIGIN.x + i * (BODY.x + GAP), ORIGIN.y, BODY.x, BODY.y)
		var inner := body.grow(-OUTLINE_W)
		draw_rect(body, SHELL)
		draw_rect(inner, EMPTY)
		var charge := charge_of(energy, max_energy, i)
		if charge > 0.0:
			# Filled from the bottom: a half battery is half a tank of charge.
			var h: float = inner.size.y * charge
			draw_rect(Rect2(inner.position.x, inner.end.y - h, inner.size.x, h), CHARGE)
		draw_rect(body, EDGE, false, OUTLINE_W)
		# Positive terminal: what makes the shape read as a battery rather
		# than a health bar.
		var nub := Rect2(body.end.x, body.position.y + (BODY.y - NUB.y) * 0.5,
				NUB.x, NUB.y)
		draw_rect(nub, SHELL)
		draw_rect(nub, EDGE, false, OUTLINE_W)
