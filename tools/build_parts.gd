extends SceneTree
## Part builder — bakes world/parts_placed.tscn: the robot parts lying in the world.
## Run: cd project && snap run godot-4 --headless --script res://tools/build_parts.gd
##
## **SITES is the thing to edit to move a part.** Each entry is a part id and where it
## lies, in world (x, z); the y comes from the terrain. Like the benches, these are placed
## as a table rather than by hand so a part can be moved by changing one line and
## re-running.
##
## The parts are deliberately NOT beside the benches they are fitted at — you find one out
## on the island and carry it back, which is the loop the whole feature is for. Placement
## is still the first cut of "hidden on the map": these sit near the paths a player
## already walks, and can be pushed further off them one entry at a time.

const PICKUP_SCENE := "res://items/part_pickup.tscn"
const OUT := "res://world/parts_placed.tscn"

## part id -> where it lies, in (x, z).
const SITES := {
	# Ezo, just off the start beach: the first part is found almost at once, so the
	# bench has something to offer on the first walk.
	"tread_triangle": Vector2(-104.0, 79.0),
	# Ezo, on the coast between the boat mooring and the bench.
	"legs_three": Vector2(18.0, 98.0),
	# Honshu, inland of that island's bench — the first one that takes real finding.
	"legs_telescope": Vector2(175.0, 548.0),
}

## Parts want dry ground that reads as somewhere a thing could have fallen.
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 9.0


func _init() -> void:
	var parts := Node3D.new()
	parts.name = "Parts"
	var problems: PackedStringArray = []
	for part_id in SITES:
		var site: Vector2 = SITES[part_id]
		var height := Ezo.height_at(site.x, site.y)
		var pickup: Area3D = load(PICKUP_SCENE).instantiate()
		pickup.name = "Part_%s" % part_id
		pickup.position = Vector3(site.x, height, site.y)
		pickup.set("part_id", part_id)
		parts.add_child(pickup)
		pickup.owner = parts
		print("%-16s (%7.1f, %7.1f)  ground %5.2f  land=%s"
				% [part_id, site.x, site.y, height, str(Ezo.is_land(site.x, site.y))])
		if not Ezo.is_land(site.x, site.y):
			problems.append("%s is not on land" % part_id)
		if height < MIN_HEIGHT or height > MAX_HEIGHT:
			problems.append("%s sits at %.2f (want %.1f..%.1f)"
					% [part_id, height, MIN_HEIGHT, MAX_HEIGHT])

	var packed := PackedScene.new()
	var err := packed.pack(parts)
	if err != OK:
		push_error("pack parts failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	print("parts_placed.tscn saved: %s (%d parts)" % [err, SITES.size()])
	parts.free()
	if not problems.is_empty():
		for p in problems:
			push_error("build_parts: %s" % p)
		quit(1)
		return
	# Prove the saved scene parses and kept its part ids.
	var check: Node3D = load(OUT).instantiate()
	var placed: PackedStringArray = []
	for child in check.get_children():
		placed.append(str(child.get("part_id")))
	print("reloaded %d parts: %s" % [check.get_child_count(), ", ".join(placed)])
	check.free()
	quit(0)