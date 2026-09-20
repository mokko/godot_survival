extends SceneTree
## Boat builder — bakes world/boats_placed.tscn: one moored boat off the south
## coast of every island on the route except the last, so each leg of the journey
## begins "sail from the south shore".
## Run: cd project && snap run godot-4 --headless --script res://tools/build_boats.gd

const BOAT_SCENE := "res://world/boat.tscn"
const OUT := "res://world/boats_placed.tscn"

## The journey, in order. Every island except the last gets a boat, and each boat's
## destination is the next island in the list — change this list to change the route.
## (Ezo → Honshu → Shikoku → Kyushu follows the archipelago south-west, which is
## also the direction the game's map runs.)
const ROUTE := ["Ezo", "Honshu", "Shikoku", "Kyushu"]

## Step south (into the water) per mooring scan, and how deep the water has to be
## to float the hull — that depth rule lives in island.gd (Ezo.HULL_DEPTH), shared
## with world/boat.gd so a moored boat can always sail away from its mooring.
const OFFSHORE_STEP := 0.6
const LAND_CHECK := 6.0       # metres north of the mooring that must be dry land

var _moorings: Array = []


func _init() -> void:
	for island in ROUTE:
		_moorings.append(_south_mooring(island))

	var boats := Node3D.new()
	boats.name = "Boats"
	var problems: PackedStringArray = []
	for i in ROUTE.size() - 1:   # the last island is the destination: no boat there
		var here: Vector3 = _moorings[i]
		var next: Vector3 = _moorings[i + 1]
		var boat: StaticBody3D = load(BOAT_SCENE).instantiate()
		boat.name = "Boat_%s" % ROUTE[i]
		boat.position = here
		# Face out to sea: forward is -Z, so yaw PI points the bow south, away from
		# the beach the boat is moored beside. Otherwise the first press of W sails
		# the player straight into the shore.
		boat.rotation.y = PI
		# Exported per-instance values: the boat knows its leg of the route.
		boat.set("island", ROUTE[i])
		boat.set("destination", ROUTE[i + 1])
		boat.set("destination_xz", Vector2(next.x, next.z))
		boats.add_child(boat)
		boat.owner = boats
		var depth := Ezo.height_at(here.x, here.z)
		print("%-8s -> %-8s  mooring (%6.1f, %6.1f)  depth %5.2f  land north: %s  leg %.0f units"
				% [ROUTE[i], ROUTE[i + 1], here.x, here.z, depth,
				str(Ezo.is_land(here.x, here.z - LAND_CHECK)),
				Vector2(here.x, here.z).distance_to(Vector2(next.x, next.z))])
		if depth < -1.2 or depth > -0.1:
			problems.append("%s moored in %0.2f water (want -1.2..-0.1)" % [ROUTE[i], depth])
		if not Ezo.is_land(here.x, here.z - LAND_CHECK):
			problems.append("%s has no land %0.0f north of the mooring" % [ROUTE[i], LAND_CHECK])

	var packed := PackedScene.new()
	var err := packed.pack(boats)
	if err != OK:
		push_error("pack boats failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	print("boats_placed.tscn saved: %s (%d boats)" % [err, ROUTE.size() - 1])
	boats.free()
	if not problems.is_empty():
		for p in problems:
			push_error("build_boats: %s" % p)
		quit(1)
		return
	# Prove the saved scene parses and kept its route metadata.
	var check: Node3D = load(OUT).instantiate()
	var legs: PackedStringArray = []
	for child in check.get_children():
		legs.append("%s->%s" % [child.get("island"), child.get("destination")])
	print("reloaded %d boats: %s" % [check.get_child_count(), ", ".join(legs)])
	check.free()
	quit(0)


func _south_mooring(island: String) -> Vector3:
	## Each island's southernmost coastline vertex *is* its south cape (Ezo's is the
	## Cape Erimo spike, Honshu's the Kii tip), so start from the outline rather than
	## from a grid-wide scan — a scan cannot tell which island it just hit and moored
	## all three boats on the same beach. A vertex can sit a little offshore where the
	## outline is coarse, so try the few southernmost candidates and take the first
	## with dry land just north of it.
	var candidates := _outline(island).duplicate()
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	for i in mini(4, candidates.size()):
		var v: Vector2 = candidates[i]
		for step in 24:
			var z := v.y - float(step) * 0.5
			if Ezo.is_land(v.x, z):
				return _step_offshore(Vector2(v.x, z))
	push_error("build_boats: found no land for %s" % island)
	return Vector3.INF


func _step_offshore(shore: Vector2) -> Vector3:
	## Walk south (z+) from the waterline until the water is deep enough to float
	## the hull, so the boat sits in the shallows beside the beach, within boarding
	## distance of dry land.
	var p := shore
	for i in 40:
		if Ezo.is_navigable(p.x, p.y):
			break
		p.y += OFFSHORE_STEP
	return Vector3(p.x, Ezo.WATER_LEVEL, p.y)


func _outline(island: String) -> Array:
	match island:
		"Ezo":
			return Ezo.OUTLINE
		"Honshu":
			return Ezo.HONSHU_OUTLINE
		"Shikoku":
			return Ezo.SHIKOKU_OUTLINE
		"Kyushu":
			return Ezo.KYUSHU_OUTLINE
	return []
