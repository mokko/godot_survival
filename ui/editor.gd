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
## **A picture of the drone, not just its parts' names** (Maurice, 27 Sep): the left column is a
## `SubViewport` holding a real `player/drone_model.gd` — the same builder the player's machine
## uses — with a camera, a key light and a fill. Cycling a part shows the change, which is the whole
## point of a fitting bench. The camera is on **-Z**, the side the drone faces, so its eye and chest
## lens are in the picture (the player's own camera sits behind the machine and would show its
## back). Nothing here is a rendering of a screenshot: the model is rebuilt from the same three ids
## the drone is wearing, so the picture cannot drift from the machine.
##
## The camera, lights and model are built in code — 3D is code everywhere in this project — and the
## scene holds only the container and the viewport. The viewport renders **while the screen is
## open** (`UPDATE_WHEN_PARENT_VISIBLE`), so a closed bench costs nothing.

const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")
const DroneModel := preload("res://player/drone_model.gd")

## Where the picture's camera stands: front-right of the machine, a little above its middle, and
## where it looks — roughly the middle of the machine, in the drone's own space, whose origin is on
## the ground. The distance is set so the **whole** machine fits with a margin, and it is sized for
## the **tallest head** rather than the stock one: the dish head's dish reaches about 1.45 m, so the
## frame — about 2.5 m away at this field of view — is roughly 1.9 m tall. Pull the camera closer and
## the dish, or lower down the treads, falls off the edge.
const PREVIEW_EYE := Vector3(0.95, 0.95, -2.30)
const PREVIEW_LOOK := Vector3(0.0, 0.66, 0.0)
const PREVIEW_FOV := 42.0

signal closed

## Where the bench that opened this stands — shown, so the screen is clearly about *this*
## bench and not an abstract menu.
var island := ""

@onready var subtitle: Label = $Center/Padding/Panel/VBox/Subtitle
@onready var fits: VBoxContainer = $Center/Padding/Panel/VBox/Content/Side/Fits
@onready var body: Label = $Center/Padding/Panel/VBox/Content/Side/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back
@onready var preview: SubViewport = $Center/Padding/Panel/VBox/Content/Preview/Viewport

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
var _preview_model: Node3D = null


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	_build_rows()
	_build_preview()


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
	body.text = "Nothing here changes how the drone behaves — yet."
	_sync_preview()


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


func preview_model() -> Node3D:
	## The machine standing in the picture — for anything that has to check it is wearing what the
	## drone is wearing (`tests/test_parts.gd`).
	return _preview_model


func _build_preview() -> void:
	## Build the picture's little world once, on ready: an environment that leaves the panel
	## showing through, the machine, a camera on its face side, and two lights aimed at it. The
	## model starts on the stock machine; `_sync_preview()` dresses it from the drone.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)              # transparent: the panel is the backdrop
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.64, 0.74)
	env.ambient_light_energy = 0.85
	var world := WorldEnvironment.new()
	world.name = "PreviewWorld"
	world.environment = env
	preview.add_child(world)

	_preview_model = DroneModel.new()
	_preview_model.name = "PreviewDrone"
	preview.add_child(_preview_model)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = PREVIEW_FOV
	preview.add_child(camera)
	camera.look_at_from_position(PREVIEW_EYE, PREVIEW_LOOK, Vector3.UP)

	# Two lights, both aimed at the machine rather than set at an angle worked out by hand: a key
	# from the front-right for the form, and a dimmer, cooler fill from the front-left so the faces
	# turned away from the key are not black.
	var key := DirectionalLight3D.new()
	key.name = "PreviewKey"
	key.light_energy = 1.25
	preview.add_child(key)
	key.look_at_from_position(Vector3(1.4, 2.0, -1.8), PREVIEW_LOOK, Vector3.UP)

	var fill := DirectionalLight3D.new()
	fill.name = "PreviewFill"
	fill.light_energy = 0.45
	fill.light_color = Color(0.78, 0.85, 1.0)
	preview.add_child(fill)
	fill.look_at_from_position(Vector3(-1.6, 0.9, -1.2), PREVIEW_LOOK, Vector3.UP)


func _sync_preview() -> void:
	## Dress the machine in the picture in exactly what the drone is wearing. A family already
	## showing the right part is left alone, so a refresh does not rebuild meshes it did not need
	## to — and a part that is missing or unknown leaves the stock one standing rather than blanking
	## the picture.
	if _preview_model == null:
		return
	for entry in _families:
		var kind: String = entry[0]
		var id := fitted(kind)
		if id == "" or _preview_model.fitted(kind) == id:
			continue
		_preview_model.set_part(kind, id)
