extends RefCounted
## Vector-art plumbing shared by the game's procedural 2D art — the inventory
## icons (ui/item_icons.gd) and the Pedia's plates (ui/pedia_art.gd). No image
## assets: art is authored as *ops* (small dictionaries) and drawn with
## CanvasItem calls.
##
## An op's coordinates are whatever space the author built them in — the icons
## and the Pedia's silhouette plates author in a 0..1 unit square and scale with
## scale_ops(); the map plates author directly in pixels, because world/island.gd
## outlines are fitted to the plate rect first (fit_points()). Keeping geometry
## separate from the drawing calls is what lets a headless test walk the ops
## instead of hoping a frame rendered.
##
## Op kinds: "poly", "polyline", "line", "circle", "ring", "arc", "rect".


## ------------------------------------------------------------- op constructors

static func p(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func poly(points: Array, color: Color) -> Dictionary:
	var pts := PackedVector2Array()
	for point in points:
		pts.append(point)
	return {"kind": "poly", "points": pts, "color": color}


static func polyline(points: Array, color: Color, width := 0.04) -> Dictionary:
	var pts := PackedVector2Array()
	for point in points:
		pts.append(point)
	return {"kind": "polyline", "points": pts, "color": color, "width": width}


static func line(from: Vector2, to: Vector2, color: Color,
		width := 0.06) -> Dictionary:
	return {"kind": "line", "from": from, "to": to, "color": color, "width": width}


static func circle(center: Vector2, radius: float, color: Color) -> Dictionary:
	return {"kind": "circle", "center": center, "radius": radius, "color": color}


static func ring(center: Vector2, radius: float, color: Color, width := 0.05,
		segments := 32) -> Dictionary:
	return {"kind": "ring", "center": center, "radius": radius, "color": color,
			"width": width, "segments": segments}


static func arc(center: Vector2, radius: float, start: float, end: float,
		color: Color, width := 0.05, segments := 24) -> Dictionary:
	return {"kind": "arc", "center": center, "radius": radius, "start": start,
			"end": end, "color": color, "width": width, "segments": segments}


static func rect(rect_: Rect2, color: Color) -> Dictionary:
	return {"kind": "rect", "rect": rect_, "color": color}


## ------------------------------------------------------------------- drawing

static func draw_ops(ci: CanvasItem, ops: Array) -> void:
	for op in ops:
		match op["kind"]:
			"poly":
				ci.draw_colored_polygon(op["points"], op["color"])
			"polyline":
				ci.draw_polyline(op["points"], op["color"], op["width"], true)
			"line":
				ci.draw_line(op["from"], op["to"], op["color"], op["width"], true)
			"circle":
				ci.draw_circle(op["center"], op["radius"], op["color"])
			"ring":
				ci.draw_arc(op["center"], op["radius"], 0.0, TAU,
						op["segments"], op["color"], op["width"], true)
			"arc":
				ci.draw_arc(op["center"], op["radius"], op["start"], op["end"],
						op["segments"], op["color"], op["width"], true)
			"rect":
				ci.draw_rect(op["rect"], op["color"])


## -------------------------------------------------------------- unit -> rect

static func translate_ops(ops: Array, offset: Vector2) -> Array:
	## Shift pixel-space ops. Unit-square art is authored from the origin, so it
	## needs this to be centred in a plate that is not square.
	var out: Array = []
	for op in ops:
		var moved: Dictionary = op.duplicate()
		match op["kind"]:
			"poly", "polyline":
				var pts := PackedVector2Array()
				for point in op["points"]:
					pts.append(point + offset)
				moved["points"] = pts
			"line":
				moved["from"] = op["from"] + offset
				moved["to"] = op["to"] + offset
			"circle", "ring", "arc":
				moved["center"] = op["center"] + offset
			"rect":
				moved["rect"] = Rect2(op["rect"].position + offset, op["rect"].size)
		out.append(moved)
	return out


static func scale_ops(ops: Array, size: Vector2) -> Array:
	## Unit-square (0..1) art scaled to `size`. Line widths scale with the width,
	## so a big plate keeps the drawn proportions of the author's square.
	var scaled: Array = []
	for op in ops:
		scaled.append(_scale_op(op, size))
	return scaled


static func _scale_op(op: Dictionary, size: Vector2) -> Dictionary:
	var out := op.duplicate()
	match op["kind"]:
		"poly", "polyline":
			var pts := PackedVector2Array()
			for point in op["points"]:
				pts.append(Vector2(point.x * size.x, point.y * size.y))
			out["points"] = pts
			if op["kind"] == "polyline":
				out["width"] = op["width"] * size.x
		"line":
			out["from"] = Vector2(op["from"].x * size.x, op["from"].y * size.y)
			out["to"] = Vector2(op["to"].x * size.x, op["to"].y * size.y)
			out["width"] = op["width"] * size.x
		"circle", "ring", "arc":
			out["center"] = Vector2(op["center"].x * size.x,
					op["center"].y * size.y)
			out["radius"] = op["radius"] * size.x
			if op["kind"] != "circle":
				out["width"] = op["width"] * size.x
		"rect":
			out["rect"] = Rect2(op["rect"].position.x * size.x,
					op["rect"].position.y * size.y,
					op["rect"].size.x * size.x, op["rect"].size.y * size.y)
	return out


## -------------------------------------------------------------- world -> rect

static func scanline_fill(points: PackedVector2Array, color: Color,
		row_step := 2.0) -> Array:
	## Fill a polygon with even-odd scanlines, one op per row per span.
	##
	## Godot's own draw_colored_polygon triangulates, and the island outlines are
	## not simple polygons: Honshu's coast is an open path that closes across the
	## Tsugaru side and crosses itself, so its fill silently vanished from the
	## map plate ("Invalid polygon data, triangulation failed"). A plate that
	## quietly loses the largest island is worse than a fill two pixels coarse,
	## and a scanline never has to triangulate anything.
	var ops: Array = []
	if points.size() < 3:
		return ops
	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var y := ceilf(min_y / row_step) * row_step
	while y <= max_y:
		var crossings: Array[float] = []
		for i in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				crossings.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var i := 0
		while i + 1 < crossings.size():
			ops.append(rect(Rect2(crossings[i], y,
					crossings[i + 1] - crossings[i], row_step), color))
			i += 2
		y += row_step
	return ops


static func fit_transform(points: Array, target: Rect2) -> Dictionary:
	## How to draw a world-space polygon inside `target`: aspect preserved,
	## centred, and y flipped, because the world's north is -z — mapped straight
	## across, every island would come out upside down. Returned as scale +
	## origin, which fit_point() applies, so extra features (a lake, a marker)
	## land in the same frame as the outline.
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for point in points:
		min_p = min_p.min(point)
		max_p = max_p.max(point)
	var span := max_p - min_p
	if span.x <= 0.0 or span.y <= 0.0:
		return {"scale": 0.0, "origin": target.position, "min_x": 0.0, "max_y": 0.0}
	var scale: float = minf(target.size.x / span.x, target.size.y / span.y)
	var origin: Vector2 = target.position + (target.size - span * scale) * 0.5
	return {"scale": scale, "origin": origin, "min_x": min_p.x, "max_y": max_p.y}


static func fit_point(point: Vector2, transform: Dictionary) -> Vector2:
	var scale: float = transform["scale"]
	var origin: Vector2 = transform["origin"]
	return Vector2(origin.x + (point.x - float(transform["min_x"])) * scale,
			origin.y + (float(transform["max_y"]) - point.y) * scale)


static func fit_points(points: Array, target: Rect2) -> PackedVector2Array:
	## A world-space polygon (x = east, y = north/-z) fitted into `target` pixels.
	var transform := fit_transform(points, target)
	var out := PackedVector2Array()
	for point in points:
		out.append(fit_point(point, transform))
	return out
