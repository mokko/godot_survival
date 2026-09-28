# The frame: what the drone can do

The drone's characteristics, worked out from the three parts it is wearing. `player/frame_stats.gd`
is the arithmetic, `player/player.gd` holds one (`frame`) and reads it, and each family —
`player/legs.gd`, `player/torsos.gd`, `player/heads.gd` — declares what its parts do to it in a
**`TRAITS`** table sitting beside the parts themselves.

This layer exists so that fitting a part can mean something. Before it, the drone's numbers were
constants on `player.gd` and every part was a cosmetic; now the numbers are the parts' and there is
one place that adds them up.

## The rule

A frame is **legs + torso + head**, and:

- **`mass` is a quantity**: the base core's own weight plus every part's own, because a part has a
  real weight. Anything else a part states as a quantity works the same way;
- **everything else is a delta** added to `BASE` — the numbers **this game has always used**. A
  `tread_plain` declares no speed change, so the stock frame walks at 5.0;
- **`grip` is per surface**: the base is 1.0 (the stock frame grips everything) and a part declares
  only the surfaces it changes, so a surface left alone stays at the base.

Because of that, **`FrameStats.new()` — the stock frame — answers exactly the numbers the game had
before this existed**, and that equality is what makes the reader move safe. `tests/test_frame_stats.gd`
asserts it to the digit, and the rest of the suite runs on the stock frame, so a part that moved
something it did not declare would show up as a broken game rather than as a surprise.

## What is read today

| stat | read by |
| --- | --- |
| `walk_speed`, `sprint_speed` | the drone's movement (`player.gd::_physics_process`), where the run is a multiple of the walk |
| `brake_scale` | how hard it comes to a stop, as a multiple of the speed it was going — 1.0 as stock |
| `jump_velocity` | the jump |
| `eye_height` | the camera's own height: **the camera rides on the body**, so a lower head or a shorter neck looks out from lower down |
| `tank` | the starting charge, the sunbulb cap, a respawn, and the max the HUD meter is fed |
| `idle_drain` | the energy a second the drone spends just being switched on |

The **Robo Editor shows them** (`ui/editor.gd`): a column beside the picture, one line per stat, each
saying what it costs by when the value is not the stock frame's — and the declared-but-unread ones
under a heading of their own, because a number the game ignores must not look like one it obeys.

Two of those are worth knowing about:

- **The frame is re-read whenever a part is fitted** (`player.gd::_read_frame()`, called from
  `fit_body_part()`, `fit_legs()` and `load_state()`). The load path matters: a save restores the
  parts through `equipment` directly, so it has to re-read the frame itself or the drone would wear
  one body and be governed by another.
- **A sunbulb's gift is the plant's, not the frame's** (`SUNBULB_HEAL` stays on `player.gd`): what
  eating one restores does not change with the parts.

## What is declared and not yet read

`mass`, `height`, `width`, `noise`, `visibility` and `grip()` are in the layer with nothing reading
them, because **this is where a part's effect lands** and the names are the agreed vocabulary.
Declaring a stat wires it to nothing, so none of it changes play. What comes next, in the order the
plan has it:

1. **Terrain grip** — the surfaces are the game's own words: `flat` and `slope` are the ground,
   `bog` is the wetland `world/island.gd::height_at()` flattens, `sand` is the beach
   `world/clutter.gd` calls a shore band, and `rock` is the stone it stops scattering on. The
   reader would be the drone's speed on each, which is where "different movement abilities for
   different terrains" becomes real.
2. **`noise` and `visibility`** — how far fauna hear and see the drone. The Dusk Stalker already
   hunts at 10 m by day and 14 m at night, so the notice distance is the obvious landing place, and
   then a loud frame is hunted sooner.
3. **`mass`** — what the drone can carry (the movable blocks are mass 10) and how it is pushed.

## Adding a part

A part is its geometry, a `NAMES` and `COLOURS` entry, and a **`TRAITS`** entry. Three rules:

- **A stock part declares its weight and nothing else.** It is the base every other part is
  measured against, and a stock part that moved something would quietly move every drone in the
  game.
- **A new trait name needs something that reads it.** Adding a stat nobody reads is adding a
  promise; the layer's class comment keeps the list of which are which.
- **A part has to trade.** A part that is only better makes the Robo Editor a no-op, so the numbers
  are chosen in pairs — the tracks grip and are loud, the legs climb and are slow, a plated body
  holds more cells and walks worse. What is being traded is the design.

`tests/test_frame_stats.gd` checks that **every trait names something the layer knows**. A typo
(`walk_speeed`) is read by nothing and looks exactly like a part with no effect, which is a failure
nobody would ever see in play, so it has to be caught here.

## Where the numbers came from

`BASE` holds them, and they are the constants this replaced, to the digit: `player.gd`'s `SPEED`,
`JUMP_VELOCITY`, `START_LIFE`, `LIFE_DRAIN_PER_SEC` and `TREAD_SPEED_FULL`, and the camera's own
`y` in `player/player.tscn` (which is `eye_height`). The drone's `mass`, `height` and `width` are
new — they had no constant to move, because nothing had measured the drone before — and the stock
frame's weight is the core's 18 kg plus the stock legs' 14, torso's 6 and head's 3.
