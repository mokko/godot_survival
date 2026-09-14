extends Control
## Procedural sunrise background for the splash/main-menu screen.
## Draws a sky gradient, a sun that slowly rises out of the ocean, and
## gently animated wave bands. Quiet by design: no audio, slow motion.

const RISE_SECONDS := 90.0   # sun takes this long to clear the horizon
const HOLD_SECONDS := 30.0   # then hangs there for a while
const FADE_SECONDS := 12.0   # then fades out and the cycle restarts

const SKY_TOP := Color(0.10, 0.15, 0.28)
const SKY_HORIZON := Color(0.75, 0.55, 0.42)
const SUN_COLOR := Color(1.0, 0.78, 0.45)
const SEA_DARK := Color(0.07, 0.11, 0.20)
const SEA_LIGHT := Color(0.35, 0.40, 0.52)
const WAVE_COLOR := Color(0.85, 0.70, 0.55, 0.35)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _cycle_time() -> float:
	var total := RISE_SECONDS + HOLD_SECONDS + FADE_SECONDS
	return fmod(_time, total)


func _sun_progress() -> float:
	## 0 = sun fully below horizon, 1 = sun at its resting height.
	var t := _cycle_time()
	if t < RISE_SECONDS:
		# ease-out so the rise feels unhurried at the end
		var u := t / RISE_SECONDS
		return 1.0 - pow(1.0 - u, 2.0)
	if t < RISE_SECONDS + HOLD_SECONDS:
		return 1.0
	# during fade the sun stays put but the whole scene dims
	return 1.0


func _dim() -> float:
	var t := _cycle_time()
	var fade_start := RISE_SECONDS + HOLD_SECONDS
	if t < fade_start:
		return 1.0
	return 1.0 - (t - fade_start) / FADE_SECONDS


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.62
	var dim := _dim()

	# --- sky gradient ---
	var steps := 32
	for i in steps:
		var y0 := horizon * float(i) / steps
		var y1 := horizon * float(i + 1) / steps
		var c := SKY_TOP.lerp(SKY_HORIZON, float(i) / (steps - 1))
		c.a = dim
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), c, true)

	# --- sun ---
	var prog := _sun_progress()
	var sun_r := minf(w, h) * 0.07
	var sun_y := horizon + sun_r * 1.2 - prog * sun_r * 3.6
	var sun_x := w * 0.5
	# glow: layered translucent discs
	for gi in 4:
		var gr := sun_r * (1.6 + gi * 0.9)
		var gc := SUN_COLOR
		gc.a = (0.10 - gi * 0.02) * dim
		draw_circle(Vector2(sun_x, sun_y), gr, gc)
	# disc (clipped so it looks submerged while below the horizon)
	var disc_c := SUN_COLOR
	disc_c.a = dim
	draw_circle(Vector2(sun_x, sun_y), sun_r, disc_c)
	# clip the below-horizon part of the sun by redrawing the sea over it

	# --- sun reflection column on the water ---
	var refl_c := SUN_COLOR
	refl_c.a = 0.18 * dim * prog
	var refl_w := sun_r * 0.7
	draw_rect(Rect2(sun_x - refl_w * 0.5, horizon, refl_w, h - horizon), refl_c, true)

	# --- sea ---
	var sea_steps := 24
	for i in sea_steps:
		var f := float(i) / (sea_steps - 1)
		var y0 := horizon + (h - horizon) * f
		var y1 := horizon + (h - horizon) * float(i + 1) / sea_steps
		var c := SEA_LIGHT.lerp(SEA_DARK, f)
		c.a = dim
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), c, true)

	# --- waves: shimmering horizontal strokes ---
	var rows := 14
	for row in rows:
		var f := float(row) / (rows - 1)
		var y := horizon + (h - horizon) * (f * f * 0.9 + 0.04)
		var amp := 1.5 + f * 5.0
		var speed := 0.6 + f * 1.2
		var n_dashes := 6 + int(f * 8.0)
		var dash_w := w / n_dashes
		for d in n_dashes:
			var phase := _time * speed + d * 1.7 + row * 2.3
			var x := d * dash_w + sin(phase) * dash_w * 0.25
			var yy := y + cos(phase * 0.8) * amp
			var c := WAVE_COLOR
			c.a = WAVE_COLOR.a * dim * (0.4 + 0.6 * (0.5 + 0.5 * sin(phase * 1.3)))
			draw_line(Vector2(x, yy), Vector2(x + dash_w * 0.45, yy), c, 1.0 + f * 2.0)
