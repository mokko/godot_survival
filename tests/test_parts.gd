extends SceneTree
## Headless check: robot parts — three of them lie in the world, picking one up puts it
## straight on the robot and never in the inventory, only owned parts can be fitted, the
## Frame screen lists exactly what the drone owns with the fit it is wearing marked, and
## the whole lot rides in the save.

const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")
const Parts := preload("res://player/robot_parts.gd")


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 10:
		await physics_frame
	var player = main.get_node("Player")
	var equip: Node3D = player.get_node("Equipment")
	var menu: Control = main.get_node("HUD/PauseMenu")
	var editor: Control = menu.get_node("Editor")
	var fails: PackedStringArray = []
	Parts.clear()

	# 1. One part in the world per catalogue fit, all on dry ground with something to see.
	var pickups: Array = get_nodes_in_group("part_pickup")
	if pickups.size() != Legs.PARTS.size():
		fails.append("part_pickups=%d (want %d)" % [pickups.size(), Legs.PARTS.size()])
	var seen: Dictionary = {}
	for p in pickups:
		var id := str(p.part_id)
		seen[id] = true
		if not Legs.NAMES.has(id):
			fails.append("%s is not a fit the legs catalogue knows" % id)
		if not Ezo.is_land(p.global_position.x, p.global_position.z):
			fails.append("%s is not on land" % id)
		if p.get_node_or_null("Mesh") == null:
			fails.append("%s has no mesh" % id)
		# Its prompt must be able to clear while a menu is up, which needs it to keep
		# processing through the pause — the same reason the bench does.
		if p.process_mode != Node.PROCESS_MODE_ALWAYS:
			fails.append("%s stops processing while paused, so its prompt cannot clear" % id)
	for id in Legs.PARTS:
		if not seen.has(id):
			fails.append("%s lies nowhere in the world" % id)
	# Two parts must not be on top of each other, or one hides the other.
	for i in pickups.size():
		for j in range(i + 1, pickups.size()):
			var a: Vector3 = pickups[i].global_position
			var b: Vector3 = pickups[j].global_position
			if a.distance_to(b) < 5.0:
				fails.append("%s and %s are in the same spot"
						% [pickups[i].part_id, pickups[j].part_id])

	# 2. Picking one up goes onto the robot, not into the bag.
	var first: Node3D = pickups[0]
	var first_id := str(first.part_id)
	var items_before := _item_total(player)
	first._on_body_entered(player)
	if not Parts.has(first_id):
		fails.append("picking up %s did not put it on the robot" % first_id)
	if _item_total(player) != items_before:
		fails.append("picking up a part added something to the inventory")
	if not first._collected:
		fails.append("the pickup did not mark itself collected")
	if Parts.own(first_id):
		fails.append("the same part could be found twice")

	# 3. Ownership: the stock fit is the drone's own, an unfound part is not, and nothing
	#    can be fitted by guessing an id.
	if not player.owns_part(Legs.STOCK):
		fails.append("the drone does not own its own treads")
	if player.owns_part("legs_three"):
		fails.append("a part it has not found reads as owned")
	if player.fit_legs("legs_three"):
		fails.append("fitted a part the drone had not found")
	if player.fit_legs("legs_dragon"):
		fails.append("fitted a part that does not exist")
	if equip.fitted_legs() != Legs.STOCK:
		fails.append("a refused fit changed the drone to %s" % equip.fitted_legs())

	# 4. The Frame screen: opened from a bench, listing what is owned and nothing else.
	var bench: Node3D = get_nodes_in_group("bench")[0]
	player.global_position = bench.global_position + Vector3(0.0, 0.0, 2.0)
	for i in 2:
		await physics_frame
	if not bench.use_for_test(player):
		fails.append("the bench did not open the frame screen")
	# The first bench of a run says what it is before the screen opens (`world/bench.gd`
	# asks for the `bench` story page): close the page, because the screen behind it is
	# what this case is about.
	var story: Node = main.get_node_or_null("HUD/StoryScreen")
	if story != null and story.is_playing():
		story._advance()
	for i in 3:
		await process_frame
	if not editor.visible:
		fails.append("the frame screen is not visible after a bench")
	# The Robo Editor shows **three families** — body, head, legs — each on its stock part, and
	# each row walks its own catalogue with ◀ ▶ (Maurice's call, 27 Sep). Every variant is
	# reachable while the parts are cosmetic (`player/player.gd::fit_body_part`), which is what
	# replaced the old "list only what the drone owns" rule and its refusal assertions.
	if editor.rows() != [Torsos.STOCK, Heads.STOCK, Legs.STOCK]:
		fails.append("the editor shows %s" % str(editor.rows()))
	for kind in ["torso", "head", "legs"]:
		var ids: Array = editor.family_ids(kind)
		if ids.size() < 4:
			fails.append("%s offers only %d variants: %s" % [kind, ids.size(), str(ids)])
		if ids[0] != str(editor.fitted(kind)) and editor.fitted(kind) == "":
			fails.append("%s has nothing on the drone" % kind)
	# ▶ walks a family, ◀ walks back, and the ends wrap rather than dead-ending.
	var torso_ids: Array = editor.family_ids("torso")
	if not editor.cycle("torso", 1) or editor.fitted("torso") != str(torso_ids[1]):
		fails.append("cycling the body did not move it: %s" % editor.fitted("torso"))
	if player.equipment.fitted_torso() != editor.fitted("torso"):
		fails.append("the screen and the drone disagree about the body")
	if not editor.cycle("torso", -1) or editor.fitted("torso") != str(torso_ids[0]):
		fails.append("cycling back did not return the body")
	if not editor.cycle("torso", -1) or editor.fitted("torso") != str(torso_ids[torso_ids.size() - 1]):
		fails.append("the body row did not wrap: %s" % editor.fitted("torso"))
	# The head cycles through its own family, and its eye is rebuilt with it (equipment's
	# reference to the lens that the hurt flash dims).
	var head_ids: Array = editor.family_ids("head")
	if not editor.cycle("head", 1) or editor.fitted("head") != str(head_ids[1]):
		fails.append("cycling the head did not move it: %s" % editor.fitted("head"))
	if player.equipment._eye == null or player.equipment._eye.name != "Eye":
		fails.append("the swapped head left the drone with no eye")

	# The picture: a real drone model in a SubViewport, with a camera and lights, **wearing what
	# the drone is wearing** — the screen shows the change rather than only naming it. Checked
	# after the cycles above, so this is the "it followed" assertion and not just "it exists".
	var picture: Node3D = editor.preview_model()
	if picture == null:
		fails.append("the screen has no picture of the drone")
	else:
		for kind in ["torso", "head", "legs"]:
			if str(picture.fitted(kind)) != str(editor.fitted(kind)):
				fails.append("the picture's %s is %s, the drone's is %s"
						% [kind, str(picture.fitted(kind)), str(editor.fitted(kind))])
		if picture.fitted("head") == "":
			fails.append("the picture is showing no head at all")
	var viewport: SubViewport = editor.preview
	if viewport == null:
		fails.append("the picture has no viewport")
	else:
		if viewport.get_node_or_null("PreviewCamera") == null:
			fails.append("the picture has no camera")
		if viewport.find_children("*", "DirectionalLight3D", true, false).is_empty():
			fails.append("the picture has no light")

	# The part itself is *found* the way the world gives it (walking into the pickup) before the
	# row walks to it, so section 5 still has a found part to restore.
	for p in pickups:
		if str(p.part_id) == "legs_three":
			p._on_body_entered(player)
	# ...and the legs row reaches that part the same way the other rows reach theirs.
	while editor.fitted("legs") != "legs_three" and editor.cycle("legs", 1):
		pass
	if editor.fitted("legs") != "legs_three" or equip.fitted_legs() != "legs_three":
		fails.append("the legs row never reached legs_three: %s" % editor.fitted("legs"))
	# ...and the choice is part of what the drone looks like: it rides in the save.
	var body_state: Dictionary = player.save_state()
	if str(body_state.get("torso", "")) != player.equipment.fitted_torso():
		fails.append("the body is not saved: %s" % str(body_state.get("torso", "")))
	if str(body_state.get("head", "")) != player.equipment.fitted_head():
		fails.append("the head is not saved: %s" % str(body_state.get("head", "")))

	# 5. It all rides in the save, and comes back.
	var state: Dictionary = player.save_state()
	var saved: Array = state.get("parts", [])
	if not (saved.has("tread_triangle") or saved.has("legs_three")):
		fails.append("save has no parts: %s" % str(saved))
	Parts.clear()
	player.load_state(state)
	if not (Parts.has(first_id) and Parts.has("legs_three")):
		fails.append("the parts did not come back from the save")
	if equip.fitted_legs() != "legs_three":
		fails.append("the fitted part did not come back (%s)" % equip.fitted_legs())

	main.queue_free()
	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _item_total(player: Node) -> int:
	## How much the inventory is carrying, so "a part did not go into the bag" is a
	## measurement rather than an assumption.
	var inv = player.inventory
	if inv == null:
		return 0
	var total := 0
	for i in inv.SLOTS:
		total += int(inv.counts[i])
	return total