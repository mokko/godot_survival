class_name Ezo
## Shared world math for the survivalm archipelago: Ezo (the Hokkaido-shaped
## island) plus Japan's other main islands at 1:1000 — Honshu, Shikoku and
## Kyushu, separated by the Tsugaru Strait and the Seto Inland Sea.
##
## Scale 1:1000: Ezo roughly 300 x 230 units, Honshu ~520 x 590. North = -Z,
## East = +X. Terrain mesh, plant placement and animal movement all sample
## these static functions, so there is exactly one source of truth for the
## world shape.
##
## NOTE: throughout this API, Vector2(x, z) stores the Godot Z in .y.
## Design canon: flora/plants.md and fauna/animals.md. Build plan: WORLD_SPEC.md.

# ------------------------------------------------------------------ constants

const WATER_LEVEL: float = 0.0                 # sea surface height
const LAKE_LEVEL: float = 2.5                  # caldera lake surface height
const CALDERA_CENTER := Vector2(-35.0, -20.0)  # (x, z) of the Ezo caldera lake
const LAKE_RADIUS: float = 13.0                # lake floor bowl radius
const COAST_BAND_IN: float = 1.0               # signed-distance band = "coast"
const COAST_BAND_OUT: float = 9.0
const SPAWN_XZ := Vector2(-112.0, 82.0)        # player arrival, Ezo SW cape

## Hokkaido outline in (x, z). x+ = east, z+ = south.
## Homage at 1:1000: SW cape = Oshima/Hakodate, N tip = Soya,
## NE tip = Shiretoko, S spike = Cape Erimo, E coast = Kushiro.
## UNCHANGED since the original single-island world — bakes depend on it.
const OUTLINE := [
	Vector2(-132.0, 100.0),  # SW cape (Hakodate)
	Vector2(-150.0, 55.0),   # Oshima west coast
	Vector2(-143.0, 5.0),
	Vector2(-120.0, -25.0),  # Oshamambe bend
	Vector2(-108.0, -62.0),  # Shakotan
	Vector2(-85.0, -85.0),   # Otaru / Sapporo coast
	Vector2(-75.0, -95.0),   # Rumoi
	Vector2(-45.0, -110.0),
	Vector2(-12.0, -118.0),  # Soya — north cape
	Vector2(18.0, -108.0),
	Vector2(35.0, -95.0),    # Monbetsu coast
	Vector2(60.0, -90.0),
	Vector2(85.0, -78.0),    # Abashiri
	Vector2(105.0, -95.0),   # Shiretoko neck
	Vector2(135.0, -88.0),   # Shiretoko — NE cape tip
	Vector2(128.0, -60.0),
	Vector2(115.0, -45.0),   # Notsuke
	Vector2(108.0, -15.0),
	Vector2(100.0, 25.0),    # Kushiro coast
	Vector2(70.0, 70.0),
	Vector2(60.0, 80.0),     # Hiroo
	Vector2(33.0, 115.0),    # Cape Erimo — south tip
	Vector2(0.0, 92.0),
	Vector2(-45.0, 95.0),    # Shiraoi
	Vector2(-90.0, 110.0),   # Oshamanbe bay
	Vector2(-125.0, 108.0),  # back to Hakodate
]

## Honshu at 1:1000,km arc coords * 0.9, offset so the Tsugaru Strait is
## ~20 units of open water south of Cape Erimo (z = 135 + km * 0.9).
## S-curve: Aomori -> Nihonkai (Akita/Niigata) -> Noto -> San'in ->
## Shimonoseki (Kanmon strait to Kyushu) -> Seto Inland Sea side ->
## Ise -> Tokai -> Tokyo bay -> Tohoku Sanriku coast.
const HONSHU_OUTLINE := [
	Vector2(-18.0, 130.5),   # Tappi Misaki — Tsugaru Strait
	Vector2(31.5, 144.0),    # Shimokita N tip
	Vector2(13.5, 175.5),
	Vector2(9.0, 238.5),     # Akita coast
	Vector2(-4.5, 288.0),    # Yamagata / Niigata bend
	Vector2(-40.5, 328.5),   # Noto peninsula tip
	Vector2(-36.0, 351.0),   # Noto S / Toyama bay head
	Vector2(-76.5, 369.0),   # Noto W coast (Kaga)
	Vector2(-90.0, 414.0),   # Tsuruga
	Vector2(-121.5, 445.5),  # San'in: Tottori dunes
	Vector2(-103.5, 490.5),  # San'in: Izumo
	Vector2(-117.0, 531.0),  # San'in: Nagato (Hagi)
	Vector2(-90.0, 576.0),   # Shimonoseki — Kanmon strait to Kyushu
	Vector2(-54.0, 589.5),   # Yamaguchi inner coast
	Vector2(-13.5, 558.0),   # Kure -> Kii channel side
	Vector2(9.0, 513.0),     # Osaka bay head
	Vector2(27.0, 477.0),    # Ise bay W shore (Tsu)
	Vector2(22.5, 427.5),    # Ise bay E (Toba)
	Vector2(63.0, 405.0),    # Hamanako
	Vector2(112.5, 409.5),   # Omaezaki head
	Vector2(139.5, 445.5),   # Shizuoka (Suruga bay inner)
	Vector2(126.0, 495.0),   # Izu peninsula S
	Vector2(148.5, 522.0),   # Izu E coast
	Vector2(166.5, 567.0),   # Tokyo bay mouth
	Vector2(144.0, 603.0),   # Choshi (Inubosaki)
	Vector2(175.5, 612.0),   # Ibaraki coast (Oarai)
	Vector2(238.5, 585.0),   # Sendai bay head
	Vector2(274.5, 558.0),   # Kesennuma
	Vector2(301.5, 513.0),   # Kamaishi (Sanriku)
	Vector2(319.5, 459.0),   # Miyako
	Vector2(333.0, 409.5),   # Hachinohe
	Vector2(315.0, 360.0),   # Shimokita S — back west along N Honshu
]

## Oga peninsula (Akita) — small separate blob on the Nihonkai coast.
const OGA_OUTLINE := [
	Vector2(-49.5, 261.0), Vector2(-34.2, 271.8),
	Vector2(-43.2, 289.8), Vector2(-59.4, 277.2),
]

const SHIKOKU_OUTLINE := [
	Vector2(-100.0, 675.0), Vector2(-45.0, 660.0), Vector2(-40.0, 710.0),
	Vector2(10.0, 720.0), Vector2(75.0, 705.0), Vector2(95.0, 720.0),
	Vector2(85.0, 675.0), Vector2(20.0, 655.0), Vector2(-60.0, 670.0),
]

## Kyushu: diamond with Nomo/Osumi peninsulas in the SW.
const KYUSHU_OUTLINE := [
	Vector2(-165.0, 650.0), Vector2(-130.0, 680.0), Vector2(-105.0, 715.0),
	Vector2(-75.0, 700.0), Vector2(-45.0, 675.0), Vector2(-15.0, 670.0),
	Vector2(35.0, 655.0), Vector2(55.0, 650.0), Vector2(35.0, 625.0),
	Vector2(-5.0, 605.0), Vector2(-45.0, 595.0), Vector2(-85.0, 595.0),
	Vector2(-130.0, 610.0),
]

## Seto Inland Sea islets (Shodoshima / Awaji style), between Honshu & Shikoku.
const SETO_ISLETS := [
	Vector2(-55.0, 610.0), Vector2(-25.0, 610.0), Vector2(-40.0, 622.5),
	Vector2(-30.0, 632.5), Vector2(15.0, 612.0), Vector2(48.0, 618.0),
]

## Interior highlands: [center: Vector2, amplitude, sigma]. Multiplied by the
## shore mask, so they never raise the open sea.
const FEATURES := [
	# Ezo: central massif, NE hills (Kitami), SW highlands
	[Vector2(-5.0, -20.0), 9.0, 40.0], [Vector2(45.0, -45.0), 4.0, 30.0],
	[Vector2(-90.0, 10.0), 3.5, 25.0],
	# Honshu: Tohoku highlands, Japan Alps, Chugoku mountains, Kii
	[Vector2(200.0, 430.0), 7.0, 35.0], [Vector2(40.0, 300.0), 10.0, 45.0],
	[Vector2(-60.0, 485.0), 6.0, 30.0], [Vector2(10.0, 520.0), 4.5, 25.0],
	# Shikoku mountains
	[Vector2(-10.0, 680.0), 5.5, 25.0],
	# Kyushu: Aso-style caldera cone, Kirishima hills
	[Vector2(-60.0, 655.0), 8.0, 20.0], [Vector2(-100.0, 680.0), 4.0, 18.0],
]

## All land polygons, combined with a min() signed distance. Assembled in
## the static initializer below (const arrays cannot call static helpers).
static var ALL_POLYGONS: Array = []


static func _static_init() -> void:
	ALL_POLYGONS = [
		OUTLINE, HONSHU_OUTLINE, OGA_OUTLINE, SHIKOKU_OUTLINE, KYUSHU_OUTLINE,
	]
	for c in SETO_ISLETS:
		ALL_POLYGONS.append(_islet_quad(c, 4.0 if c.x > 40.0 else 5.0))

## Biome sampling regions: name -> Array of [center: Vector2, radius: float].
## "coast", "lake" and "anywhere" are special-cased in random_land_point().
const BIOMES := {
	"sw_cape": [[Vector2(-115.0, 75.0), 40.0], [Vector2(-95.0, 95.0), 25.0]],
	"massif": [[Vector2(-5.0, -20.0), 55.0], [Vector2(30.0, -50.0), 30.0]],
	"caldera_rim": [[Vector2(-35.0, -20.0), 22.0]],
	"wetlands": [[Vector2(75.0, 5.0), 30.0]],
	"ne_cape": [[Vector2(115.0, -65.0), 28.0]],
	"alps": [[Vector2(40.0, 300.0), 50.0]],
	"kii": [[Vector2(10.0, 520.0), 30.0]],
	"tohoku": [[Vector2(200.0, 430.0), 45.0]],
	"chugoku": [[Vector2(-60.0, 485.0), 35.0]],
	"shikoku": [[Vector2(-10.0, 680.0), 40.0]],
	"kyushu": [[Vector2(-60.0, 655.0), 45.0]],
	"coast": [],
	"lake": [],
	"anywhere": [],
}

## World bounds for mesh generation and sampling.
const GRID_MIN := Vector2(-210.0, -150.0)
const GRID_MAX := Vector2(410.0, 760.0)
const WATER_PLANE_SIZE := 1700.0

# ------------------------------------------------------------------- terrain

static func height_at(x: float, z: float) -> float:
	## Terrain height at (x, z). Offshore ≈ -3.5 (seafloor), beaches cross
	## WATER_LEVEL just inside each outline, massif peaks ≈ 10-12.
	var p := Vector2(x, z)
	var s := clampf(0.5 + signed_distance(p) / 14.0, 0.0, 1.0)
	var h := lerpf(-3.5, 2.2, s)
	h += _feature_rise(p) * s
	# Caldera bowl: flat floor -12 inside r=12, walls rising to 0 at r=22.
	var r := p.distance_to(CALDERA_CENTER)
	h -= 12.0 * (1.0 - _smoothstep2(12.0, 22.0, r)) * s
	# Wetlands: flatten the Kushiro region into boggy ground just above sea.
	var wet := clampf(0.8 * _gauss(p, Vector2(75.0, 5.0), 22.0), 0.0, 1.0)
	h = lerpf(h, 0.9, wet)
	return h


static func is_land(x: float, z: float) -> bool:
	return height_at(x, z) >= WATER_LEVEL + 0.25


static func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < WATER_LEVEL - 0.1


static func spawn_point() -> Vector3:
	return Vector3(SPAWN_XZ.x, height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)

# ----------------------------------------------------------------- placement

static func random_land_point(biome: String = "anywhere") -> Vector3:
	## Uniform-ish random point for a biome. Returns Vector3(x, y, z) with
	## y = terrain height (or LAKE_LEVEL for biome "lake"). Falls back to
	## the spawn point after 400 tries (should never happen).
	if biome == "lake":
		var a := randf() * TAU
		var r := sqrt(randf()) * (LAKE_RADIUS - 1.0)
		var c := CALDERA_CENTER + Vector2(cos(a), sin(a)) * r
		return Vector3(c.x, LAKE_LEVEL, c.y)
	for _attempt in 400:
		var p := _sample_biome(biome)
		if p == Vector3.INF or not is_land(p.x, p.z):
			continue
		if biome == "coast":
			var d := signed_distance(Vector2(p.x, p.z))
			if d < COAST_BAND_IN or d > COAST_BAND_OUT:
				continue
		elif biome == "caldera_rim":
			if Vector2(p.x, p.z).distance_to(CALDERA_CENTER) < LAKE_RADIUS + 2.0:
				continue
		return p
	return spawn_point()


static func _sample_biome(biome: String) -> Vector3:
	if biome == "anywhere":
		var x := randf_range(GRID_MIN.x, GRID_MAX.x)
		var z := randf_range(GRID_MIN.y, GRID_MAX.y)
		return Vector3(x, height_at(x, z), z)
	var regions: Array = BIOMES.get(biome, [])
	if regions.is_empty():
		return Vector3.INF
	var region: Array = regions[randi() % regions.size()]
	var center: Vector2 = region[0]
	var radius: float = region[1]
	var a := randf() * TAU
	var r := sqrt(randf()) * radius
	var c := center + Vector2(cos(a), sin(a)) * r
	return Vector3(c.x, height_at(c.x, c.y), c.y)

# --------------------------------------------------------------------- shape

static func signed_distance(p: Vector2) -> float:
	## Positive inside the nearest island, negative offshore. Magnitude ≈
	## distance to that island's outline polygon, in units. Union of the
	## polygons: max over per-polygon positive-inside distances.
	var best := -1000000.0
	for poly in ALL_POLYGONS:
		best = maxf(best, _poly_signed_distance(poly, p))
	return best


static func _seto_islet_polygons() -> Array:
	## Tiny quads around each Seto islet center.
	var out: Array = []
	for c in SETO_ISLETS:
		var r := 5.0
		if c.x > 40.0:
			r = 4.0
		out.append(_islet_quad(c, r))
	return out


static func _islet_quad(c: Vector2, r: float) -> Array:
	return [
		Vector2(c.x - r, c.y - r * 0.6), Vector2(c.x + r, c.y - r * 0.5),
		Vector2(c.x + r * 0.8, c.y + r * 0.6), Vector2(c.x - r * 0.9, c.y + r * 0.5),
	]


static func _poly_signed_distance(poly: Array, p: Vector2) -> float:
	var dmin := 1000000.0
	var j := poly.size() - 1
	var crossings := 0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		var d := _dist_to_segment(p, a, b)
		dmin = minf(dmin, d)
		if (a.y > p.y) != (b.y > p.y):
			var x_int: float = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < x_int:
				crossings += 1
		j = i
	return -dmin if crossings % 2 == 0 else dmin


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# -------------------------------------------------------------- height field

static func _gauss(p: Vector2, center: Vector2, sigma: float) -> float:
	var d := p - center
	return exp(-d.length_squared() / (2.0 * sigma * sigma))


static func _feature_rise(p: Vector2) -> float:
	var h := 0.0
	for f in FEATURES:
		h += f[1] * _gauss(p, f[0], f[2])
	return h


static func _noise(x: float, z: float, freq: float) -> float:
	## Deterministic value noise in [0, 1] — integer hash + smooth bilinear.
	var fx := x * freq
	var fz := z * freq
	var i := floori(fx)
	var j := floori(fz)
	var tx := fx - float(i)
	var tz := fz - float(j)
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sz := tz * tz * (3.0 - 2.0 * tz)
	var a := _hash2(i, j)
	var b := _hash2(i + 1, j)
	var c := _hash2(i, j + 1)
	var d := _hash2(i + 1, j + 1)
	return a + (b - a) * sx + (c - a) * sz + (a - b - c + d) * sx * sz


static func _hash2(i: int, j: int) -> float:
	var h := (i * 374761393 + j * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) % 10000
	return h / 10000.0


static func _smoothstep01(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _smoothstep2(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
