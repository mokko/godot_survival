extends Control
## The binocular view: what the drone sees when the binoculars are out. Everything
## outside two circles of vision is dimmed, each circle has a bright rim, and a
## small reticle marks the exact aim point.
##
## The mask is drawn with vertical strips rather than a texture: a circle-shaped
## hole in an overlay cannot be done with four rects, and a 4 px strip is invisible
## at any window size. The camera's own field of view is deliberately left alone —
## the scroll wheel owns that, and two zooms fighting each other reads as a bug.

const DIM := Color(0, 0, 0, 0.72)
const RIM := Color(0.85, 0.92, 1.0, 0.75)
const RIM_GLOW := Color(0.65, 0.85, 1.0, 0.28)
const RETICLE := Color(0.9, 0.96, 1.0, 0.8)

const TUBE_GAP := 0.42   ## distance between tube centres, as a fraction of radius
const STRIP := 4.0       ## px width of the mask strips
const VIEW_RADIUS := 0.34  ## of the viewport height


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * VIEW_RADIUS
	var gap := radius * TUBE_GAP
	var centres := [
		Vector2(size.x * 0.5 - gap, size.y * 0.5),
		Vector2(size.x * 0.5 + gap, size.y * 0.5),
	]
	_draw_mask(centres, radius)
	for centre in centres:
		draw_arc(centre, radius, 0.0, TAU, 64, RIM_GLOW, 6.0, true)
		draw_arc(centre, radius, 0.0, TAU, 64, RIM, 1.6, true)
	# Reticle: a small cross where the ray actually goes.
	var mid := Vector2(size.x * 0.5, size.y * 0.5)
	draw_line(mid + Vector2(-9, 0), mid + Vector2(-3, 0), RETICLE, 1.0, true)
	draw_line(mid + Vector2(3, 0), mid + Vector2(9, 0), RETICLE, 1.0, true)
	draw_line(mid + Vector2(0, -9), mid + Vector2(0, -3), RETICLE, 1.0, true)
	draw_line(mid + Vector2(0, 3), mid + Vector2(0, 9), RETICLE, 1.0, true)


func _draw_mask(centres: Array, radius: float) -> void:
	## Column by column: whatever the tubes do not cover is dark. A column outside
	## both circles is dark top to bottom.
	var r2 := radius * radius
	var x := 0.0
	while x < size.x:
		var top := size.y
		var bottom := 0.0
		var covered := false
		for centre in centres:
			var dx: float = x - centre.x
			if absf(dx) > radius:
				continue
			var dy: float = sqrt(maxf(r2 - dx * dx, 0.0))
			top = minf(top, centre.y - dy)
			bottom = maxf(bottom, centre.y + dy)
			covered = true
		if not covered:
			draw_rect(Rect2(x, 0.0, STRIP, size.y), DIM)
		else:
			if top > 0.0:
				draw_rect(Rect2(x, 0.0, STRIP, top), DIM)
			if bottom < size.y:
				draw_rect(Rect2(x, bottom, STRIP, size.y - bottom), DIM)
		x += STRIP