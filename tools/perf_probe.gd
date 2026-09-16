extends SceneTree
## Frame-rate benchmark for the world scene. Run it through tools/perf_test.sh,
## which sorts out the display environment first.
##
## Why this exists: the headless test suite cannot see rendering at all
## (--headless has no renderer), so a graphics change that halves the frame rate
## still passes every test. Run this before every release and record the numbers.
##
## It toggles the graphics options inside one session and reports draw calls and
## primitives per frame next to the frame rate, because this machine renders
## through the Compatibility backend without vsync: frames-per-second alone can
## look healthy while nothing is being drawn. If the sample reports 0 frames
## drawn, the window was never presented and every number is meaningless — the
## probe says so explicitly and exits non-zero.

const WINDOW := Vector2i(960, 600)
## Frames can take ~1 s on this machine while the window is obscured, so these are
## deliberately small: Engine.get_frames_per_second() is already an average over the
## last second, and 120 frames per configuration is plenty to compare builds.
const SETTLE_FRAMES := 60
const SAMPLE_FRAMES := 120

var _env: Environment
var _clutter: Node
var _fails := 0


func _init() -> void:
	# Never benchmark fullscreen, and never make noise.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW)

	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_env = main.get_node("WorldEnvironment").environment
	_clutter = main.get_node_or_null("Clutter")

	print("BENCH adapter=%s display=%s window=%s"
			% [RenderingServer.get_video_adapter_name(), DisplayServer.get_name(),
			str(DisplayServer.window_get_size())])
	print("BENCH godot=%s renderer=%s"
			% [Engine.get_version_info()["string"], ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", "?")])

	for i in SETTLE_FRAMES:
		await process_frame

	await _sample("msaa x2 + ssao + clutter", _env.ssao_enabled)
	_env.ssao_enabled = false
	await _sample("ssao off", false)
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _sample("ssao off + msaa off", false)
	_env.ssao_enabled = true
	root.msaa_3d = Viewport.MSAA_2X
	if _clutter != null:
		_clutter.visible = false
	await _sample("ssao + msaa, clutter hidden", true)
	_clutter.visible = true

	if _fails > 0:
		print("RESULT BENCHMARK INVALID: %d sample(s) drew no frames — "
				% _fails + "the window was not presented (headless? no DISPLAY?)")
		quit(1)
	print("RESULT BENCHMARK OK")
	quit(0)


func _sample(label: String, ssao: bool) -> void:
	## One configuration: settle, then average over SAMPLE_FRAMES.
	for i in 10:
		await process_frame
	var fps := 0.0
	var worst := INF
	var draws := 0.0
	var prims := 0.0
	var drawn0 := Engine.get_frames_drawn()
	for i in SAMPLE_FRAMES:
		await process_frame
		var f := Engine.get_frames_per_second()
		fps += f
		worst = minf(worst, f)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var n := float(SAMPLE_FRAMES)
	var drawn := Engine.get_frames_drawn() - drawn0
	if drawn <= 0:
		_fails += 1
	print("BENCH | %-30s | ssao=%-5s | %6.1f fps avg | %6.1f fps worst | "
			% [label, str(ssao), fps / n, worst]
			+ "%6.1f draws | %9.0f prims | %d frames drawn"
			% [draws / n, prims / n, drawn])
