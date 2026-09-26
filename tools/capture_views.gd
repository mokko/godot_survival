extends SceneTree
## Dev tool: render the world from a fixed set of camera poses and write PNGs, so
## graphics changes can actually be looked at instead of guessed at.
##
## Run (needs a display — pass the session env explicitly if the shell has none):
##   cd ~/snap/godot-4/common/survivalm
##   env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
##     snap run godot-4 --audio-driver Dummy --script res://tools/capture_views.gd \
##     -- /tmp/survivalm_shots
##
## The window is forced windowed and small (the project boots fullscreen), the HUD
## is hidden so the frame is just the world, and a free camera is used so the poses
## do not depend on the player's movement code. Biome poses are sampled through
## Ezo.random_land_point() with a fixed seed, so a given build always yields the
## same shots and two runs can be diffed.

const WINDOW := Vector2i(1280, 720)
const SEED := 20260915
const DEFAULT_DIR := "user://shots"
const FOV := 70.0
## Frames to let a pose (and the clutter window, which follows the player) settle.
## The clutter window needs ~30 frames to build at its 2 ms/frame budget; on this
## machine frames can take up to a second while the window is obscured, so keep
## this as low as the clutter needs.
const SETTLE_FRAMES := 30
## eye = metres above the terrain; pitch is degrees, negative looks down.
## Biome keys are sampled with the fixed seed; "centre" poses on the caldera.
## A view inherits the previous view's time of day unless it sets "time", so any
## view needing daylight has to say so.
const VIEWS := [
	{"name": "01_ground_closeup", "x": -112.0, "z": 82.0, "eye": 1.7,
		"yaw": 25.0, "pitch": -38.0},
	{"name": "02_coast", "biome": "coast", "eye": 1.7, "downhill": true,
		"pitch": -6.0},
	{"name": "03_inland", "biome": "anywhere", "inland": 25.0, "eye": 1.7,
		"yaw": 20.0, "pitch": -4.0},
	{"name": "04_massif", "biome": "massif", "eye": 1.7, "yaw": 200.0,
		"pitch": -8.0},
	{"name": "05_caldera_lake", "caldera": true, "eye": 1.7, "look_centre": true,
		"pitch": -5.0},
	{"name": "06_night_coast", "biome": "coast", "eye": 1.7, "downhill": true,
		"pitch": -6.0, "time": 0.92},
	{"name": "07_boat_ezo", "x": 38.0, "z": 120.0, "eye": 2.8, "yaw": -135.0,
		"pitch": -14.0, "time": 0.3},
	# The Ezo service bench, seen from the beach side it faces (it stands ~30 m
	# inland of the Ezo mooring at z≈114, working face toward +Z).
	{"name": "08_bench_ezo", "x": 33.0, "z": 87.0, "eye": 1.6, "yaw": 180.0,
		"pitch": -9.0, "time": 0.3},
]

var _out_dir := DEFAULT_DIR
## Optional second argument: only shoot views whose name starts with this, so
## iterating on one asset does not re-render the whole set.
var _only := ""
var _day_cycle: Node
var _player: Node3D
var _clutter: Node


func _init() -> void:
	# Never run this against the player's real options or in a fullscreen window.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_only = args[1]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("shots: writing to %s (display=%s adapter=%s)" % [_out_dir,
			DisplayServer.get_name(), RenderingServer.get_video_adapter_name()])

	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	# The world scene's HUD would otherwise sit in the middle of every shot.
	var hud: Node = main.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	_day_cycle = main.get_node_or_null("DayCycle")
	_clutter = main.get_node_or_null("Clutter")

	var cam := Camera3D.new()
	cam.name = "ShotCamera"
	cam.fov = FOV
	root.add_child(cam)

	for i in 30:
		await process_frame

	# The player joins its group in its own _ready, which does not run until the tree
	# ticks — looked up in the same breath as add_child() this is null, and the "carry
	# the player along" step below then quietly does nothing, leaving the clutter window
	# at the spawn for every later shot.
	_player = get_first_node_in_group("player")
	if _player == null:
		push_warning("shots: no player in the tree — the clutter window will not follow")

	seed(SEED)   # Ezo.random_land_point() is unseeded RNG: fix it for repeatability
	for view in VIEWS:
		if _only != "" and not String(view["name"]).begins_with(_only):
			continue
		await _shoot(cam, view)
	cam.queue_free()
	main.queue_free()
	print("shots: done")
	quit(0)


func _shoot(cam: Camera3D, view: Dictionary) -> void:
	var spot := _spot(view)
	if spot == Vector3.INF:
		push_warning("shots: could not place view '%s'" % view["name"])
		return
	# Day cycle first, so the glow/lighting has a frame or two to settle.
	if view.has("time") and _day_cycle != null:
		_day_cycle.time_of_day = view["time"]
	var yaw: float = deg_to_rad(view.get("yaw", 0.0))
	if view.get("downhill", false):
		yaw = _downhill_yaw(spot.x, spot.z)
	var eye: float = view.get("eye", 1.7)
	# Carry the player along with the camera: the clutter window follows the
	# player, so a camera-only teleport photographs an empty world.
	if _player != null:
		_player.global_position = Vector3(spot.x,
				Ezo.height_at(spot.x, spot.z) + 0.5, spot.z)
		# Build this pose's scatter window right away instead of hoping the budgeted
		# fills catch up. A teleport of a hundred metres or more leaves every cell new,
		# and the 30 settle frames below are not enough for that: the bench view came
		# out with 0 pebbles, 0 twigs and 0 tufts, which reads as "no scatter here"
		# rather than as the tool racing itself. plan_fill() is the synchronous path
		# clutter.gd keeps for exactly this.
		if _clutter != null and _clutter.has_method("plan_fill"):
			_clutter.plan_fill(Vector2(spot.x, spot.z))
	for i in SETTLE_FRAMES:
		await process_frame
	cam.global_position = Vector3(spot.x, Ezo.height_at(spot.x, spot.z) + eye, spot.z)
	var target := spot
	if view.get("look_centre", false):
		target = Vector3(Ezo.CALDERA_CENTER.x,
				Ezo.height_at(Ezo.CALDERA_CENTER.x, Ezo.CALDERA_CENTER.y) + 2.0,
				Ezo.CALDERA_CENTER.y)
	var pitch: float = deg_to_rad(view.get("pitch", 0.0))
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at(cam.global_position + dir * 12.0, Vector3.UP)
	cam.current = true
	# Let the renderer draw this pose (and the new day time) before grabbing.
	# frame_post_draw is the textbook signal for this, but it never fires when the
	# window is not actually being presented (e.g. an off-screen Wayland client),
	# which hangs the tool — so wait on process_frame and force a draw instead.
	for i in 3:
		await process_frame
	RenderingServer.force_draw()
	var path := "%s/%s.png" % [_out_dir.trim_suffix("/"), view["name"]]
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	var lum := _mean_luminance(img)
	print("  %-18s at (%.1f, %.1f) yaw %.0f pitch %.0f -> %s (%s) lum %.3f%s%s" % [
			view["name"], spot.x, spot.z, rad_to_deg(yaw),
			view.get("pitch", 0.0), path, error_string(err), lum,
			"" if lum > 0.01 else "  ⚠ frame is black: window not presented?",
			_clutter_counts()])


func _clutter_counts() -> String:
	## Scatter is windowed around the player, so log what was on screen.
	if _clutter == null:
		return ""
	var n := []
	for child in _clutter.get_children():
		var mm: MultiMesh = child.multimesh
		n.append("%s %d" % [child.name, mm.visible_instance_count if mm else -1])
	return "  clutter: " + ", ".join(n)


func _mean_luminance(img: Image) -> float:
	## Cheap check that something was actually rendered — a black frame means the
	## window was never presented, which is easy to mistake for a bad camera pose.
	var total := 0.0
	var n := 0
	for y in range(0, img.get_height(), 12):
		for x in range(0, img.get_width(), 12):
			total += img.get_pixel(x, y).get_luminance()
			n += 1
	return total / float(maxi(n, 1))


func _spot(view: Dictionary) -> Vector3:
	if view.has("x"):
		return Vector3(view["x"], 0.0, view["z"])
	if view.get("caldera", false):
		# Stand on the rim, looking across the lake.
		var c := Ezo.CALDERA_CENTER
		return Vector3(c.x, 0.0, c.y - (Ezo.LAKE_RADIUS + 9.0))
	if view.has("biome"):
		for attempt in 40:
			var p: Vector3 = Ezo.random_land_point(view["biome"])
			if p == Vector3.INF:
				continue
			# The sampler falls back to the spawn point when a biome finds
			# nothing; treat that as a miss rather than shooting the spawn twice.
			if p.distance_to(Ezo.spawn_point()) < 0.01:
				continue
			if view.has("inland") \
					and Ezo.signed_distance(Vector2(p.x, p.z)) < view["inland"]:
				continue
			return p
	return Vector3.INF


func _downhill_yaw(x: float, z: float) -> float:
	## Face the way the ground falls away, so a coastal camera actually has the
	## sea in frame instead of a wall of grass.
	const S := 6.0
	var dx := Ezo.height_at(x + S, z) - Ezo.height_at(x - S, z)
	var dz := Ezo.height_at(x, z + S) - Ezo.height_at(x, z - S)
	if absf(dx) < 0.0001 and absf(dz) < 0.0001:
		return 0.0
	return atan2(-dx, -dz)