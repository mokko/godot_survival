extends SceneTree
## Fauna builder — bakes animals/animals_placed.tscn: all 6 species scattered
## by biome using island.gd (plants.md / animals.md canon).
## Run: cd project && snap run godot-4 --headless --script res://build_animals.gd

const SEED := 20260907

# species -> placements [biome, count]. Counts follow animals.md herd sizes.
const PLAN := {
	"grazer": {scene = "res://animals/grazer.tscn",
		placements = [["sw_cape", 4], ["wetlands", 4], ["anywhere", 4]]},
	"drifter": {scene = "res://animals/drifter.tscn",
		placements = [["wetlands", 5], ["coast", 3]]},
	"gull": {scene = "res://animals/gull.tscn",
		placements = [["coast", 6], ["anywhere", 4]]},
	"rippleback": {scene = "res://animals/rippleback.tscn",
		placements = [["lake", 3]]},
	"scuttler": {scene = "res://animals/scuttler.tscn",
		placements = [["coast", 5], ["sw_cape", 3]]},
	"stalker": {scene = "res://animals/stalker.tscn",
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
	var ezo = load("res://island.gd")
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
	err = ResourceSaver.save(packed, "res://animals/animals_placed.tscn")
	print("animals_placed.tscn saved: %s" % err)
	_root.free()
	quit(0)


func _place(scene: PackedScene, pos: Vector3, species: String) -> void:
	var inst: Node3D = scene.instantiate()
	inst.position = pos
	inst.rotation.y = _rng.randf() * TAU
	_root.add_child(inst)
	inst.owner = _root
	_counts[species] = _counts.get(species, 0) + 1


## Thin wrapper over island.gd's random_land_point with a retry.
func _point(ezo, biome: String) -> Vector3:
	for attempt in 40:
		var p: Vector3 = ezo.random_land_point(biome)
		if p != Vector3.INF:
			return p
	return Vector3.INF
