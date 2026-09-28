extends SceneTree
## Headless check: the Robo Editor's readout — the drone's numbers on the screen beside the picture,
## in two lists (what the game reads today, and what is declared and read by nothing yet), each line
## showing what a part costs by.
##
## **The screen must not be able to lie about the drone**: every line is asked of the same frame the
## player is holding, so this checks the readout against the frame rather than against a number
## written down here — the same rule the Pedia's plates follow, and the reason `ItemIcons.icon_ops()`
## exists at all.

const FrameStats := preload("res://player/frame_stats.gd")
const SaveGame := preload("res://world/savegame.gd")


func _init() -> void:
	var fails: PackedStringArray = []
	# A fresh run, so the drone is in its stock parts and nothing is restored over them.
	SaveGame.pending_new_run = true
	SaveGame.pending_load = false
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 20:
		await physics_frame

	var player = main.get_node("Player")
	var editor: Control = main.get_node("HUD/PauseMenu/Editor")
	if editor == null:
		print("RESULT FAIL: no editor on the pause menu")
		quit(1)
		return
	editor.open()
	for i in 2:
		await process_frame

	# 1. The stock drone's numbers, and no deltas at all: nothing has been changed yet, so no line
	#    should read as a cost.
	if editor.stat_value("walk_speed") != "5.0 m/s":
		fails.append("stock walk reads '%s'" % editor.stat_value("walk_speed"))
	if editor.stat_value("mass") != "41.0 kg":
		fails.append("stock mass reads '%s'" % editor.stat_value("mass"))
	for key in ["walk_speed", "sprint_speed", "jump_velocity", "tank", "brake_scale",
			"eye_height", "mass", "noise"]:
		if editor.stat_value(key).contains("("):
			fails.append("a stock frame shows a cost on %s: '%s'"
					% [key, editor.stat_value(key)])
	if editor.stat_value("grip_rock") != "1.00":
		fails.append("stock grip reads '%s'" % editor.stat_value("grip_rock"))

	# 2. The two lists are two lists: what the game reads is in one, what nothing reads is in the
	#    other. A number the game ignores must not sit where an obeyed one sits.
	if editor.now_stats.get_node_or_null("Value_walk_speed") == null:
		fails.append("the walk is not in the list of what the game reads")
	if editor.now_stats.get_node_or_null("Value_mass") != null:
		fails.append("mass is listed as something the game reads")
	if editor.later_stats.get_node_or_null("Value_mass") == null:
		fails.append("mass is not in the list of what nothing reads yet")
	if editor.later_stats.get_node_or_null("Value_grip_bog") == null:
		fails.append("a surface has no row of its own")
	for surface in FrameStats.SURFACES:
		if editor.later_stats.get_node_or_null("Value_grip_%s" % surface) == null:
			fails.append("the frame declares '%s' and the readout has no row for it" % surface)

	# 3. Fit something slower and the readout follows — **and says what it cost**. Walking legs are
	#    the far end of the legs catalogue, so one step back from the stock fit reaches them.
	if not editor.cycle("legs", -1):
		fails.append("stepping back through the legs changed nothing")
	for i in 2:
		await process_frame
	if editor.fitted("legs") != "legs_telescope":
		fails.append("the legs row landed on '%s'" % editor.fitted("legs"))
	var frame = player.frame
	if absf(frame.walk_speed() - 4.0) > 0.001:
		fails.append("telescope legs walk at %.2f, not 4.0" % frame.walk_speed())
	if editor.stat_value("walk_speed") != "4.0 m/s  (-1.00)":
		fails.append("the walk line reads '%s'" % editor.stat_value("walk_speed"))
	# The run is a multiple of the walk, so it moved with it — and its cost is bigger in the same
	# direction, which is what a player is deciding about.
	if editor.stat_value("sprint_speed") != "8.0 m/s  (-2.00)":
		fails.append("the run line reads '%s'" % editor.stat_value("sprint_speed"))
	if editor.stat_value("mass") != "36.0 kg  (-5.00)":
		fails.append("the mass line reads '%s'" % editor.stat_value("mass"))

	# 4. The readout cannot drift from the drone: every line re-asked of the frame the player holds
	#    must match what the screen says, whoever changed the part and however.
	var live := {"walk_speed": "%.1f m/s", "sprint_speed": "%.1f m/s", "jump_velocity": "%.2f",
			"tank": "%.0f", "brake_scale": "%.2f×", "eye_height": "%.2f m", "mass": "%.1f kg",
			"noise": "%.2f"}
	for key in live:
		if not editor.stat_value(key).begins_with(str(live[key] % frame.stat(key))):
			fails.append("the screen says '%s' for %s, the frame says %s"
					% [editor.stat_value(key), key, live[key] % frame.stat(key)])
	# ...including a part fitted behind the screen's back, which is what a load or another system
	# would do: the readout is refreshed from the frame, never from its own memory of a press.
	player.fit_body_part("torso", "torso_plated")
	editor.refresh()
	for i in 2:
		await process_frame
	if not editor.stat_value("tank").begins_with("48"):
		fails.append("the readout missed a part fitted elsewhere: charge '%s'"
				% editor.stat_value("tank"))
	if not editor.stat_value("tank").contains("+8.00"):
		fails.append("a bigger tank does not read as a gain: '%s'" % editor.stat_value("tank"))

	print("RESULT walk='%s' run='%s' mass='%s' charge='%s' grip(rock)='%s'"
			% [editor.stat_value("walk_speed"), editor.stat_value("sprint_speed"),
			editor.stat_value("mass"), editor.stat_value("tank"),
			editor.stat_value("grip_rock")])
	main.queue_free()
	if fails.is_empty():
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)