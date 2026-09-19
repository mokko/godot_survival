extends SceneTree
## Fauna builder — bakes animals/animals_placed.tscn: all 6 species scattered
## by biome using island.gd (flora/plants.md / fauna/animals.md canon).
## Run: cd project && snap run godot-4 --headless --script res://tools/build_animals.gd

const SEED := 20260907

# species -> placements [biome, count]. Counts follow fauna/animals.md herd sizes.
const PLAN := {
	"grazer": {scene = "res://fauna/grazer.tscn",
		placements = [["sw_cape", 4], ["wetlands", 4], ["anywhere", 4]]},
	"drifter": {scene = "res://fauna/drifter.tscn",
		placements = [["wetlands", 5], ["coast", 3]]},
	"gull": {scene = "res://fauna/gull.tscn",
		placements = [["coast", 6], ["anywhere", 4]]},
	"rippleback": {scene = "res://fauna/rippleback.tscn",
		placements = [["lake", 3]]},
	"scuttler": {scene = "res://fauna/scuttler.tscn",
		placements = [["coast", 5], ["sw_cape", 3]]},
	"stalker": {scene = "res://fauna/stalker.tscn",
		placements = [["massif", 2], ["ne_cape", 2]]},
}

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _counts := {}


func _init() -> void:
	_rng.seed = SEED
	DirAccess.open("res://").make_dir_recursive("animals")
	_root = Node3D.new()
	_root.name = "Animals"
	var ezo = load("res://world/island.gd")
	for species in PLAN:
		_counts[species] = 0
		var scene: PackedScene = load(PLAN[species]["scene"])
		if scene == null:
			push_error("cannot load %s" % PLAN[species]["scene"])
			continue
		for entry in PLAN[species]["placements"]:
			var biome: String = entry[0]
			for i in int(entry[1]):
				var p: Vector3 = _point(ezo, biome)
				if p == Vector3.INF:
					continue
				_place(scene, p, species)
		print("%-12s %2d placed" % [species, _counts[species]])
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		push_error("pack animals failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://fauna/animals_placed.tscn")
	print("animals_placed.tscn saved: %s" % err)
	_root.free()
	quit(0)


func _place(scene: PackedScene, pos: Vector3, species: String) -> void:
	var inst: Node3D = scene.instantiate()
	inst.position = pos
	inst.rotation.y = _rng.randf() * TAU
	if species == "stalker":
		# Each stalker gets its own territory plus a second patrol leg on land.
		# Without this they all kept territory_center = Vector2.ZERO and marched
		# to world origin instead of hunting where they were placed.
		var here := Vector2(pos.x, pos.z)
		inst.territory_center = here
		inst.patrol_a = pos
		inst.patrol_b = _patrol_point(here)
	_root.add_child(inst)
	inst.owner = _root
	_counts[species] = _counts.get(species, 0) + 1


func _patrol_point(center: Vector2) -> Vector3:
	## A land point ~9 m from the territory centre, tried in 8 fixed directions.
	var island = load("res://world/island.gd")
	for i in 8:
		var ang := _rng.randf() * TAU + i * TAU / 8.0
		var p := center + Vector2(cos(ang), sin(ang)) * 9.0
		if island.is_land(p.x, p.y):
			return Vector3(p.x, island.height_at(p.x, p.y) + 0.5, p.y)
	return center_pos_fallback(center, island)


func center_pos_fallback(center: Vector2, island) -> Vector3:
	return Vector3(center.x, island.height_at(center.x, center.y) + 0.5, center.y)


## Thin wrapper over island.gd's random_land_point with a retry.
func _point(ezo, biome: String) -> Vector3:
	for attempt in 40:
		var p: Vector3 = ezo.random_land_point(biome)
		if p != Vector3.INF:
			return p
	return Vector3.INF
