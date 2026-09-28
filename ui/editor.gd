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
## **Every variant is reachable for now.** Nothing gates a fit, because the editor is being built,
## so all of them have to be selectable without finding anything: fitting goes through
## `player/player.gd::fit_body_part()` — one door, and exactly where the ownership rule lands when a
## fit is gated on having found the part ("eventually we'll work with the parts we have found").
## The found-parts loop (`player/robot_parts.gd`, `items/part_pickup.gd`) is untouched, and
## `fit_legs()` still carries the old gate for that path.
##
## **The numbers are on the screen, not only the pictures** (Maurice, 28 Sep): the right column
## carries the drone's characteristics for the parts it is wearing (`player/frame_stats.gd`), and a
## line whose value is not the stock frame's says what it costs by — a part's price is the whole
## reason this screen exists. They stand in **two lists**: what the game reads today, and what is
## declared and read by nothing yet (`player/frame.md`), because a number the game ignores must not
## look like one it obeys. The readout asks the same frame the drone uses and the same `SURFACES`
## the layer declares, so the screen cannot drift from either.
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
const FrameStats := preload("res://player/frame_stats.gd")

## What the readout lists, as [stat, label, format]: **the numbers the game reads today**. The value
## is formatted, and when it differs from the stock frame's the difference is shown beside it — a
## part's cost is the whole reason this screen exists, and "4.4 m/s (−0.6)" says what it costs in a
## way that "4.4 m/s" does not.
##
## The rows flow into a **four-column** grid, so they pair up two to a row and **the order here is
## the order they read in** — walk beside run, jump beside charge.
const NOW := [
	["walk_speed", "Walk", "%.1f m/s"],
	["sprint_speed", "Run", "%.1f m/s"],
	["jump_velocity", "Jump", "%.2f"],
	["tank", "Charge", "%.0f"],
	["brake_scale", "Braking", "%.2f×"],
	["eye_height", "View height", "%.2f m"],
]
## ...and the ones that are **declared and read by nothing yet** (`player/frame.md`): its weight,
## how far it carries, and how it holds each surface. Shown all the same, because this is where a
## part's numbers are chosen — and kept apart, because a number the game ignores must not look like
## one it obeys.
const LATER := [
	["mass", "Mass", "%.1f kg"],
	["noise", "Noise", "%.2f"],
]

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
@onready var now_stats: GridContainer = $Center/Padding/Panel/VBox/Content/Stats/Now
@onready var later_stats: GridContainer = $Center/Padding/Panel/VBox/Content/Stats/Later
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
## The stock frame: what every readout line is measured against, so a part's cost shows as a
## difference rather than as a number the player has to remember.
var _stock = FrameStats.new()
## key -> the readout's value Label, so `stat_value()` can say what the screen shows without
## walking the grid for it.
var _stat_cells := {}


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
	body.text = "Every part trades something — these numbers are its price."
	_refresh_stats()
	_sync_preview()


# ------------------------------------------------------------ what the drone is

func stat_value(key: String) -> String:
	## One line of the readout, by the key its row was built under — "walk_speed", "mass",
	## "grip_rock" — so a test reads what the screen says without walking the grid.
	var cell: Label = _stat_cells.get(key)
	return "" if cell == null else cell.text


func _frame():
	## The frame the drone is wearing, or the stock one when there is no drone to ask (the screen
	## is built and laid out before a bench ever opens it). Untyped, because the node in the group
	## is only checked for the property.
	var node = _player.get("frame") if _player != null else null
	return node if node != null else _stock


func _refresh_stats() -> void:
	## Rebuild the readout from the frame. **Two grids rather than one list**, so "what the game
	## reads today" and "what nothing reads yet" cannot be mistaken for each other — a number the
	## game ignores must not look like one it obeys.
	_stat_cells.clear()
	_fill_stats(now_stats, NOW)
	_fill_stats(later_stats, LATER)
	# The surfaces come from the frame rather than from a table: `FrameStats.SURFACES` is the
	# vocabulary, so a surface added there gets a row here without anyone remembering to.
	for surface in FrameStats.SURFACES:
		# `grip_<surface>`, not `grip:<surface>`: the key doubles as the row's node name, and a
		# node name cannot hold a colon — Godot sanitises it away and the row stops being findable.
		var key := "grip_%s" % surface
		later_stats.add_child(_stat_name("Grip %s" % surface, key))
		later_stats.add_child(_stat_cell(_frame().grip(surface), _stock.grip(surface),
				"%.2f", key))


func _fill_stats(grid: GridContainer, rows: Array) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for row in rows:
		var key: String = row[0]
		grid.add_child(_stat_name(str(row[1]), key))
		grid.add_child(_stat_cell(_frame().stat(key), _stock.stat(key), str(row[2]), key))


func _stat_name(text: String, key: String) -> Label:
	var label := Label.new()
	label.name = "Stat_%s" % key
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _stat_cell(value: float, stock: float, format: String, key: String) -> Label:
	var label := Label.new()
	label.name = "Value_%s" % key
	label.text = _value_text(value, stock, format)
	label.add_theme_font_size_override("font_size", 16)
	_stat_cells[key] = label
	return label


func _value_text(value: float, stock: float, format: String) -> String:
	## The number, and — when it is not the stock frame's — what it costs by. A part that were only
	## better than the stock one would be a part with no decision in it, so the difference is the
	## interesting half of the line.
	var text := format % value
	if absf(value - stock) > 0.005:
		text += "  (%+.2f)" % (value - stock)
	return text


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
