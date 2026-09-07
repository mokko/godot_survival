extends SceneTree
## Headless self-test for the Ezo world math. Run with:
##   cd /home/maurice/snap/godot-4/common/survivalm
##   snap run godot-4 --headless --script res://test_island.gd

const EzoScript := preload("res://island.gd")

var _failures := 0


func _init() -> void:
	print("=== Ezo world math self-test ===")
	_check(EzoScript.is_land(EzoScript.SPAWN_XZ.x, EzoScript.SPAWN_XZ.y), "spawn point is on land")
	_check(EzoScript.is_land(0.0, 0.0), "island center is on land")
	_check(not EzoScript.is_land(0.0, 300.0), "far south is sea")
	_check(not EzoScript.is_land(300.0, 0.0), "far east is sea")
	var peak: float = EzoScript.height_at(-5.0, -20.0)
	_check(peak > 8.0, "central massif is tall (h=%.1f)" % peak)
	var bowl: float = EzoScript.height_at(EzoScript.CALDERA_CENTER.x, EzoScript.CALDERA_CENTER.y)
	_check(bowl < EzoScript.LAKE_LEVEL - 1.5, "caldera bowl below lake level (h=%.1f)" % bowl)
	_check(EzoScript.height_at(155.0, 140.0) < -3.0, "offshore is seafloor")
	for biome in ["sw_cape", "wetlands", "ne_cape", "massif", "coast", "anywhere"]:
		var bad := 0
		for i in 300:
			var p: Vector3 = EzoScript.random_land_point(biome)
			if not EzoScript.is_land(p.x, p.z):
				bad += 1
		_check(bad == 0, "300 random %s points on land (%d bad)" % [biome, bad])
	var lake_bad := 0
	for i in 100:
		var p: Vector3 = EzoScript.random_land_point("lake")
		var d: float = Vector2(p.x, p.z).distance_to(EzoScript.CALDERA_CENTER)
		if d > EzoScript.LAKE_RADIUS or not is_equal_approx(p.y, EzoScript.LAKE_LEVEL):
			lake_bad += 1
	_check(lake_bad == 0, "100 random lake points on the lake surface (%d bad)" % lake_bad)
	print("spawn ground height: %.2f" % EzoScript.height_at(EzoScript.SPAWN_XZ.x, EzoScript.SPAWN_XZ.y))
	_print_ascii_map()
	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _print_ascii_map() -> void:
	print("map (x -> east, z -> south; # land, . sea):")
	var cols := 64
	var rows := 30
	for r in rows:
		var line := ""
		var z := lerpf(-130.0, 130.0, float(r) / float(rows - 1))
		for c in cols:
			var x := lerpf(-160.0, 160.0, float(c) / float(cols - 1))
			line += "#" if EzoScript.is_land(x, z) else "."
		print(line)
