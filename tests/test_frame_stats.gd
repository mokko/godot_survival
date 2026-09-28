extends SceneTree
## Headless check: the drone's characteristics — `player/frame_stats.gd` sums the three fitted
## families, and **the stock frame answers exactly the numbers the game used before that file
## existed**. That equality is what made moving the readers over to it safe, so it is asserted
## here rather than assumed; the rest of the suite running on the stock frame is the other half.
##
## The other thing worth pinning is the vocabulary: every part's trait must name something the
## layer knows, because a typo'd trait ("walk_speeed") is read by nothing and looks exactly like a
## part with no effect — the failure a test has to catch because no one will ever see it in play.

const FrameStats := preload("res://player/frame_stats.gd")
const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")
const PlayerScene := preload("res://player/player.tscn")

## The three families, as [script, the word for it in a message].
const FAMILIES := [[Legs, "legs"], [Torsos, "torso"], [Heads, "head"]]


func _init() -> void:
	var fails: PackedStringArray = []
	var stock = FrameStats.new()

	# 1. The stock frame is the game's own numbers, to the digit.
	if absf(stock.walk_speed() - 5.0) > 0.001:
		fails.append("stock_walk=%.2f" % stock.walk_speed())
	if absf(stock.sprint_speed() - 10.0) > 0.001:
		fails.append("stock_sprint=%.2f" % stock.sprint_speed())
	if absf(stock.jump_velocity() - 4.72) > 0.001:
		fails.append("stock_jump=%.2f" % stock.jump_velocity())
	if absf(stock.tank() - 40.0) > 0.001:
		fails.append("stock_tank=%.1f" % stock.tank())
	if absf(stock.idle_drain() - 0.25) > 0.001:
		fails.append("stock_drain=%.2f" % stock.idle_drain())
	if absf(stock.brake_scale() - 1.0) > 0.001:
		fails.append("stock_brake=%.2f" % stock.brake_scale())
	# The view height is the camera's own place in the scene, so check it against the scene.
	var scene_player = PlayerScene.instantiate()
	var camera: Camera3D = scene_player.get_node_or_null("Camera3D")
	if camera == null:
		fails.append("the player has no camera to measure the view height")
	elif absf(stock.eye_height() - camera.position.y) > 0.0001:
		fails.append("stock_eye_height=%.6f, camera at %.6f"
				% [stock.eye_height(), camera.position.y])
	scene_player.free()

	# 2. A stock part contributes its **weight and nothing else** — that is what keeps the base
	#    the base, and a stock part that moved something would quietly move every drone in the game.
	for family in FAMILIES:
		var traits: Dictionary = family[0].TRAITS.get(family[0].STOCK, {})
		if traits.is_empty():
			fails.append("%s's stock part declares no traits at all" % family[1])
		for key in traits:
			if key != "mass":
				fails.append("the stock %s changes %s" % [family[1], key])

	# 3. Weight adds up: the core plus every part's own.
	var core: float = FrameStats.BASE["mass"]
	if absf(stock.mass() - (core + 14.0 + 6.0 + 3.0)) > 0.001:
		fails.append("stock_mass=%.1f" % stock.mass())
	var heavy = FrameStats.new(Legs.STOCK, "torso_plated", Heads.STOCK)
	if absf(heavy.mass() - (core + 14.0 + 9.0 + 3.0)) > 0.001:
		fails.append("plated_mass=%.1f" % heavy.mass())

	# 4. A delta is the frame's, not the part's: legs that walk are slower, and the run follows the
	#    walk because it is a multiple of it.
	var walker = FrameStats.new("legs_three")
	if walker.walk_speed() >= stock.walk_speed():
		fails.append("legs_three did not slow the walk")
	if walker.sprint_speed() >= stock.sprint_speed():
		fails.append("the run did not follow the walk")
	if absf(walker.jump_velocity() - (4.72 + 0.20)) > 0.001:
		fails.append("legs_three_jump=%.2f" % walker.jump_velocity())

	# 5. Grip is per surface: the stock frame holds all of them, and a part moves only the ones it
	#    names — so a surface left alone stays at the base.
	for surface in FrameStats.SURFACES:
		if absf(stock.grip(surface) - 1.0) > 0.001:
			fails.append("the stock frame grips %s at %.2f" % [surface, stock.grip(surface)])
	var climber = FrameStats.new("legs_three")
	if climber.grip("rock") <= stock.grip("rock"):
		fails.append("legs_three does not hold rock any better")
	if absf(climber.grip("sand") - float(FrameStats.BASE["grip"]["sand"])) > 0.001:
		fails.append("legs_three moved a surface it never named")

	# 6. Every trait names something the frame knows, in every family and for every part —
	#    stock parts included, so a catalogue cannot grow an unreadable trait.
	var known: Array = FrameStats.BASE.keys()
	known.append("grip")
	for family in FAMILIES:
		var table: Dictionary = family[0].TRAITS
		var ids: Array = [family[0].STOCK] + family[0].PARTS.duplicate()
		for id in ids:
			if not table.has(id):
				fails.append("%s %s declares no traits, so it is a part with no numbers" % [family[1], id])
				continue
			var traits: Dictionary = table[id]
			for key in traits:
				if not known.has(key):
					fails.append("%s's '%s' is not something the frame knows" % [id, key])
				if key == "grip":
					for surface in traits[key]:
						if not FrameStats.SURFACES.has(surface):
							fails.append("%s grips an unknown surface '%s'" % [id, surface])

	# 7. The vocabulary for what comes next is declared even though nothing reads it yet: that is
	#    where a part's effect will land, and losing a name would be losing the plan.
	for name in ["mass", "height", "width", "noise", "visibility"]:
		if not FrameStats.BASE.has(name):
			fails.append("the frame has no '%s'" % name)

	print("RESULT stock mass=%.1f walk=%.2f sprint=%.2f jump=%.2f tank=%.1f brake=%.2f grip(rock)=%.2f"
			% [stock.mass(), stock.walk_speed(), stock.sprint_speed(), stock.jump_velocity(),
			stock.tank(), stock.brake_scale(), stock.grip("rock")])
	if fails.is_empty():
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)