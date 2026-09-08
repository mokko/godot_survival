extends Control
## Story screen — sits between the splash menu and the game. Shows intro
## text typed letter by letter on a near-black background. ESC or a left
## click immediately enters the game (no text advancement).

const GAME_SCENE := "res://main.tscn"
const CHARS_PER_SEC := 40.0

## The story so far: intro sentence repeated 3x (stand-in for the future
## full-length text, hardwired as one string).
const FULL_TEXT := """this text introduces character, setting and reasons for game play

this text introduces character, setting and reasons for game play

this text introduces character, setting and reasons for game play
"""

@onready var label: Label = $Center/VBox/Text

var _shown := 0.0            # characters revealed so far (float accumulator)
var _done := false


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
	get_tree().change_scene_to_file(GAME_SCENE)
