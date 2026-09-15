extends Node
## Display toggle autoload: F11 flips fullscreen/windowed anywhere in the game
## — main menu, mid-run, and while the pause menu has the tree paused, which is
## why this node runs with PROCESS_MODE_ALWAYS.
##
## The choice is persisted through options.gd (the same "fullscreen" option the
## splash options panel edits), so F11 sticks across sessions and the panel's
## checkbox reflects it next time it opens.

const Options := preload("res://ui/options.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> bool:
	## Flip the persisted option and apply it now. Returns the new value.
	var now_fullscreen: bool = not bool(Options.get_option("fullscreen"))
	Options.set_option("fullscreen", now_fullscreen)
	Options.apply_display()
	return now_fullscreen
