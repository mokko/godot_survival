class_name Ezo
## Shared world math for Ezo — the Hokkaido-shaped island of survivalm.
##
## Scale 1:1000 of Hokkaido: roughly 300 x 230 units. North = -Z, East = +X.
## Terrain mesh, plant placement and animal movement all sample these static
## functions, so there is exactly one source of truth for the world shape.
##
## NOTE: throughout this API, Vector2(x, z) stores the Godot Z in .y.
## Design canon: flora/plants.md and fauna/animals.md. Build plan: WORLD_SPEC.md.

# ------------------------------------------------------------------ constants

const WATER_LEVEL: float = 0.0                 # sea surface height
const LAKE_LEVEL: float = 2.5                  # caldera lake surface height
const CALDERA_CENTER := Vector2(-35.0, -20.0)  # (x, z) of the caldera lake
const LAKE_RADIUS: float = 13.0                # lake floor bowl radius
const COAST_BAND_IN: float = 1.0               # signed-distance band = "coast"
const COAST_BAND_OUT: float = 9.0
const SPAWN_XZ := Vector2(-112.0, 82.0)        # player arrival, SW cape

## Hokkaido outline polygon in (x, z). x+ = east, z+ = south.
## Homage at 1:1000: SW cape = Oshima/Hakodate, N tip = Soya,
## NE tip = Shiretoko, S spike = Cape Erimo, E coast = Kushiro.
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

## Biome sampling regions: name -> Array of [center: Vector2, radius: float].
## "coast", "lake" and "anywhere" are special-cased in random_land_point().
const BIOMES := {
	"sw_cape": [[Vector2(-115.0, 75.0), 40.0], [Vector2(-95.0, 95.0), 25.0]],
	"massif": [[Vector2(-5.0, -20.0), 55.0], [Vector2(30.0, -50.0), 30.0]],
	"caldera_rim": [[Vector2(-35.0, -20.0), 22.0]],
	"wetlands": [[Vector2(75.0, 5.0), 30.0]],
	"ne_cape": [[Vector2(115.0, -65.0), 28.0]],
	"coast": [],
	"lake": [],
	"anywhere": [],
}

# ------------------------------------------------------------------- terrain

static func height_at(x: float, z: float) -> float:
	## Terrain height at (x, z). Offshore ≈ -3.5 (seafloor), beaches cross
	## WATER_LEVEL just inside the outline, massif peaks ≈ 10-12.
	var p := Vector2(x, z)
	var s := clampf(0.5 + signed_distance(p) / 14.0, 0.0, 1.0)
	var h := lerpf(-3.5, 2.2, s)                                     # island base
	h += 9.0 * _gauss(p, Vector2(-5.0, -20.0), 40.0) * s             # central massif
	h += 4.0 * _gauss(p, Vector2(45.0, -45.0), 30.0) * s             # NE hills (Kitami)
	h += 3.5 * _gauss(p, Vector2(-90.0, 10.0), 25.0) * s             # SW highlands
	# Caldera bowl: flat floor -12 inside r=12, walls rising to 0 at r=22.
	var r := p.distance_to(CALDERA_CENTER)
	h -= 12.0 * (1.0 - smoothstep(12.0, 22.0, r)) * s
	# Wetlands: flatten the Kushiro region into boggy ground just above sea.
	var wet := clampf(0.8 * _gauss(p, Vector2(75.0, 5.0), 22.0), 0.0, 1.0)
	h = lerpf(h, 0.9, wet)
	return h


static func is_land(x: float, z: float) -> bool:
	return height_at(x, z) >= WATER_LEVEL + 0.25


static func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < WATER_LEVEL - 0.1


static func signed_distance(p: Vector2) -> float:
	## Positive inside the island, negative offshore. Magnitude ≈ distance
	## to the coastline polygon, in units.
	var best := 1000000.0
	var j := OUTLINE.size() - 1
	for i in OUTLINE.size():
		var d := _dist_to_segment(p, OUTLINE[i], OUTLINE[j])
		best = minf(best, d)
		j = i
	if is_inside_outline(p):
		return best
	return -best


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
		var x := randf_range(-150.0, 150.0)
		var z := randf_range(-122.0, 122.0)
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


static func _gauss(p: Vector2, center: Vector2, sigma: float) -> float:
	var d := p - center
	return exp(-d.length_squared() / (2.0 * sigma * sigma))


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# --------------------------------------------------------------------- shape

static func is_inside_outline(p: Vector2) -> bool:
	var inside := false
	var j := OUTLINE.size() - 1
	for i in OUTLINE.size():
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[j]
		if (a.y > p.y) != (b.y > p.y):
			var x_int: float = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < x_int:
				inside = not inside
		j = i
	return inside
