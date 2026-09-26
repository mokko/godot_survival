extends Control
## Story screen — sits between the splash menu and the game. Shows intro
## text typed letter by letter on a near-black background, **as a mechanical
## typewriter**: a monospace typewriter face, a clack per character, and a
## carriage return with its bell at every line break. ESC or a left click (at any
## point, even mid-typing) immediately enters the game.
##
## The click is handled in _unhandled_input, so every node in story.tscn must
## keep mouse_filter = MOUSE_FILTER_IGNORE: a Control on the default STOP grabs
## the click during GUI hit-testing, marks it handled, and the event never
## reaches this script (that is why only ESC used to work). If you add a button
## here later, give it STOP but connect it — do not re-enable STOP on the
## full-rect Background/Center container, which would swallow every click.
##
## The typing is paced in _process: characters come out at CHARS_PER_SEC, a line
## break stops the reveal for RETURN_PAUSE so the carriage can travel, and the
## sounds are fired from the characters actually revealed rather than from a
## separate clock, so they can never drift from the text.

const GAME_SCENE := "res://world/main.tscn"
## Typewriter speed. 28 cps reads as deliberate narration; 40 rushed it (the
## whole intro lands in ~15 s, and a click or ESC still skips at any point).
const CHARS_PER_SEC := 28.0
## A clack does not fire faster than this however fast the reveal runs. At 28 cps
## a clack on every single character is one solid buzz rather than typing, so the
## shortest gap wins and the rest of the characters come out silently.
const KEY_MIN_GAP := 0.055
## The beat at the end of a line. A typewriter's carriage return is not instant,
## and the pause is what makes a newline read as a newline instead of as the next
## sentence arriving on its own.
const RETURN_PAUSE := 0.26
## Sits at the end of the revealed text while the machine is still typing, the way
## a cursor waits for the next keystroke. Dropped once the intro is complete, so
## the finished screen is the finished text.
const CURSOR := "▌"
## Key clacks are the loudest thing here because they repeat ~18 times a second;
## the return is a one-off and can ring.
const KEY_VOLUME_DB := -12.0
const RETURN_VOLUME_DB := -7.0

## The intro, lifted from story.md § Premise. Typed out by _process; the
## player skips it with a click or ESC (see research/old.md/story.md for the fuller
## narrative it should eventually grow into).
const FULL_TEXT := """You are a mind without a body.

Not dead — displaced. Somewhere behind you is a life you can no longer
reach, and a name you cannot remember.

What you have is a drone: small, patient. Through it you see and hear and
touch this place — all of it secondhand, remote.

You wake on a shore that is not Japan, and is shaped like Japan.
Someone built this. Someone put you here.

You do not yet know why.
"""

@onready var label: Label = $Center/VBox/Text

var _shown := 0.0            # characters revealed so far (float accumulator)
var _done := false
var _starting := false
var _hold := 0.0             # seconds left of a carriage-return beat
var _since_key := 99.0       # seconds since the last clack
var _snd_key: AudioStreamPlayer = null
var _snd_return: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()


func _make_snd(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	label.text = ""
	# Two players on purpose: the carriage return has to ring on while the next
	# line's clacks start, and one player would cut it off.
	_snd_key = _make_snd("res://sounds/type_key.wav", KEY_VOLUME_DB)
	_snd_return = _make_snd("res://sounds/type_return.wav", RETURN_VOLUME_DB)
	_rng.seed = 20260926          # the same intro sounds the same every run


func _process(delta: float) -> void:
	if _done or _starting:
		return
	_since_key += delta
	if _hold > 0.0:
		# Mid carriage-return: the text stands still and the beat runs out.
		_hold = maxf(_hold - delta, 0.0)
		return
	var before := int(_shown)
	var limit := FULL_TEXT.length()
	_shown = minf(_shown + CHARS_PER_SEC * delta, float(limit))
	var now := int(_shown)
	# A line break among the characters just revealed stops the reveal *at* the break,
	# so the carriage return happens at the end of a line and the next line starts
	# after the beat. Without this the break would be ordinary and the bell would ring
	# somewhere inside the following sentence.
	var brk := FULL_TEXT.find("\n", before)
	if brk != -1 and brk < now:
		now = brk + 1
		_shown = float(now)
		if _snd_return != null:
			_snd_return.play()
		_hold = RETURN_PAUSE
	if now > before:
		_clack()
	label.text = FULL_TEXT.substr(0, now) + (CURSOR if now < limit else "")
	if now >= limit:
		_done = true
		label.text = FULL_TEXT
		$Center/VBox/Hint.text = "click or press ESC to begin"


func _clack() -> void:
	## One key clack, if enough time has passed for a separate one to be heard, and a
	## little pitch scatter so a line of them does not sound like a machine gun.
	if _since_key < KEY_MIN_GAP:
		return
	_since_key = 0.0
	if _snd_key == null:
		return
	_snd_key.pitch_scale = _rng.randf_range(0.92, 1.08)
	_snd_key.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_start_game()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_start_game()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	# The machine stops with the screen: no clacks under the loading wait.
	if _snd_key != null:
		_snd_key.stop()
	if _snd_return != null:
		_snd_return.stop()
	# Immediate visual feedback: the world scene takes a while to load (several
	# seconds on a Rock 5B), so the player must see the skip register the
	# instant they press.
	$Center/VBox/Text.hide()
	$Center/VBox/Hint.text = "Loading..."
	$Center/VBox/Hint.show()
	# The hint has to actually reach the screen before the load blocks the
	# main thread. `process_frame` is emitted *before* drawing, and
	# RenderingServer.frame_post_draw never fires in headless runs, so wait a
	# few real frames on a short timer instead: change_scene_to_file()
	# instantiates the new scene on the spot and freezes everything.
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file(GAME_SCENE)