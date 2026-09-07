extends SceneTree
## Flora builder — bakes plants/plants_placed.tscn: all 12 species scattered
## by biome using island.gd (WORLD_SPEC.md worker: Plants).
## Run: cd project && snap run godot-4 --headless --script res://build_plants.gd

const SEED := 20260906

# species -> {scene, placements: [biome or ["grove", center_biome, count, spread]]}
# Counts follow plants.md. "inland" filters out the beach band via signed_distance.
const PLAN := {
	"windsinger": {"scene": "res://plants/windsinger.tscn", "mode": "groves",
		"groves": [["massif", 5], ["massif", 7], ["massif", 4], ["ne_cape", 5]]},
	"sunbulb": {"scene": "res://plants/sunbulb.tscn", "mode": "biome",
		"placements": [["anywhere", 60]], "inland": true},
	"lantern_reed": {"scene": "res://plants/lantern_reed.tscn", "mode": "biome",
		"placements": [["wetlands", 60], ["caldera_rim", 20]]},
	"mirrorlily_big": {"scene": "res://plants/mirrorlily.tscn", "mode": "biome",
		"placements": [["lake", 12]]},
	"mirrorlily_small": {"scene": "res://plants/mirrorlily_small.tscn", "mode": "biome",
		"placements": [["lake", 13]]},
	"glasspetal": {"scene": "res://plants/glasspetal.tscn", "mode": "biome",
		"placements": [["massif", 20], ["ne_cape", 20]]},
	"embermoss": {"scene": "res://plants/embermoss.tscn", "mode": "biome",
		"placements": [["wetlands", 30], ["massif", 20]]},
	"thornlash": {"scene": "res://plants/thornlash.tscn", "mode": "biome",
		"placements": [["sw_cape", 10], ["wetlands", 5], ["anywhere", 5]], "inland": true},
	"sporebell": {"scene": "res://plants/sporebell.tscn", "mode": "biome",
		"placements": [["wetlands", 20], ["ne_cape", 10]]},
	"hoverfern": {"scene": "res://plants/hoverfern.tscn", "mode": "biome",
		"placements": [["massif", 25], ["caldera_rim", 10]]},
	"frostneedle": {"scene": "res://plants/frostneedle.tscn", "mode": "ring",
		"center": Vector2(-5.0, -20.0), "r_min": 12.0, "r_max": 48.0, "count": 90},
	"pulsegrass": {"scene": "res://plants/pulsegrass.tscn", "mode": "biome",
		"placements": []},  # shader-pass placeholder; zero instances (plants.md)
}
const GHOSTSILK := {"scene": "res://plants/ghostsilk.tscn", "count": 15,
	"hosts": ["frostneedle", "windsinger", "sunbulb"]}

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _counts := {}
var _placed_positions := {}  # species -> Array[Vector3]


func _init() -> void:
	_rng.seed = SEED
	DirAccess.open("res://").make_dir_recursive("plants")
	_root = Node3D.new()
	_root.name = "Plants"
	for species in PLAN:
		_counts[species] = 0
		_placed_positions[species] = []
		_scatter(species, PLAN[species])
	_silk()
	for species in PLAN:
		if PLAN[species]["mode"] == "biome" and PLAN[species].get("placements", []).is_empty():
			continue
		print("%-18s %3d placed" % [species, _counts[species]])
	print("%-18s %3d placed" % ["ghostsilk", _counts.get("ghostsilk", 0)])
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		push_error("pack plants failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://plants/plants_placed.tscn")
	print("plants_placed.tscn saved: %s" % err)
	_root.free()
	quit(0)


func _scatter(species: String, spec: Dictionary) -> void:
	var scene: PackedScene = load(spec["scene"])
	match spec["mode"]:
		"biome":
			for entry in spec.get("placements", []):
				var biome: String = entry[0]
				for i in int(entry[1]):
					var p := Ezo_point(biome)
					if p == Vector3.INF:
						continue
					if spec.get("inland", false) \
							and Ezo.signed_distance(Vector2(p.x, p.z)) < 4.0:
						continue
					_place(scene, p, species)
		"ring":
			var center: Vector2 = spec["center"]
			var placed: int = 0
			for attempt in spec["count"] * 6:
				if placed >= int(spec["count"]):
					break
				var a := _rng.randf() * TAU
				var r := _rng.randf_range(spec["r_min"], spec["r_max"])
				var p2 := center + Vector2(cos(a), sin(a)) * r
				if not Ezo.is_land(p2.x, p2.y):
					continue
				_place(scene, Vector3(p2.x, Ezo.height_at(p2.x, p2.y), p2.y), species)
				placed += 1
		"groves":
			for grove in spec["groves"]:
				var gc := Ezo_point(grove[0])
				if gc == Vector3.INF:
					continue
				for i in int(grove[1]):
					var off := _rng.randf_range(2.0, 9.0)
					var a := _rng.randf() * TAU
					var p2 := Vector2(gc.x, gc.z) + Vector2(cos(a), sin(a)) * off
					if Ezo.is_land(p2.x, p2.y):
						_place(scene, Vector3(p2.x, Ezo.height_at(p2.x, p2.y), p2.y), species)


func _silk() -> void:
	var scene: PackedScene = load(GHOSTSILK["scene"])
	var pool: Array = []
	for host in GHOSTSILK["hosts"]:
		pool.append_array(_placed_positions[host])
	if pool.is_empty():
		return
	for i in int(GHOSTSILK["count"]):
		var base: Vector3 = pool[_rng.randi() % pool.size()]
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.0, 2.5)
		var p := base + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if Ezo.is_land(p.x, p.z):
			_place(scene, Vector3(p.x, Ezo.height_at(p.x, p.z), p.y if false else Ezo.height_at(p.x, p.z)), "ghostsilk")


func _place(scene: PackedScene, pos: Vector3, species: String) -> void:
	var inst: Node3D = scene.instantiate()
	inst.position = pos
	inst.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.85, 1.2)
	inst.scale = Vector3(s, s, s)
	_root.add_child(inst)
	inst.owner = _root
	_counts[species] = _counts.get(species, 0) + 1
	if _placed_positions.has(species):
		_placed_positions[species].append(pos)


## Thin wrapper over island.gd's random_land_point with a retry.
func Ezo_point(biome: String) -> Vector3:
	for attempt in 40:
		var p: Vector3 = Ezo.random_land_point(biome)
		if p != Vector3.INF:
			return p
	return Vector3.INF
