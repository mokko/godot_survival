extends Control
## Story screen — sits between the splash menu and the game. Shows intro
## text typed letter by letter on a near-black background. ESC or a left
## click immediately enters the game (no text advancement).

const GAME_SCENE := "res://world/main.tscn"
const CHARS_PER_SEC := 40.0

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
	# Immediate visual feedback: the world scene takes a while to load, but
	# the player should see the skip register the instant they press.
	$Center/VBox/Text.hide()
	$Center/VBox/Hint.text = "Loading..."
	$Center/VBox/Hint.show()
	await get_tree().process_frame   # let the label draw before the freeze
	get_tree().change_scene_to_file(GAME_SCENE)
