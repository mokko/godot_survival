extends RefCounted
## The Pedia's plates: one picture per entry, drawn as vector ops through
## ui/vector_art.gd — no image assets, like everything else in this game.
##
## Three sources, in the order they cost effort:
##  - **islands** — the entry's real outline from `world/island.gd`, fitted to the
##    plate (and Ezo gets its caldera lake and the arrival point drawn in), so the
##    picture is the actual map rather than a drawing of one;
##  - **equipment** — `ui/item_icons.gd`, the same art the inventory slot draws,
##    so an item's Pedia page and its icon cannot drift apart;
##  - **plants and animals** — a silhouette authored here in a 0..1 unit square,
##    in the species' own colours.

const VectorArt := preload("res://ui/vector_art.gd")
const ItemIcons := preload("res://ui/item_icons.gd")
const Island := preload("res://world/island.gd")

## Plate palette.
const LAND := Color(0.28, 0.35, 0.24)
const LAND_EDGE := Color(0.55, 0.65, 0.45)
const SEA := Color(0.16, 0.24, 0.34)
const LAKE := Color(0.22, 0.46, 0.56)
const MARKER := Color(0.95, 0.85, 0.45)


static func plate_ops(chapter: String, id: String, size: Vector2) -> Array:
	## Every op the plate draws, in plate pixels. [] for an unknown entry, so a
	## caller can ask for anything and draw what it gets (the coverage test walks
	## every entry in the Pedia, so an id with no plate cannot ship unnoticed).
	## The maps use the whole plate; the species and item art is authored square
	## and centred, so a 300x220 plate does not stretch it 36% wider.
	match chapter:
		"islands":
			return _island_ops(id, size)
		"equipment":
			return _centred(ItemIcons.icon_ops(id, _square(size)), size)
		"plants":
			return _centred(VectorArt.scale_ops(_plant_ops(id), _square(size)), size)
		"animals":
			return _centred(VectorArt.scale_ops(_animal_ops(id), _square(size)), size)
	return []


static func _square(size: Vector2) -> Vector2:
	var side: float = minf(size.x, size.y) * 0.92
	return Vector2(side, side)


static func _centred(ops: Array, size: Vector2) -> Array:
	return VectorArt.translate_ops(ops, (size - _square(size)) * 0.5)


## -------------------------------------------------------------------- islands

static func island_outline(id: String) -> Array:
	## The world-space outline the plate is drawn from — one place to look when
	## world/island.gd changes.
	match id:
		"ezo":
			return Island.OUTLINE
		"honshu":
			return Island.HONSHU_OUTLINE
		"shikoku":
			return Island.SHIKOKU_OUTLINE
		"kyushu":
			return Island.KYUSHU_OUTLINE
	return []


static func _island_ops(id: String, size: Vector2) -> Array:
	var outline: Array = island_outline(id)
	if outline.is_empty():
		return []
	var target := Rect2(Vector2(size.x * 0.07, size.y * 0.07),
			Vector2(size.x * 0.86, size.y * 0.86))
	var transform := VectorArt.fit_transform(outline, target)
	var fitted: PackedVector2Array = VectorArt.fit_points(outline, target)
	var ops: Array = []
	ops.append_array(VectorArt.scanline_fill(fitted, LAND))
	ops.append(VectorArt.polyline(_closed(fitted), LAND_EDGE, 2.0))
	if id == "ezo":
		# Two real features, drawn where the map actually has them: the caldera
		# lake, and the SW cape the drone arrives on (Hakodate in the homage).
		ops.append(VectorArt.circle(
				VectorArt.fit_point(Island.CALDERA_CENTER, transform),
				Island.LAKE_RADIUS * float(transform["scale"]), LAKE))
		ops.append(VectorArt.circle(
				VectorArt.fit_point(Vector2(Island.SPAWN_XZ.x, Island.SPAWN_XZ.y),
						transform), 3.0, MARKER))
	return ops


static func island_distance(id: String, point: Vector2) -> float:
	## World-space distance from a point (x, z) to an island's coastline, 0 when the
	## point is inside the island. Uses the world's own outlines, so "have I reached
	## Honshu" is answered by the same data the terrain is built from.
	var outline: Array = island_outline(id)
	if outline.size() < 3:
		return INF
	if _inside_polygon(outline, point):
		return 0.0
	var best := INF
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		best = minf(best, _segment_distance(point, a, b))
	return best


static func _inside_polygon(points: Array, p: Vector2) -> bool:
	## Ray casting to +x: an odd number of crossings means inside.
	var inside := false
	var j := points.size() - 1
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		if (a.y > p.y) != (b.y > p.y):
			var x: float = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < x:
				inside = not inside
		j = i
	return inside


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _closed(points: PackedVector2Array) -> Array:
	## draw_polyline does not close the loop; draw_colored_polygon does.
	var out: Array = []
	for p in points:
		out.append(p)
	if points.size() > 0:
		out.append(points[0])
	return out


## --------------------------------------------------------------------- plants

static func _plant_ops(id: String) -> Array:
	match id:
		"windsinger":
			return [
				_poly([_p(0.42, 0.96), _p(0.58, 0.96), _p(0.53, 0.24), _p(0.47, 0.24)],
						Color(0.36, 0.28, 0.22)),
				_line(_p(0.5, 0.24), _p(0.24, 0.08), Color(0.42, 0.36, 0.3), 0.02),
				_line(_p(0.5, 0.24), _p(0.36, 0.04), Color(0.42, 0.36, 0.3), 0.02),
				_line(_p(0.5, 0.24), _p(0.5, 0.02), Color(0.42, 0.36, 0.3), 0.02),
				_line(_p(0.5, 0.24), _p(0.64, 0.04), Color(0.42, 0.36, 0.3), 0.02),
				_line(_p(0.5, 0.24), _p(0.76, 0.08), Color(0.42, 0.36, 0.3), 0.02),
				_line(_p(0.44, 0.46), _p(0.56, 0.46), Color(0.75, 0.9, 1.0), 0.025),
				_line(_p(0.44, 0.62), _p(0.56, 0.62), Color(0.75, 0.9, 1.0), 0.025),
				_line(_p(0.44, 0.78), _p(0.56, 0.78), Color(0.75, 0.9, 1.0), 0.025),
			]
		"sunbulb":
			return [
				_poly([_p(0.5, 0.86), _p(0.84, 0.94), _p(0.16, 0.94)],
						Color(0.26, 0.24, 0.2)),
				_circle(_p(0.5, 0.62), 0.26, Color(0.95, 0.55, 0.18)),
				_ring(_p(0.5, 0.62), 0.3, Color(1.0, 0.72, 0.35, 0.5), 0.03),
				# A highlight on the shoulder of the bulb, not across the middle:
				# a centred arc read as a smiling face.
				_arc(_p(0.5, 0.62), 0.17, PI * 1.15, PI * 1.7, Color(1.0, 0.88, 0.62), 0.03),
				_poly([_p(0.24, 0.66), _p(0.06, 0.5), _p(0.26, 0.46)],
						Color(0.35, 0.5, 0.28)),
				_poly([_p(0.76, 0.66), _p(0.94, 0.5), _p(0.74, 0.46)],
						Color(0.35, 0.5, 0.28)),
			]
		"lantern_reed":
			return [
				_line(_p(0.36, 0.96), _p(0.3, 0.3), Color(0.34, 0.44, 0.3), 0.03),
				_line(_p(0.52, 0.96), _p(0.54, 0.2), Color(0.34, 0.44, 0.3), 0.03),
				_line(_p(0.68, 0.96), _p(0.74, 0.36), Color(0.34, 0.44, 0.3), 0.03),
				_poly([_p(0.3, 0.3), _p(0.22, 0.16), _p(0.3, 0.02), _p(0.38, 0.16)],
						Color(0.45, 0.9, 0.95)),
				_poly([_p(0.54, 0.2), _p(0.46, 0.08), _p(0.54, 0.0), _p(0.62, 0.08)],
						Color(0.45, 0.9, 0.95)),
				_poly([_p(0.74, 0.36), _p(0.67, 0.24), _p(0.74, 0.1), _p(0.81, 0.24)],
						Color(0.45, 0.9, 0.95)),
			]
		"mirrorlily":
			return [
				_line(_p(0.02, 0.76), _p(0.98, 0.76), Color(0.2, 0.34, 0.44), 0.02),
				_circle(_p(0.5, 0.6), 0.3, Color(0.72, 0.78, 0.86)),
				_ring(_p(0.5, 0.6), 0.3, Color(0.24, 0.26, 0.3), 0.045),
				_arc(_p(0.5, 0.6), 0.19, PI * 1.05, PI * 1.95, Color(0.95, 0.98, 1.0), 0.035),
				_line(_p(0.26, 0.88), _p(0.74, 0.88), Color(0.55, 0.62, 0.7), 0.02),
			]
		"glasspetal":
			return [
				_line(_p(0.5, 0.96), _p(0.5, 0.42), Color(0.36, 0.5, 0.34), 0.035),
				_poly([_p(0.5, 0.06), _p(0.82, 0.34), _p(0.7, 0.62), _p(0.3, 0.62), _p(0.18, 0.34)],
						Color(0.72, 0.88, 0.95, 0.75)),
				_polyline([_p(0.18, 0.34), _p(0.5, 0.06), _p(0.82, 0.34)],
						Color(0.95, 0.99, 1.0), 0.02),
				_ring(_p(0.5, 0.4), 0.12, Color(0.85, 0.95, 1.0), 0.025),
				_circle(_p(0.5, 0.44), 0.06, Color(0.98, 0.92, 0.6)),
			]
		"embermoss":
			return [
				_poly([_p(0.02, 0.78), _p(0.3, 0.56), _p(0.62, 0.6), _p(0.98, 0.8),
						_p(0.98, 0.96), _p(0.02, 0.96)], Color(0.24, 0.2, 0.18)),
				_polyline([_p(0.06, 0.84), _p(0.34, 0.66), _p(0.64, 0.7), _p(0.94, 0.86)],
						Color(0.95, 0.42, 0.16), 0.05),
				_circle(_p(0.2, 0.8), 0.05, Color(1.0, 0.66, 0.3)),
				_circle(_p(0.48, 0.72), 0.06, Color(1.0, 0.66, 0.3)),
				_circle(_p(0.78, 0.8), 0.05, Color(1.0, 0.66, 0.3)),
			]
		"thornlash":
			return [
				_arc(_p(0.52, 0.62), 0.3, PI * 0.15, PI * 1.35, Color(0.42, 0.48, 0.26), 0.06),
				_poly([_p(0.22, 0.5), _p(0.1, 0.4), _p(0.24, 0.42)], Color(0.3, 0.34, 0.2)),
				_poly([_p(0.26, 0.68), _p(0.12, 0.7), _p(0.24, 0.6)], Color(0.3, 0.34, 0.2)),
				_poly([_p(0.44, 0.34), _p(0.38, 0.18), _p(0.52, 0.24)], Color(0.3, 0.34, 0.2)),
				_poly([_p(0.7, 0.4), _p(0.72, 0.22), _p(0.8, 0.34)], Color(0.3, 0.34, 0.2)),
				_poly([_p(0.72, 0.82), _p(0.86, 0.9), _p(0.7, 0.9)], Color(0.3, 0.34, 0.2)),
				_circle(_p(0.82, 0.56), 0.05, Color(0.85, 0.3, 0.28)),
			]
		"sporebell":
			return [
				_line(_p(0.5, 0.96), _p(0.5, 0.56), Color(0.44, 0.42, 0.34), 0.05),
				_poly([_p(0.14, 0.56), _p(0.2, 0.24), _p(0.5, 0.06), _p(0.8, 0.24),
						_p(0.86, 0.56)], Color(0.72, 0.7, 0.62)),
				_arc(_p(0.5, 0.56), 0.36, PI, TAU, Color(0.86, 0.84, 0.76), 0.03),
				_circle(_p(0.24, 0.72), 0.035, Color(0.85, 0.85, 0.8, 0.6)),
				_circle(_p(0.76, 0.7), 0.03, Color(0.85, 0.85, 0.8, 0.6)),
				_circle(_p(0.1, 0.62), 0.025, Color(0.85, 0.85, 0.8, 0.5)),
			]
		"hoverfern":
			return [
				_polyline([_p(0.5, 0.96), _p(0.3, 0.7), _p(0.12, 0.58)],
						Color(0.3, 0.48, 0.3), 0.03),
				_polyline([_p(0.5, 0.96), _p(0.5, 0.66), _p(0.52, 0.5)],
						Color(0.3, 0.48, 0.3), 0.03),
				_polyline([_p(0.5, 0.96), _p(0.7, 0.7), _p(0.88, 0.58)],
						Color(0.3, 0.48, 0.3), 0.03),
				_circle(_p(0.3, 0.34), 0.07, Color(0.72, 0.58, 0.92)),
				_circle(_p(0.56, 0.22), 0.06, Color(0.78, 0.64, 0.95)),
				_circle(_p(0.8, 0.36), 0.055, Color(0.72, 0.58, 0.92)),
			]
		"frostneedle":
			return [
				_rect(Rect2(0.46, 0.62, 0.08, 0.34), Color(0.48, 0.44, 0.42)),
				_poly([_p(0.5, 0.02), _p(0.7, 0.3), _p(0.3, 0.3)], Color(0.62, 0.78, 0.88)),
				_poly([_p(0.5, 0.2), _p(0.78, 0.52), _p(0.22, 0.52)], Color(0.54, 0.72, 0.86)),
				_poly([_p(0.5, 0.4), _p(0.86, 0.74), _p(0.14, 0.74)], Color(0.46, 0.66, 0.82)),
				_circle(_p(0.28, 0.42), 0.02, Color(0.92, 0.98, 1.0)),
				_circle(_p(0.72, 0.6), 0.02, Color(0.92, 0.98, 1.0)),
			]
		"pulsegrass":
			return [
				_line(_p(0.14, 0.96), _p(0.24, 0.56), Color(0.4, 0.52, 0.32), 0.03),
				_line(_p(0.3, 0.96), _p(0.3, 0.44), Color(0.4, 0.52, 0.32), 0.03),
				_line(_p(0.44, 0.96), _p(0.6, 0.5), Color(0.4, 0.52, 0.32), 0.03),
				_line(_p(0.66, 0.96), _p(0.7, 0.6), Color(0.4, 0.52, 0.32), 0.03),
				_line(_p(0.84, 0.96), _p(0.78, 0.66), Color(0.4, 0.52, 0.32), 0.03),
				_arc(_p(0.5, 0.72), 0.46, PI * 1.15, PI * 1.85, Color(0.98, 0.92, 0.6), 0.04),
			]
		"ghostsilk":
			return [
				_circle(_p(0.34, 0.62), 0.14, Color(0.8, 0.78, 0.72)),
				_circle(_p(0.68, 0.68), 0.11, Color(0.72, 0.7, 0.66)),
				_line(_p(0.08, 0.24), _p(0.5, 0.5), Color(0.94, 0.94, 0.9), 0.02),
				_line(_p(0.5, 0.5), _p(0.94, 0.3), Color(0.94, 0.94, 0.9), 0.02),
				_line(_p(0.3, 0.16), _p(0.62, 0.44), Color(0.94, 0.94, 0.9), 0.02),
				_line(_p(0.62, 0.44), _p(0.88, 0.86), Color(0.94, 0.94, 0.9), 0.02),
				_line(_p(0.34, 0.86), _p(0.5, 0.5), Color(0.94, 0.94, 0.9), 0.02),
			]
	return []


## -------------------------------------------------------------------- animals

static func _animal_ops(id: String) -> Array:
	match id:
		"grazer":
			return [
				_poly([_p(0.2, 0.52), _p(0.72, 0.48), _p(0.8, 0.56), _p(0.7, 0.66),
						_p(0.24, 0.68)], Color(0.4, 0.42, 0.36)),
				_poly([_p(0.24, 0.54), _p(0.7, 0.5), _p(0.74, 0.56), _p(0.28, 0.62)],
						Color(0.42, 0.58, 0.34)),
				# Six low legs: the grazer is a six-legged deer-analog in the
				# model, and the plate has to say the same thing.
				_line(_p(0.26, 0.68), _p(0.22, 0.86), Color(0.3, 0.3, 0.26), 0.03),
				_line(_p(0.33, 0.68), _p(0.3, 0.88), Color(0.3, 0.3, 0.26), 0.03),
				_line(_p(0.44, 0.68), _p(0.43, 0.86), Color(0.3, 0.3, 0.26), 0.03),
				_line(_p(0.51, 0.68), _p(0.52, 0.88), Color(0.3, 0.3, 0.26), 0.03),
				_line(_p(0.6, 0.68), _p(0.62, 0.86), Color(0.3, 0.3, 0.26), 0.03),
				_line(_p(0.67, 0.67), _p(0.7, 0.85), Color(0.3, 0.3, 0.26), 0.03),
				_polyline([_p(0.76, 0.54), _p(0.88, 0.4), _p(0.94, 0.44)],
						Color(0.42, 0.4, 0.36), 0.05),
				_line(_p(0.9, 0.38), _p(0.92, 0.24), Color(0.62, 0.58, 0.5), 0.025),
				_line(_p(0.88, 0.38), _p(0.82, 0.26), Color(0.62, 0.58, 0.5), 0.025),
			]
		"scuttler":
			return [
				_circle(_p(0.5, 0.56), 0.3, Color(0.55, 0.53, 0.5)),
				_circle(_p(0.36, 0.44), 0.06, Color(0.44, 0.52, 0.36)),
				_circle(_p(0.62, 0.66), 0.05, Color(0.44, 0.52, 0.36)),
				_arc(_p(0.5, 0.56), 0.22, PI * 1.1, PI * 1.9, Color(0.66, 0.64, 0.6), 0.02),
				_circle(_p(0.4, 0.34), 0.04, Color(0.05, 0.05, 0.05)),
				_circle(_p(0.6, 0.34), 0.04, Color(0.05, 0.05, 0.05)),
				_line(_p(0.22, 0.52), _p(0.04, 0.42), Color(0.4, 0.38, 0.36), 0.03),
				_line(_p(0.2, 0.62), _p(0.03, 0.62), Color(0.4, 0.38, 0.36), 0.03),
				_line(_p(0.24, 0.72), _p(0.06, 0.82), Color(0.4, 0.38, 0.36), 0.03),
				_line(_p(0.78, 0.52), _p(0.96, 0.42), Color(0.4, 0.38, 0.36), 0.03),
				_line(_p(0.8, 0.62), _p(0.97, 0.62), Color(0.4, 0.38, 0.36), 0.03),
				_line(_p(0.76, 0.72), _p(0.94, 0.82), Color(0.4, 0.38, 0.36), 0.03),
			]
		"drifter":
			return [
				_poly([_p(0.5, 0.06), _p(0.78, 0.3), _p(0.74, 0.48), _p(0.26, 0.48),
						_p(0.22, 0.3)], Color(0.86, 0.84, 0.72, 0.9)),
				_arc(_p(0.5, 0.3), 0.28, PI * 0.05, PI * 0.95, Color(0.96, 0.94, 0.84), 0.03),
				_line(_p(0.32, 0.48), _p(0.28, 0.9), Color(0.9, 0.86, 0.72), 0.025),
				_line(_p(0.42, 0.48), _p(0.42, 0.94), Color(0.9, 0.86, 0.72), 0.025),
				_line(_p(0.58, 0.48), _p(0.6, 0.92), Color(0.9, 0.86, 0.72), 0.025),
				_line(_p(0.68, 0.48), _p(0.74, 0.88), Color(0.9, 0.86, 0.72), 0.025),
				_circle(_p(0.28, 0.9), 0.04, Color(0.55, 0.95, 0.95)),
				_circle(_p(0.42, 0.94), 0.035, Color(0.55, 0.95, 0.95)),
				_circle(_p(0.6, 0.92), 0.035, Color(0.55, 0.95, 0.95)),
				_circle(_p(0.74, 0.88), 0.04, Color(0.55, 0.95, 0.95)),
			]
		"gull":
			return [
				_poly([_p(0.02, 0.4), _p(0.44, 0.52), _p(0.5, 0.62), _p(0.06, 0.56)],
						Color(0.86, 0.88, 0.9)),
				_poly([_p(0.98, 0.4), _p(0.56, 0.52), _p(0.5, 0.62), _p(0.94, 0.56)],
						Color(0.86, 0.88, 0.9)),
				_poly([_p(0.5, 0.46), _p(0.64, 0.58), _p(0.56, 0.76), _p(0.4, 0.72),
						_p(0.36, 0.54)], Color(0.72, 0.74, 0.78)),
				_poly([_p(0.36, 0.54), _p(0.42, 0.44), _p(0.5, 0.46)], Color(0.6, 0.62, 0.66)),
				_poly([_p(0.42, 0.44), _p(0.36, 0.42), _p(0.42, 0.4)], Color(0.95, 0.78, 0.3)),
				_circle(_p(0.46, 0.47), 0.015, Color(0.1, 0.1, 0.1)),
			]
		"rippleback":
			return [
				_line(_p(0.02, 0.66), _p(0.98, 0.66), Color(0.2, 0.34, 0.44), 0.025),
				_poly([_p(0.14, 0.66), _p(0.26, 0.34), _p(0.34, 0.38), _p(0.3, 0.66)],
						Color(0.24, 0.26, 0.3)),
				_poly([_p(0.34, 0.66), _p(0.46, 0.26), _p(0.54, 0.3), _p(0.5, 0.66)],
						Color(0.28, 0.3, 0.34)),
				_poly([_p(0.54, 0.66), _p(0.66, 0.32), _p(0.74, 0.36), _p(0.7, 0.66)],
						Color(0.24, 0.26, 0.3)),
				_poly([_p(0.74, 0.66), _p(0.86, 0.42), _p(0.92, 0.46), _p(0.9, 0.66)],
						Color(0.3, 0.32, 0.36)),
				_poly([_p(0.06, 0.66), _p(0.94, 0.66), _p(0.88, 0.86), _p(0.14, 0.86)],
						Color(0.16, 0.22, 0.28, 0.8)),
			]
		"stalker":
			return [
				_poly([_p(0.16, 0.5), _p(0.68, 0.46), _p(0.78, 0.56), _p(0.66, 0.68),
						_p(0.2, 0.68)], Color(0.1, 0.1, 0.12)),
				_line(_p(0.24, 0.68), _p(0.2, 0.88), Color(0.12, 0.12, 0.14), 0.035),
				_line(_p(0.36, 0.68), _p(0.36, 0.9), Color(0.12, 0.12, 0.14), 0.035),
				_line(_p(0.52, 0.68), _p(0.54, 0.9), Color(0.12, 0.12, 0.14), 0.035),
				_line(_p(0.64, 0.68), _p(0.68, 0.88), Color(0.12, 0.12, 0.14), 0.035),
				_poly([_p(0.74, 0.48), _p(0.96, 0.54), _p(0.9, 0.66), _p(0.7, 0.62)],
						Color(0.08, 0.08, 0.1)),
				_line(_p(0.78, 0.54), _p(0.94, 0.56), Color(0.95, 0.2, 0.15), 0.035),
				_polyline([_p(0.2, 0.5), _p(0.08, 0.36), _p(0.16, 0.3)],
						Color(0.1, 0.1, 0.12), 0.045),
			]
	return []


## ------------------------------------------------------- unit-square wrappers

static func _p(x: float, y: float) -> Vector2:
	return VectorArt.p(x, y)


static func _poly(points: Array, color: Color) -> Dictionary:
	return VectorArt.poly(points, color)


static func _polyline(points: Array, color: Color, width: float) -> Dictionary:
	return VectorArt.polyline(points, color, width)


static func _line(from: Vector2, to: Vector2, color: Color, width: float) -> Dictionary:
	return VectorArt.line(from, to, color, width)


static func _circle(center: Vector2, radius: float, color: Color) -> Dictionary:
	return VectorArt.circle(center, radius, color)


static func _ring(center: Vector2, radius: float, color: Color, width: float) -> Dictionary:
	return VectorArt.ring(center, radius, color, width)


static func _arc(center: Vector2, radius: float, start: float, end: float,
		color: Color, width: float) -> Dictionary:
	return VectorArt.arc(center, radius, start, end, color, width)


static func _rect(rect_: Rect2, color: Color) -> Dictionary:
	return VectorArt.rect(rect_, color)