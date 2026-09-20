extends Control
## Procedural inventory icons: each item is drawn as vector art into its slot
## (no image assets — the droid, flora and fauna are built the same way).
##
## Art is authored as *ops* in a 0..1 unit square by _unit_ops(), then scaled to
## whatever rect the slot asks for; the op vocabulary, the scaling and the
## drawing live in ui/vector_art.gd, shared with the Pedia's plates. Keeping the
## geometry separate from the drawing calls is what lets the headless test walk
## every item's ops instead of hoping a frame rendered.
##
## Slot usage: set_item() then queue_redraw happens automatically; an
## empty/unset id draws nothing (the slot's frame stays visible).

const VectorArt := preload("res://ui/vector_art.gd")

var item_id := ""


func set_item(id: String) -> void:
	if item_id == id:
		return
	item_id = id
	queue_redraw()

## Every id in ItemDB must appear here, or it would fall back to the generic
## shard; tests/test_item_icons.gd enforces that.
const ICON_IDS := [
	"flint", "stick", "vine", "kana_charm", "shell", "emberstone",
	"sword", "shield", "dagger", "bow", "arrows", "leather_armor", "notebook",
]

# Shared palette bits (item colours come from ItemDB; these are the accents).
const STEEL := Color(0.85, 0.87, 0.92)
const STEEL_EDGE := Color(0.55, 0.58, 0.65)
const DARK := Color(0.14, 0.15, 0.18)
const WOOD_DARK := Color(0.35, 0.24, 0.12)
const HILIGHT := Color(1.0, 1.0, 1.0, 0.55)


func _draw() -> void:
	VectorArt.draw_ops(self, icon_ops(item_id, size))


static func icon_ops(icon_id: String, size: Vector2) -> Array:
	## Unit-square art scaled to `size`. Returns [] for an unknown/empty id, so
	## a slot can call this unconditionally. The Pedia's equipment plates call
	## this too, which is why an item's icon cannot drift from its Pedia page.
	if icon_id == "":
		return []
	return VectorArt.scale_ops(_unit_ops(icon_id), size)


## ---- geometry ------------------------------------------------------------
## Thin wrappers over ui/vector_art.gd so the art below reads as coordinates.

static func _p(x: float, y: float) -> Vector2:
	return VectorArt.p(x, y)


static func _poly(points: Array, color: Color) -> Dictionary:
	return VectorArt.poly(points, color)


static func _line(from: Vector2, to: Vector2, color: Color,
		width := 0.06) -> Dictionary:
	return VectorArt.line(from, to, color, width)


static func _arc(center: Vector2, radius: float, start: float, end: float,
		color: Color, width := 0.05, segments := 24) -> Dictionary:
	return VectorArt.arc(center, radius, start, end, color, width, segments)


static func _circle(center: Vector2, radius: float, color: Color) -> Dictionary:
	return VectorArt.circle(center, radius, color)


static func _text(pos: Vector2, string: String, color: Color,
		size: float) -> Dictionary:
	return VectorArt.text(pos, string, color, size)


static func _unit_ops(icon_id: String) -> Array:
	## One branch per item id. Coordinates run 0..1, y down.
	match icon_id:
		"flint":
			return [
				_poly([_p(0.12, 0.78), _p(0.46, 0.1), _p(0.62, 0.44),
						_p(0.88, 0.62), _p(0.5, 0.9)], Color(0.55, 0.55, 0.58)),
				_poly([_p(0.46, 0.1), _p(0.62, 0.44), _p(0.5, 0.9)], Color(0.42, 0.42, 0.46)),
				_line(_p(0.5, 0.12), _p(0.58, 0.86), HILIGHT, 0.02),
			]
		"stick":
			return [
				_line(_p(0.14, 0.88), _p(0.84, 0.16), Color(0.62, 0.45, 0.25), 0.1),
				_line(_p(0.5, 0.5), _p(0.78, 0.6), Color(0.62, 0.45, 0.25), 0.06),
				_circle(_p(0.34, 0.66), 0.045, WOOD_DARK),
				_circle(_p(0.66, 0.36), 0.035, WOOD_DARK),
			]
		"vine":
			return [
				{"kind": "polyline", "points": PackedVector2Array([
						_p(0.24, 0.92), _p(0.5, 0.74), _p(0.3, 0.56),
						_p(0.56, 0.4), _p(0.42, 0.22), _p(0.62, 0.1)]),
					"color": Color(0.35, 0.55, 0.25), "width": 0.07},
				_poly([_p(0.56, 0.4), _p(0.86, 0.3), _p(0.6, 0.22)],
						Color(0.45, 0.68, 0.32)),
				_poly([_p(0.3, 0.56), _p(0.14, 0.44), _p(0.34, 0.4)],
						Color(0.45, 0.68, 0.32)),
			]
		"kana_charm":
			return [
				# Omamori pouch: gold cord loop and knot, red bag, dark binding.
				_arc(_p(0.5, 0.16), 0.14, PI * 1.08, TAU * 0.92,
						Color(0.9, 0.78, 0.4), 0.05),
				_poly([_p(0.26, 0.24), _p(0.74, 0.24), _p(0.78, 0.88),
						_p(0.22, 0.88)], Color(0.85, 0.2, 0.2)),
				_line(_p(0.2, 0.34), _p(0.8, 0.34), Color(0.7, 0.13, 0.13), 0.09),
				_circle(_p(0.5, 0.24), 0.045, Color(0.9, 0.78, 0.4)),
				_poly([_p(0.34, 0.46), _p(0.66, 0.46), _p(0.62, 0.78),
						_p(0.38, 0.78)], Color(0.92, 0.36, 0.3)),
				_line(_p(0.5, 0.46), _p(0.5, 0.78), Color(0.97, 0.86, 0.6), 0.03),
			]
		"shell":
			return [
				_circle(_p(0.5, 0.5), 0.42, Color(0.9, 0.85, 0.7)),
				_arc(_p(0.5, 0.5), 0.34, 0.0, TAU * 0.86, Color(0.72, 0.66, 0.52), 0.045, 32),
				_arc(_p(0.5, 0.5), 0.22, 0.0, TAU * 0.8, Color(0.72, 0.66, 0.52), 0.04, 28),
				_arc(_p(0.5, 0.5), 0.1, 0.0, TAU * 0.74, Color(0.72, 0.66, 0.52), 0.035, 20),
			]
		"emberstone":
			return [
				_poly([_p(0.5, 0.08), _p(0.88, 0.42), _p(0.72, 0.9),
						_p(0.28, 0.9), _p(0.12, 0.42)], Color(1.0, 0.4, 0.1)),
				_poly([_p(0.5, 0.08), _p(0.62, 0.46), _p(0.5, 0.9),
						_p(0.38, 0.46)], Color(1.0, 0.62, 0.24)),
				_poly([_p(0.5, 0.08), _p(0.88, 0.42), _p(0.62, 0.46)],
						Color(1.0, 0.78, 0.45, 0.85)),
			]
		"sword":
			return [
				# Katana: long, gently curved blade, clear round tsuba, wrapped grip.
				{"kind": "polyline", "points": PackedVector2Array([
						_p(0.3, 0.6), _p(0.5, 0.4), _p(0.66, 0.24),
						_p(0.76, 0.08)]), "color": STEEL, "width": 0.075},
				{"kind": "polyline", "points": PackedVector2Array([
						_p(0.3, 0.6), _p(0.5, 0.4), _p(0.66, 0.24)]),
					"color": STEEL_EDGE, "width": 0.022},
				_poly([_p(0.72, 0.04), _p(0.82, 0.02), _p(0.8, 0.16),
						_p(0.68, 0.16)], STEEL),
				_circle(_p(0.29, 0.62), 0.075, DARK),
				_line(_p(0.25, 0.68), _p(0.1, 0.9), WOOD_DARK, 0.1),
				_line(_p(0.22, 0.71), _p(0.14, 0.83), Color(0.55, 0.4, 0.2), 0.03),
			]
		"shield":
			return [
				_poly([_p(0.5, 0.06), _p(0.9, 0.24), _p(0.84, 0.66),
						_p(0.5, 0.94), _p(0.16, 0.66), _p(0.1, 0.24)],
						Color(0.55, 0.4, 0.2)),
				_poly([_p(0.5, 0.18), _p(0.78, 0.31), _p(0.74, 0.62),
						_p(0.5, 0.82), _p(0.26, 0.62), _p(0.22, 0.31)],
						Color(0.66, 0.49, 0.26)),
				_circle(_p(0.5, 0.5), 0.11, STEEL_EDGE),
				_line(_p(0.5, 0.18), _p(0.5, 0.82), Color(0.45, 0.32, 0.16), 0.03),
			]
		"dagger":
			return [
				_poly([_p(0.58, 0.14), _p(0.63, 0.2), _p(0.44, 0.5),
						_p(0.4, 0.44)], STEEL),
				_line(_p(0.44, 0.5), _p(0.58, 0.14), STEEL_EDGE, 0.02),
				_poly([_p(0.34, 0.44), _p(0.46, 0.42), _p(0.5, 0.52),
						_p(0.38, 0.54)], DARK),
				_line(_p(0.4, 0.56), _p(0.24, 0.84), WOOD_DARK, 0.09),
			]
		"bow":
			return [
				_arc(_p(0.42, 0.5), 0.42, -PI * 0.62, PI * 0.62,
						Color(0.5, 0.35, 0.15), 0.075, 28),
				_line(_p(0.55, 0.08), _p(0.55, 0.92), Color(0.85, 0.85, 0.82), 0.025),
				_line(_p(0.18, 0.5), _p(0.86, 0.5), Color(0.7, 0.6, 0.35), 0.045),
				_poly([_p(0.86, 0.5), _p(0.74, 0.44), _p(0.74, 0.56)],
						Color(0.75, 0.75, 0.72)),
			]
		"arrows":
			return [
				_line(_p(0.16, 0.86), _p(0.74, 0.28), Color(0.75, 0.65, 0.4), 0.05),
				_line(_p(0.3, 0.92), _p(0.88, 0.34), Color(0.75, 0.65, 0.4), 0.05),
				_poly([_p(0.74, 0.28), _p(0.88, 0.14), _p(0.86, 0.32),
						_p(0.7, 0.34)], STEEL),
				_poly([_p(0.88, 0.34), _p(0.98, 0.24), _p(0.94, 0.42)],
						STEEL),
				_poly([_p(0.16, 0.86), _p(0.06, 0.98), _p(0.24, 0.94)],
						Color(0.85, 0.35, 0.3)),
			]
		"leather_armor":
			return [
				_poly([_p(0.24, 0.14), _p(0.44, 0.1), _p(0.56, 0.1),
						_p(0.76, 0.14), _p(0.82, 0.5), _p(0.7, 0.9),
						_p(0.3, 0.9), _p(0.18, 0.5)], Color(0.55, 0.4, 0.25)),
				_poly([_p(0.44, 0.1), _p(0.56, 0.1), _p(0.5, 0.22)],
						Color(0.42, 0.3, 0.18)),
				_line(_p(0.3, 0.34), _p(0.7, 0.34), Color(0.42, 0.3, 0.18), 0.05),
				_line(_p(0.28, 0.62), _p(0.72, 0.62), Color(0.42, 0.3, 0.18), 0.05),
			]
		"notebook":
			return [
				# The Pedia itself: a brown leather notebook, slightly skewed so it
				# reads as a book on a table, with its name on the cover. The only
				# art in the game that needs letters (vector_art.text()).
				_poly([_p(0.16, 0.16), _p(0.84, 0.11), _p(0.88, 0.87),
						_p(0.2, 0.93)], Color(0.45, 0.3, 0.18)),
				_poly([_p(0.16, 0.16), _p(0.29, 0.145), _p(0.33, 0.92),
						_p(0.2, 0.93)], Color(0.3, 0.2, 0.11)),
				_poly([_p(0.78, 0.12), _p(0.84, 0.11), _p(0.88, 0.87),
						_p(0.82, 0.88)], Color(0.87, 0.83, 0.72)),
				_text(_p(0.36, 0.45), "Pedia", Color(0.96, 0.91, 0.79), 0.135),
				_line(_p(0.38, 0.62), _p(0.72, 0.585), Color(0.72, 0.63, 0.48), 0.025),
				_line(_p(0.39, 0.72), _p(0.74, 0.685), Color(0.72, 0.63, 0.48), 0.025),
				_line(_p(0.4, 0.82), _p(0.68, 0.79), Color(0.72, 0.63, 0.48), 0.025),
			]
		_:
			# Unknown id: a neutral shard rather than blank, so a missing icon
			# is visible in game and caught by the id-coverage test.
			return [
				_poly([_p(0.5, 0.1), _p(0.9, 0.5), _p(0.5, 0.9), _p(0.1, 0.5)],
						Color(0.6, 0.6, 0.6)),
			]
