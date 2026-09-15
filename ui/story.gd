extends Control
## Story screen — sits between the splash menu and the game. Shows intro
## text typed letter by letter on a near-black background. ESC or a left
## click (at any point, even mid-typing) immediately enters the game.
##
## The click is handled in _unhandled_input, so every node in story.tscn must
## keep mouse_filter = MOUSE_FILTER_IGNORE: a Control on the default STOP grabs
## the click during GUI hit-testing, marks it handled, and the event never
## reaches this script (that is why only ESC used to work). If you add a button
## here later, give it STOP but connect it — do not re-enable STOP on the
## full-rect Background/Center container, which would swallow every click.

const GAME_SCENE := "res://world/main.tscn"
## Typewriter speed. 28 cps reads as deliberate narration; 40 rushed it (the
## whole intro lands in ~15 s, and a click or ESC still skips at any point).
const CHARS_PER_SEC := 28.0

## The intro, lifted from story.md § Premise. Typed out by _process; the
## player skips it with a click or ESC (see research.md/story.md for the fuller
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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	label.text = ""


func _process(delta: float) -> void:
	if _done:
		return
	_shown = minf(_shown + CHARS_PER_SEC * delta, FULL_TEXT.length())
	label.text = FULL_TEXT.substr(0, int(_shown))
	if int(_shown) >= FULL_TEXT.length():
		_done = true
		$Center/VBox/Hint.text = "click or press ESC to begin"


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
