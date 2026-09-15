extends SceneTree
## Headless check: island.gd biome sampling actually finds points. The "coast"
## biome used to have no sampler at all, so every coastal placement burned 400
## attempts and fell back to the spawn point — which stacked 14 animals on the
## player's start position. This pins that shut.

const Island := preload("res://world/island.gd")

func _init() -> void:
	var fails: PackedStringArray = []
	var spawn: Vector3 = Island.spawn_point()

	# "anywhere" and "coast" must land on land, inside their own contracts,
	# and never silently degrade to the spawn point.
	for biome in ["anywhere", "coast"]:
		var hits := 0
		var at_spawn := 0
		for i in 60:
			var p: Vector3 = Island.random_land_point(biome)
			if p.distance_to(spawn) < 0.01:
				at_spawn += 1
				continue
			if not Island.is_land(p.x, p.z):
				fails.append("%s_not_land=%s" % [biome, p])
				continue
			if biome == "coast":
				var d: float = Island.signed_distance(Vector2(p.x, p.z))
				if d < Island.COAST_BAND_IN or d > Island.COAST_BAND_OUT:
					fails.append("coast_out_of_band=%.2f" % d)
			hits += 1
		if at_spawn > 0:
			fails.append("%s_fell_back_to_spawn=%d/60" % [biome, at_spawn])
		if hits < 30:
			fails.append("%s_too_few=%d/60" % [biome, hits])

	# "lake" stays on the caldera lake surface.
	var lake_ok := true
	for i in 20:
		var p: Vector3 = Island.random_land_point("lake")
		if absf(p.y - Island.LAKE_LEVEL) > 0.01 \
				or Vector2(p.x, p.z).distance_to(Island.CALDERA_CENTER) > Island.LAKE_RADIUS:
			lake_ok = false
			break
	if not lake_ok:
		fails.append("lake_sampling")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
