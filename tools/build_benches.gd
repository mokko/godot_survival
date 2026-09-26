extends SceneTree
## Bench builder — bakes world/benches_placed.tscn: one service bench on every
## island, so the Frame screen (ui/editor.gd) is reachable from anywhere the
## journey goes.
## Run: cd project && snap run godot-4 --headless --script res://tools/build_benches.gd
##
## **SITES is the thing to edit to move a bench.** Each entry is where that island's
## bench stands, in world (x, z); the y comes from the terrain. Everything else here
## is validation, because a bench placed in the sea or on a cliff is a bench nobody
## can ever service.

const BENCH_SCENE := "res://world/bench.tscn"
const OUT := "res://world/benches_placed.tscn"

## One bench per island. Each is a short walk inland from that island's south
## shore — the beach the player comes ashore on — so it is found by exploring up
## from the landing rather than by being handed a marker. The coordinates were
## probed from the terrain (they sit 30 m inland of the waterline, 2.2-6.3 m above
## the sea). Change a number here and re-run to move a bench.
const SITES := {
	"Ezo": Vector2(33.0, 81.0),
	"Honshu": Vector2(175.5, 579.5),
	"Shikoku": Vector2(10.0, 689.0),
	"Kyushu": Vector2(-105.0, 682.5),
}

## A bench wants dry, walkable ground: not a beach (it would be washed over) and
## not a summit (nobody walks up there expecting a workshop).
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 9.0


func _init() -> void:
	var benches := Node3D.new()
	benches.name = "Benches"
	var problems: PackedStringArray = []
	for island in SITES:
		var site: Vector2 = SITES[island]
		var height := Ezo.height_at(site.x, site.y)
		var bench: StaticBody3D = load(BENCH_SCENE).instantiate()
		bench.name = "Bench_%s" % island
		bench.position = Vector3(site.x, height, site.y)
		# The working side faces the sea, back toward the shore the player walks up
		# from: the bench is built with its slab, vice and hung tools on its +Z face,
		# so yaw 0 (no rotation) aims that at the shore rather than at the hills.
		bench.rotation.y = 0.0
		bench.set("island", island)
		benches.add_child(bench)
		bench.owner = benches
		print("%-8s bench (%7.1f, %7.1f)  ground %5.2f  land=%s"
				% [island, site.x, site.y, height, str(Ezo.is_land(site.x, site.y))])
		if not Ezo.is_land(site.x, site.y):
			problems.append("%s's bench is not on land" % island)
		if height < MIN_HEIGHT or height > MAX_HEIGHT:
			problems.append("%s's bench sits at %.2f (want %.1f..%.1f)"
					% [island, height, MIN_HEIGHT, MAX_HEIGHT])

	var packed := PackedScene.new()
	var err := packed.pack(benches)
	if err != OK:
		push_error("pack benches failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	print("benches_placed.tscn saved: %s (%d benches)" % [err, SITES.size()])
	benches.free()
	if not problems.is_empty():
		for p in problems:
			push_error("build_benches: %s" % p)
		quit(1)
		return
	# Prove the saved scene parses and kept its island metadata.
	var check: Node3D = load(OUT).instantiate()
	var placed: PackedStringArray = []
	for child in check.get_children():
		placed.append(str(child.get("island")))
	print("reloaded %d benches: %s" % [check.get_child_count(), ", ".join(placed)])
	check.free()
	quit(0)