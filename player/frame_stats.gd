extends RefCounted
## The drone's characteristics **as a whole**, worked out from the three parts it is wearing.
##
## **The one place a frame's numbers are computed.** `player/equipment.gd` (the machine the player
## steers) holds one of these and re-reads it whenever a part is fitted; anything else — a test, a
## screen — can build one for any combination without a scene.
##
## A frame is its three parts: **legs** (`player/legs.gd`), **torso** (`player/torsos.gd`) and
## **head** (`player/heads.gd`). Each part declares `TRAITS` beside itself, and the rule is short:
##
##  - **mass** is a quantity: the base core's own plus every part's own, because a part has a real
##    weight. So does anything else a part states as a quantity later;
##  - **everything else is a delta** added to `BASE`, which holds **the numbers this game has
##    always used**. `tread_plain` declares no speed change, so the stock frame walks at 5.0;
##  - **grip is per surface**: the base is 1.0 (the stock frame grips everything) and a part
##    declares only the surfaces it changes.
##
## Because of that, **`FrameStats.new()` — the stock frame — answers exactly the numbers the game
## used before this file existed.** That is what makes moving the readers over to it provably
## behaviour-neutral, and the whole test suite is the evidence: it runs on the stock frame.
##
## Which of these the game reads today, and which are vocabulary waiting for their system:
##
##  - **read now**: `walk_speed`, `brake_scale`, `sprint_speed`, `jump_velocity`, `eye_height`,
##    `tank`, `idle_drain`.
##  - **declared, read by nothing yet**: `mass`, `height`, `width`, `noise`, `visibility`, `grip()`.
##    They are here because this is where a part's effect lands — the numbers are the agreed
##    vocabulary, and the systems that read them come next (terrain grip, then how far fauna hear
##    and see the drone). Declaring a stat wires it to nothing, so it changes no behaviour.
##
## `height` and `width` are the frame's own measurements; a part that makes the drone bulkier
## declares a delta here rather than anyone re-measuring a mesh.
##
## **The rule for a new part: it has to trade.** A part that is only better makes the Robo Editor a
## no-op, so the numbers below are chosen in pairs — fast and loud, tall and slow, capable on rock
## and poor on the flat.

const Legs := preload("res://player/legs.gd")
const Torsos := preload("res://player/torsos.gd")
const Heads := preload("res://player/heads.gd")

## The surfaces a `grip` trait can name. They are the game's own terrain words — flat and slope are
## `world/island.gd`'s ground, `bog` is the wetland `height_at()` flattens, `sand` is the beach
## `world/clutter.gd` calls a shore band, and `rock` is the stone it stops scattering on.
const SURFACES := ["flat", "slope", "rock", "bog", "sand"]

## The stock frame's numbers, and **the one place they are written down**. The values that used to
## be constants on `player/player.gd` (its `SPEED`, `JUMP_VELOCITY`, `START_LIFE`,
## `LIFE_DRAIN_PER_SEC`) and on the drone's camera (`eye_height`) live here now; the ones with no
## reader yet are written down once so a part can move them.
const BASE := {
	# what it weighs and measures
	"mass": 18.0,                 # the core: cells, motors' electronics, the neck
	"height": 1.25,               # metres, origin on the ground (player/drone_model.gd)
	"width": 0.56,
	# what it does
	"walk_speed": 5.0,
	"brake_scale": 1.0,           # the stopping rate, as a multiple of the speed it was going
	"sprint_multiplier": 2.0,     # the run is this many times the walk
	"jump_velocity": 4.72,        # 4.5 * sqrt(1.1): +10% peak height
	"eye_height": 2.2497854,      # where the camera rides; the drone is seen in third person
	"tank": 40.0,                 # four batteries of 10
	"idle_drain": 0.25,           # energy a second just for being switched on
	# how the world notices it
	"noise": 1.0,
	"visibility": 1.0,
	# how it holds the ground
	"grip": {"flat": 1.0, "slope": 1.0, "rock": 1.0, "bog": 1.0, "sand": 1.0},
}

var legs := ""
var torso := ""
var head := ""

var _stats := {}


func _init(legs_id := Legs.STOCK, torso_id := Torsos.STOCK, head_id := Heads.STOCK) -> void:
	## Built from the three ids; with no arguments that is the **stock frame**, whose numbers are
	## the ones the game had before any of this existed.
	legs = legs_id
	torso = torso_id
	head = head_id
	_stats = BASE.duplicate(true)
	_add_traits(Legs.TRAITS.get(legs, {}))
	_add_traits(Torsos.TRAITS.get(torso, {}))
	_add_traits(Heads.TRAITS.get(head, {}))
	# The run's speed is worked out once and kept under its own name, so anything that **lists** the
	# frame's numbers can ask for it like the rest (`stat("sprint_speed")`) instead of having to know
	# that it is the walk times the multiplier. Nothing writes it: a part moves the walk or the
	# multiplier and this follows.
	_stats["sprint_speed"] = float(_stats["walk_speed"]) * float(_stats["sprint_multiplier"])


func _add_traits(traits: Dictionary) -> void:
	## One part's contribution. `grip` is per surface and everything else is a flat addition — see
	## the class comment for why a quantity and a delta can share the same rule.
	for key in traits:
		if key == "grip":
			var grip: Dictionary = traits[key]
			for surface in grip:
				_stats["grip"][surface] = float(_stats["grip"].get(surface, 0.0)) \
						+ float(grip[surface])
			continue
		_stats[key] = float(_stats.get(key, 0.0)) + float(traits[key])


# ------------------------------------------------------------------- what it is

func mass() -> float:
	return float(_stats["mass"])


func height() -> float:
	return float(_stats["height"])


func width() -> float:
	return float(_stats["width"])


# ------------------------------------------------------------------- what it does

func walk_speed() -> float:
	return float(_stats["walk_speed"])


func brake_scale() -> float:
	## How hard it comes to a stop, as a multiple of the speed it was going — 1.0 as stock, and
	## read where the drone brakes. A heavier frame slides further; more track bites harder.
	return float(_stats["brake_scale"])


func sprint_multiplier() -> float:
	return float(_stats["sprint_multiplier"])


func sprint_speed() -> float:
	## The speed of the run — what the treads are scaled against for their sound. Kept worked out
	## (see `_init`) so a listing can ask for it by name too.
	return float(_stats["sprint_speed"])


func jump_velocity() -> float:
	return float(_stats["jump_velocity"])


func eye_height() -> float:
	## Where the camera rides above the ground. A taller head sees over more of the world.
	return float(_stats["eye_height"])


func tank() -> float:
	return float(_stats["tank"])


func idle_drain() -> float:
	return float(_stats["idle_drain"])


# ------------------------------------------------------- how the world notices it

func noise() -> float:
	## How far the drone carries, as a multiple of the stock frame. Nothing reads it yet: the
	## fauna's own notice ranges are where it lands.
	return float(_stats["noise"])


func visibility() -> float:
	## How far it is seen, as a multiple of the stock frame — the same, and for the same reason.
	return float(_stats["visibility"])


func grip(surface: String) -> float:
	## How well the frame holds one surface, 1.0 for the stock frame and 0.0 for "not at all".
	## Nothing reads it yet; `player/frame.md` says what is coming.
	return float(_stats["grip"].get(surface, 1.0))


func stat(name: String) -> float:
	## One characteristic by name — for anything that **lists** the numbers rather than asking for
	## them one at a time, which is what the Robo Editor's readout does. An unknown name answers
	## 0.0 rather than raising: a listing should survive a stat being renamed.
	return float(_stats.get(name, 0.0))