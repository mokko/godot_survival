extends SceneTree
## Headless check: the drone's legs — the stock fit is unchanged, the three parts
## all build, swapping replaces rather than stacks, an unknown id is refused rather
## than half-applied, the fit rides in the save, and every fit actually reaches the
## ground instead of floating or sinking into it.

const Legs := preload("res://player/legs.gd")

## The stock body was 2 tread boxes + 6 hub caps; the pin is that moving treads into
## player/legs.gd did not change the drone a fresh run is given.
const STOCK_MESHES := 8


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player = main.get_node("Player")
	var equip: Node3D = player.get_node("Equipment")
	for i in 10:
		await physics_frame
	var fails: PackedStringArray = []

	var legs: Node3D = equip.get_node_or_null("Legs")
	if legs == null:
		print("RESULT FAIL: no Legs node on the drone")
		quit(1)
		return

	# 1. The stock fit, and that it is what the body always had.
	if legs.part() != Legs.STOCK:
		fails.append("stock_fit=%s (want %s)" % [legs.part(), Legs.STOCK])
	var stock_count: int = _mesh_count(legs)
	if stock_count != STOCK_MESHES:
		fails.append("stock_meshes=%d (want %d — the treads moved, they did not change)"
				% [stock_count, STOCK_MESHES])
	if legs.name_of(Legs.STOCK) == "" or legs.name_of(Legs.STOCK) == Legs.STOCK:
		fails.append("the stock fit has no display name")

	# 2. Three parts, each one buildable and named.
	if Legs.PARTS.size() != 3:
		fails.append("parts=%d (want 3)" % Legs.PARTS.size())
	for id in Legs.PARTS:
		if not Legs.NAMES.has(id):
			fails.append("%s has no name" % id)

	# 3. Every fit stands on the ground: its lowest geometry touches y ~ 0, not below
	#    it (sunk into the terrain) and not high above it (hovering). The player's
	#    origin is on the ground, so this is measured from the body's own frame.
	var fits: Array = [Legs.STOCK] + Legs.PARTS.duplicate()
	for id in fits:
		if not equip.set_legs(id):
			fails.append("could not fit %s" % id)
			continue
		if legs.part() != id:
			fails.append("fitting %s left %s on the drone" % [id, legs.part()])
		if _mesh_count(legs) < 4:
			fails.append("%s builds only %d meshes" % [id, _mesh_count(legs)])
		var low: float = _lowest_y(legs)
		if low < -0.02 or low > 0.10:
			fails.append("%s's lowest point is y=%.3f (want -0.02..0.10)" % [id, low])
		# A set has to stand on both sides, or the drone would tip over.
		var left := false
		var right := false
		for m in _meshes(legs):
			if m.position.x < -0.05:
				left = true
			if m.position.x > 0.05:
				right = true
		if not (left and right):
			fails.append("%s is not on both sides (left=%s right=%s)"
					% [id, str(left), str(right)])

	# 4. A swap replaces the old fit — meshes must not accumulate on the body, and
	#    coming back to the stock fit must give exactly the stock meshes again.
	for id in Legs.PARTS:
		equip.set_legs(id)
		var count: int = _mesh_count(legs)
		if count <= stock_count:
			fails.append("%s is only %d meshes — a part should be more than the stock treads"
					% [id, count])
	equip.set_legs(Legs.STOCK)
	if _mesh_count(legs) != stock_count:
		fails.append("returning to the stock fit gave %d meshes, not %d — the old set leaked"
				% [_mesh_count(legs), stock_count])

	# 5. An unknown id is refused and changes nothing.
	if equip.set_legs("legs_dragon"):
		fails.append("an unknown part id was accepted")
	if legs.part() != Legs.STOCK:
		fails.append("a refused part changed the fit to %s" % legs.part())

	# 6. The fit rides in the save.
	equip.set_legs("legs_telescope")
	var state: Dictionary = player.save_state()
	if str(state.get("legs", "")) != "legs_telescope":
		fails.append("save_state legs=%s" % str(state.get("legs", "<missing>")))
	player.load_state(state)
	if equip.fitted_legs() != "legs_telescope":
		fails.append("load_state left %s on the drone" % equip.fitted_legs())
	# A save from before legs existed, or a part this build does not know, leaves the
	# stock fit on rather than leaving the drone legless.
	player.load_state({"legs": "legs_dragon"})
	if equip.fitted_legs() == "legs_dragon" or equip.fitted_legs() == "":
		fails.append("a bogus saved fit was applied: %s" % equip.fitted_legs())
	if _mesh_count(legs) < 4:
		fails.append("a bogus saved fit left the drone with %d leg meshes" % _mesh_count(legs))

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


func _mesh_count(node: Node) -> int:
	return _meshes(node).size()


func _lowest_y(node: Node) -> float:
	## Lowest corner of any mesh in the set, in the node's own frame. Walks the eight
	## corners so a raked belt bar (a box turned about X) is measured where it
	## actually is, not where its centre pretends to be.
	var lowest := 1e9
	for m in _meshes(node):
		var aabb: AABB = m.mesh.get_aabb()
		for i in 8:
			var corner := aabb.get_endpoint(i)
			lowest = minf(lowest, (m.transform * corner).y)
	return lowest