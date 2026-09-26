extends Control
## The Frame screen — where the drone's body is serviced.
##
## **Opened from a service bench and nowhere else** (`world/bench.gd` calls
## `PauseMenu.open_editor`): there is deliberately no pause-menu button, because a
## bench you have to find is the whole point. Which also means closing this hands the
## player straight back to the game rather than to the menu — they were playing, not
## browsing.
##
## **Nothing here handles ESC**: the pause menu owns that key and calls `close()`,
## so there is exactly one owner and no race (the same rule the Pedia follows).
##
## This is a first cut: the frame is described, but no parts exist yet to fit into
## it. The slot list arrives with the parts the player finds on the island.

signal closed

## Where the bench that opened this stands — shown, so the screen is clearly about
## *this* bench and not an abstract menu.
var island := ""

@onready var subtitle: Label = $Center/Padding/Panel/VBox/Subtitle
@onready var body: Label = $Center/Padding/Panel/VBox/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

const LINE_EMPTY := "Nothing is fitted here yet."
const LINE_HELP := "Parts found out on the island will be fitted from a bench like this one."


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)


func open(bench: Node = null) -> void:
	visible = true
	island = str(bench.get("island")) if bench != null else ""
	subtitle.text = ("Service bench — %s" % island) if island != "" else "Service bench"
	body.text = "%s\n%s" % [LINE_EMPTY, LINE_HELP]
	back_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()