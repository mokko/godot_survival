extends Control
## The Frame screen — where the drone's body is serviced, at a service bench.
##
## **Opened from a service bench and nowhere else** (`world/bench.gd` calls
## `PauseMenu.open_editor`): there is deliberately no pause-menu button, because a bench
## you have to find is the whole point. Which also means closing this hands the player
## straight back to the game rather than to the menu — they were playing, not browsing.
##
## **Nothing here handles ESC**: the pause menu owns that key and calls `close()`, so
## there is exactly one owner and no race (the same rule the Pedia follows).
##
## The list is **what the drone owns**, from `player/robot_parts.gd`: the parts it found
## and the stock fit it was built with. Fitting goes through `player.fit_legs()`, because
## that is where the ownership rule lives — this screen never calls the equipment
## directly, so no part can be fitted by guessing an id. A part the player has not found
## is not listed at all, so the screen never teases something that does not exist yet.

const Legs := preload("res://player/legs.gd")

signal closed

## Where the bench that opened this stands — shown, so the screen is clearly about *this*
## bench and not an abstract menu.
var island := ""

@onready var subtitle: Label = $Center/Padding/Panel/VBox/Subtitle
@onready var fits: VBoxContainer = $Center/Padding/Panel/VBox/Fits
@onready var body: Label = $Center/Padding/Panel/VBox/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

const SECTION := "Legs"
const LINE_EMPTY := "Nothing but its own treads so far."
const LINE_HELP := "Parts found out on the island can be bolted on here."

var _player: Node3D = null


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)


func open(bench: Node = null) -> void:
	visible = true
	island = str(bench.get("island")) if bench != null else ""
	subtitle.text = ("Service bench — %s" % island) if island != "" else "Service bench"
	_player = get_tree().get_first_node_in_group("player")
	refresh()
	back_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	## Rebuild the list from what the drone owns and what it is wearing. Public because a
	## test drives it directly, and because anything that changes the fit while this is
	## open has to be able to say so.
	for child in fits.get_children():
		fits.remove_child(child)
		child.queue_free()
	var current := fitted()
	var known: Array = [Legs.STOCK] + Legs.PARTS.duplicate()
	var shown := 0
	for id in known:
		if not _owns(id):
			continue
		fits.add_child(_row(id, id == current))
		shown += 1
	body.text = "%s\n%s" % [SECTION, LINE_EMPTY if shown <= 1 else LINE_HELP]


func fitted() -> String:
	## What the drone is wearing right now; "" when there is nothing to ask.
	if _player == null or not _player.has_method("fit_legs"):
		return ""
	return str(_player.equipment.fitted_legs())


func rows() -> Array:
	## The fit ids on screen, in order — for tests and for anything counting them.
	var out: Array = []
	for child in fits.get_children():
		out.append(str(child.name).trim_prefix("Fit_"))
	return out


func _owns(id: String) -> bool:
	if _player == null or not _player.has_method("owns_part"):
		return id == Legs.STOCK
	return _player.owns_part(id)


func _row(id: String, is_fitted: bool) -> Button:
	## One fit: its name, and whether it is the one on the drone. The row already fitted
	## is disabled rather than merely labelled — a button that does nothing when pressed
	## reads as broken, and this one has nothing left to do.
	var button := Button.new()
	button.name = "Fit_%s" % id
	button.add_theme_font_size_override("font_size", 22)
	button.text = str(Legs.NAMES.get(id, id))
	if is_fitted:
		button.text += "   · fitted"
		button.disabled = true
	else:
		button.pressed.connect(_on_fit.bind(id))
	return button


func _on_fit(id: String) -> void:
	if _player == null or not _player.has_method("fit_legs"):
		return
	if _player.fit_legs(id):
		refresh()