extends SceneTree
## Headless check: ground clutter — three MultiMesh layers filled around the
## player, every instance on dry land inside the window, tufts only where plants
## can hold, deterministic across refills, recentring when the window moves,
## fading in at the edge, and decoration-only (no collision, no shadows).
##
## Placement is checked through plan_fill() rather than by reading the MultiMesh
## back: under --headless the dummy renderer keeps no instance buffers, so
## get_instance_transform() returns nothing usable there. plan_fill() also
## completes the window synchronously, which the tests need — _process() builds
## it under a per-frame time budget instead.


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await process_frame
	var fails: PackedStringArray = []
	var clutter: Node3D = main.get_node("Clutter")
	var player: Node3D = main.get_node("Player")

	# Complete the window, then check that the plan reached the MultiMeshes.
	var centre := Vector2(player.global_position.x, player.global_position.z)
	var plan: Dictionary = clutter.plan_fill(centre)
	var transforms: Array = plan["transforms"]
	var colours: Array = plan["colours"]

	# 1. Layers are filled MultiMeshes matching the plan, with room to spare.
	var names := ["Pebbles", "Twigs", "Tufts"]
	var total := 0
	for li in names.size():
		var node: MultiMeshInstance3D = clutter.get_node(names[li])
		var mm: MultiMesh = node.multimesh
		if mm == null:
			fails.append("layer_%d_no_multimesh" % li)
			continue
		if mm.mesh == null:
			fails.append("layer_%d_no_mesh" % li)
		if not mm.use_colors:
			fails.append("layer_%d_no_colours" % li)
		if mm.visible_instance_count != transforms[li].size():
			fails.append("layer_%d_write_mismatch=%d_of_%d"
					% [li, mm.visible_instance_count, transforms[li].size()])
		if mm.visible_instance_count > mm.instance_count:
			fails.append("layer_%d_over_capacity" % li)
		if mm.visible_instance_count <= 0:
			fails.append("layer_%d_empty" % li)
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			fails.append("layer_%d_shadows_on" % li)
		if node.custom_aabb.size.y <= 0.0:
			fails.append("layer_%d_no_culling_box" % li)
		total += mm.visible_instance_count
	if total < 50:
		fails.append("too_few_instances=%d" % total)
	for child in clutter.get_children():
		if child is CollisionObject3D:
			fails.append("collision_body=%s" % child.name)

	# 2. Placement rules over the window the player is standing in.
	for li in 3:
		if transforms[li].size() < 10:
			fails.append("layer_%d_too_sparse=%d" % [li, transforms[li].size()])
		for i in transforms[li].size():
			var t: Transform3D = transforms[li][i]
			var p := t.origin
			if Vector2(p.x, p.z).distance_to(centre) > clutter.RADIUS + 0.01:
				fails.append("layer_%d_out_of_window" % li)
				break
			if not Ezo.is_land(p.x, p.z):
				fails.append("layer_%d_off_land" % li)
				break
			if p.y > Ezo.height_at(p.x, p.z) + 0.01:
				fails.append("layer_%d_floating" % li)
				break
			if colours[li][i].a <= 0.0:
				fails.append("layer_%d_invisible_colour" % li)
				break
	# Tufts are plants: none on beach sand or bare highland rock.
	for i in transforms[2].size():
		var p: Vector3 = transforms[2][i].origin
		var h := Ezo.height_at(p.x, p.z)
		if h < Ezo.WATER_LEVEL + clutter.SHORE_BAND:
			fails.append("tuft_on_sand")
			break
		if h > clutter.ROCK_HEIGHT:
			fails.append("tuft_on_rock")
			break

	# 3. Variation: transforms and tints are not all the same.
	var first_t: Transform3D = transforms[0][0]
	var first_c: Color = colours[0][0]
	var varied_t := false
	var varied_c := false
	for i in transforms[0].size():
		varied_t = varied_t or transforms[0][i] != first_t
		varied_c = varied_c or colours[0][i] != first_c
	if not varied_t:
		fails.append("transforms_identical")
	if not varied_c:
		fails.append("colours_identical")

	# 4. Edge fade: items in the outermost band are scaled down.
	var inner := 0.0
	var inner_n := 0
	var outer := 0.0
	var outer_n := 0
	for i in transforms[0].size():
		var p: Vector3 = transforms[0][i].origin
		var d := Vector2(p.x, p.z).distance_to(centre)
		var s: float = transforms[0][i].basis.get_scale().x
		if d < clutter.RADIUS - clutter.FADE_BAND:
			inner += s
			inner_n += 1
		else:
			outer += s
			outer_n += 1
	if inner_n > 0 and outer_n > 0:
		if outer / outer_n >= 0.75 * (inner / inner_n):
			fails.append("no_edge_fade")
	else:
		fails.append("fade_band_empty")

	# 5. Deterministic: the same centre plans to the same instances.
	var again: Array = clutter.plan_fill(centre)["transforms"]
	var stable: bool = again[0].size() == transforms[0].size()
	if stable:
		for i in transforms[0].size():
			if again[0][i] != transforms[0][i]:
				stable = false
				break
	if not stable:
		fails.append("plan_not_deterministic")

	# 6. Recentring: a window planned 40/25 units away holds its items there.
	var moved := centre + Vector2(40.0, 25.0)
	var moved_transforms: Array = clutter.plan_fill(moved)["transforms"]
	var inside := 0
	for i in moved_transforms[0].size():
		var p: Vector3 = moved_transforms[0][i].origin
		if Vector2(p.x, p.z).distance_to(moved) <= clutter.RADIUS:
			inside += 1
	if moved_transforms[0].size() > 0 and inside != moved_transforms[0].size():
		fails.append("planned_out_of_window=%d/%d" % [inside, moved_transforms[0].size()])
	if moved_transforms[0].size() <= 0:
		fails.append("moved_window_empty")

	# 7. Cost: sliding the window by one refill step must stay cheap. The first
	#    version re-sampled the terrain on every refill and cost ~220 ms — a
	#    stall every few metres; the per-cell cache and the derived ground tilt
	#    are what removed it. In play this work is also spread over frames by
	#    CACHE_BUDGET_US, so this is the pessimistic synchronous number.
	var step: float = clutter.REFILL_STEP
	var t0 := Time.get_ticks_usec()
	var slid: Array = clutter.plan_fill(moved + Vector2(step, step))["transforms"]
	var slide_us := Time.get_ticks_usec() - t0
	print("clutter: slide refill cost %d us (%d pebbles)" % [slide_us, slid[0].size()])
	if slide_us > 40000:
		fails.append("slide_refill_too_slow=%dus" % slide_us)

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
