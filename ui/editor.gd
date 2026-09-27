extends Control
## The Frame screen — where the drone's body is serviced, at a service bench.
## **Its heading reads "Robo Editor"** (Maurice's call, 27 Sep: the heading is the tool's name,
## and "Frame" was the code's word for it). The file, the node, `PauseMenu.open_editor()` and the
## docs all still say Frame; renaming those is a separate pass if it is wanted.
##
## **Opened from a service bench, and — while it is being built — from the pause menu**
## (`world/bench.gd`, and `ui/pause_menu.gd`'s debug entry): both go through
## `PauseMenu.open_editor()`, which owns ESC. Closing hands the player straight back to the game
## rather than to the menu — they were playing, not browsing, and **nothing here handles ESC**.
##
## **Three families, cycled with ◀ ▶** (Maurice, 27 Sep): what the drone is made of —
## `player/torsos.gd`, `player/heads.gd`, `player/legs.gd`. One row per family, showing that part's
## name with a button either side; the walk wraps, so a row is never a dead end.
##
## **Every variant is reachable for now.** The parts are cosmetics that change nothing, and the
## editor is being built, so all of them have to be selectable without finding anything: fitting
## goes through `player/player.gd::fit_body_part()` — one door, and exactly where the ownership
## rule lands when parts start to matter ("eventually we'll work with the parts we have found").
## The found-parts loop (`player/robot_parts.gd`, `items/part_pickup.gd`) is untouched, and
## `fit_legs()` still carries the old gate for that path.
##
## **Next: a picture of the drone.** The screen is meant to *show* the machine as it stands now,
## not just name its parts — a `SubViewport` with a camera, a light and the model rebuilt from the
## same three ids (one builder, so the picture and the real drone cannot drift).

const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")

signal closed

## Where the bench that opened this stands — shown, so the screen is clearly about *this*
## bench and not an abstract menu.
var island := ""

@onready var subtitle: Label = $Center/Padding/Panel/VBox/Subtitle
@onready var fits: VBoxContainer = $Center/Padding/Panel/VBox/Fits
@onready var body: Label = $Center/Padding/Panel/VBox/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

## The three families, in the order they are shown: [kind, label, catalogue]. `STOCK` leads its own
## catalogue in every family, so walking one wraps through the whole set — including the part the
## drone was built with.
var _families: Array = [
	["torso", "Body", Torsos],
	["head", "Head", Heads],
	["legs", "Legs", Legs],
]

var _player: Node3D = null
var _labels := {}      # kind -> the Label showing that family's current part
var _rows := {}        # kind -> its HBoxContainer


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	_build_rows()


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
	## Re-read every row from the drone. Public because a test drives it directly, and because
	## anything that changes a part while this is open has to be able to say so.
	for entry in _families:
		var kind: String = entry[0]
		var label: Label = _labels.get(kind)
		if label == null:
			continue
		label.text = "%s: %s" % [str(entry[1]), _name_of(entry[2], fitted(kind))]
	body.text = "Cycle each part with ◀ ▶.\nNothing here changes how the drone behaves — yet."


func fitted(kind: String) -> String:
	## Which part of that kind is on the drone right now; "" when there is nothing to ask.
	if _player == null or _player.equipment == null:
		return ""
	match kind:
		"torso":
			return str(_player.equipment.fitted_torso())
		"head":
			return str(_player.equipment.fitted_head())
		"legs":
			return str(_player.equipment.fitted_legs())
	return ""


func cycle(kind: String, step: int) -> bool:
	## Walk one family's catalogue by `step` and put the result on the drone. True when something
	## changed; the ends wrap, so a press is never ignored.
	if step == 0:
		return false
	var catalogue: GDScript = _catalogue(kind)
	if catalogue == null:
		return false
	var ids: Array = family_ids(kind)
	if ids.is_empty():
		return false
	var current: int = ids.find(fitted(kind))
	var next: String = str(ids[posmod(current + step, ids.size())])
	if _player == null or not _player.has_method("fit_body_part"):
		return false
	if not _player.fit_body_part(kind, next):
		return false
	refresh()
	return true


func rows() -> Array:
	## The part each family is showing right now, in family order — for tests and anything
	## counting them.
	var out: Array = []
	for entry in _families:
		out.append(fitted(str(entry[0])))
	return out


func family_ids(kind: String) -> Array:
	## The whole catalogue of one family, stock first: what that row walks.
	var catalogue: GDScript = _catalogue(kind)
	if catalogue == null:
		return []
	return [catalogue.STOCK] + catalogue.PARTS.duplicate()


func _catalogue(kind: String) -> GDScript:
	for entry in _families:
		if str(entry[0]) == kind:
			return entry[2]
	return null


func _name_of(catalogue: GDScript, id: String) -> String:
	return str(catalogue.NAMES.get(id, id))


func _build_rows() -> void:
	## Built in code, like the rest of this game's HUD: the scene holds the panel, the subtitle,
	## the body line and Back, and anything that lists things builds its own list. Every node a
	## test reaches for is named (`Row_<kind>`, `Prev_<kind>`, `Name_<kind>`, `Next_<kind>`), so
	## nothing has to be found by index.
	for entry in _families:
		var kind: String = entry[0]
		var row := HBoxContainer.new()
		row.name = "Row_%s" % kind
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var prev := Button.new()
		prev.name = "Prev_%s" % kind
		prev.text = "◀"
		prev.add_theme_font_size_override("font_size", 22)
		prev.pressed.connect(cycle.bind(kind, -1))
		row.add_child(prev)
		var label := Label.new()
		label.name = "Name_%s" % kind
		label.custom_minimum_size = Vector2(260, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		row.add_child(label)
		_labels[kind] = label
		var next := Button.new()
		next.name = "Next_%s" % kind
		next.text = "▶"
		next.add_theme_font_size_override("font_size", 22)
		next.pressed.connect(cycle.bind(kind, 1))
		row.add_child(next)
		fits.add_child(row)
		_rows[kind] = row
