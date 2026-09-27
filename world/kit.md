# The Explorer's Kit: where a run's gear comes from

A new run begins with **nothing**. The drone wakes on Ezo's SW cape with empty hands and an empty bag,
and the first thing a player does is walk a dozen metres into the cape and find the satchel its tools
were left in. `world/explorer_kit.gd` is the satchel, `world/main.tscn` is where it lies and where the
katana lies too, and `tests/test_explorer_kit.gd` pins both.

## What is in it

```gdscript
const CONTENTS := ["notebook", "pen", "magnifying_glass", "binoculars"]
```

`items/item_db.gd`'s ids: the **Pedia notebook**, the **Pen**, the **Magnifying Glass** and the
**Binoculars**. The notebook leads the list because it is the thing the other three write into — the
book holds the survey, and the two instruments are how entries are made (a plant by close study with
the glass, an animal by watching it through the binoculars; see `ui/pedia.md`).

The **katana** is *not* in the satchel. It lies out on the cape on its own, about 18 m from the
spawn — and it is a **prop**, not a pickup cube: `items/katana_pickup.gd` extends the ordinary pickup
(`items/item_pickup.gd`) and replaces only its look, so what lies in the grass is a blade beside its
saya, guard and wrapped handle toward whoever walks up, with the blade's edge a brighter strip of its
own. Walk into it and it is yours, exactly like every other pickup in the world; the base class keeps
the rules and this file is only the sword. The other katana in the world (`Pickup6`, up on the massif)
uses the same scene, so a sword is a sword wherever it is found.

Nothing here is a **keepsake by itself**: `player.gd`'s `KEEPSAKE_ITEMS` (notebook, pen, glass) are
still the items a death wipe gives back — but only once the run has actually held them. A drone that
dies before it reaches the satchel comes back with the same empty hands it started with, and the
satchel is still out there waiting. That is what `_keepsakes_found` is for, and it is read back off the
restored bag when a save is loaded.

## Where it lies, and how to move it

The satchel is a plain node in `world/main.tscn`:

```
[node name="ExplorerKit" parent="." instance=ExtResource("22_kit")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -110, 2.3655, 70)
```

Two things are load-bearing about those numbers:

- **The y is the terrain's answer, not a guess.** `world/island.gd`'s `height_at(x, z)` is the height
  field `tools/build_terrain.gd` bakes the ground mesh from, so a satchel placed at that y lies on the
  ground. `x` and `z` are both multiples of 2.5, which is the terrain mesh's own vertex spacing, so the
  height is exact rather than interpolated. `tests/test_explorer_kit.gd` fails if it floats, if it is
  not on dry land, or if it is more than 25 m from the spawn.
- **It lies unrotated, facing the spawn.** Its flap, buckle and lit mark are built into the **+Z**
  face, and +Z is where the player walks from.

The mesh is built to the ground: the leather body's base sits at y = 0 in the node's own frame, and the
whole bag is about 0.35 m tall — a small thing in grass, which is what the lit mark on the flap is for.

Moving it is editing that transform (and the katana's `Pickup15` a few lines further down in `Items`),
then re-checking the test. There is no builder for either: they are two positions, not a bake, and
`world/main.tscn` is the file a hand-placed pickup already lives in.

## Opening it

Stand within **3.5 m** and press **E** (`interact`) — the bench's radius and the bench's key. The
contents go straight to the inventory, the satchel leaves the world, and a frame later the drone is
wearing it. Standing beside a shut satchel shows **"E — open the satchel"** — the prompt names what is
*visible*, not what the bag turns out to hold: "the Explorer's Kit" is the name the opening page
gives it, and putting it on the approach would spend the reveal before the finding. Built in code and
parented to the HUD exactly like the boat's and the bench's prompts, and only while the world holds the
mouse.

Opening it is also a **screen**: the satchel asks the HUD's milestone story screen
(`world/main.tscn`'s `HUD/StoryScreen`) for `ui/story_text.gd`'s `explorer_kit` page, which types
itself over the paused world and closes back into the run. That is why the drone's first find is
narrated — and why it is asked for on the *opening* path only: a satchel a save remembers as already
emptied is on the drone's shoulder and says nothing, so loading a run never replays the page. See
`ui/story.md`.

Three rules, all of them in `explorer_kit.gd:use()`:

- **Nothing is handed out twice.** An item the drone already carries is skipped. This is what makes a
  reloaded save safe: without it the satchel would refill a bag that already holds all four.
- **A full bag keeps the satchel shut**, so the gear is come back for rather than dropped on the
  ground. It opens as soon as everything fits or is already carried.
- **What has been opened rides in the save**: `player.open_container(id)` appends the satchel's id to
  `player.opened_containers`, which is written under `containers` and restored on load. A run that has
  been through it comes back with **the bag on the drone's shoulder and nothing in the grass**, instead
  of a satchel looking shut and offering gear the drone already has. Both the satchel and the drone's
  equipment read that list in a deferred call, because the player is the one that restores the save, in
  its own `_ready`.

Like the boat and the bench the satchel is one merged, vertex-coloured mesh (`world/prop_mesh.gd`) on a
`StaticBody3D`, so it cannot be walked through. Its only light is the emissive mark, which costs no
light in the scene's budget — `tools/perf_test.sh` is what keeps that honest.

## The satchel is the drone's bag

This is the one container in the game that **moves**. Emptying it does not leave an open box behind:
the satchel goes onto the drone (`player/equipment.gd`'s `show_satchel(true)`, called from
`explorer_kit.gd`'s `_wear_satchel`) and the one in the grass is hidden with its collision shape
disabled. Two consequences, both wanted:

- **The player is never shown two satchels.** The bag on the shoulder *is* the bag that was lying on
  the cape, and it is what tells a returning player that this run has already been here — a better
  trace than an open lid, because it travels with the drone.
- **The inventory is visible on the character.** `equipment.gd` builds the bag as a flat leather panel
  at the right hip (`SATCHEL_POS`) with a strap crossing the back to the left shoulder, and keeps it
  hidden until asked. It hangs deliberately **behind the arm**: the arms swing at x = ±0.36 through
  z ≈ 0, so a bag hung further out at that depth would be inside the right arm on every step.

`equipment.gd`'s `KIT_CONTAINER` names the one container id that means "the bag is ours", and
`_sync_worn_satchel()` asks the player for it after a load, so a restored run gets the bag without
replaying anything. `tests/test_equipment.gd` checks the bag is built, off on a fresh run, and goes on
and off through `show_satchel` and nowhere else; `tests/test_explorer_kit.gd` checks the whole move —
bag off and satchel on the cape at spawn, bag on and satchel gone (with its shape disabled) after
emptying, and both right again in a loaded run.

## Known rough edges

- **E now does four jobs**: board a boat, equip armour from the inventory, service a bench, and open the
  satchel. None of them can collide at the spawn — the bench is 145 m away on the same island and the
  armour case only fires when an armour piece is in the held slot — but the key is doing a lot of work
  by now. See `world/bench.md` for the same note from the bench's side.
- **The satchel is a prop, not a system.** One satchel, one id, one contents list. A second one wants
  its own `container_id` set on the placed instance, or the two share an entry in the save. A second
  container that is *also* a bag would want its own `KIT_CONTAINER` answer — the drone can only wear
  one.
- **The katana glows a little.** A lying sword is barely taller than the grass, so `katana_pickup.gd`
  gives the whole prop a faint emission (0.3) — the same trick the pickup cube uses (0.35). Duller or
  brighter is one constant in that file; the alternative, no glow at all, means finding a white line in
  a field of tufts by eye.
- `Pickup6`, the massif katana, sits at the terrain's height (`11.9039`) where it used to float a metre
  above it (`12.6`, a number from before the last terrain bake). If a katana is ever moved, both x and z
  are on the terrain mesh's 2.5 m grid, so the ground height at that spot is exact rather than guessed.
