# The Explorer's Kit: where a run's gear comes from

A new run begins with **nothing**. The drone wakes on Ezo's SW cape with empty hands and an empty bag,
and the first thing a player does is walk a dozen metres into the cape and find the crate that its
tools were left in. `world/explorer_kit.gd` is the crate, `world/main.tscn` is where it stands and
where the katana lies, and `tests/test_explorer_kit.gd` pins both.

## What is in it

```gdscript
const CONTENTS := ["notebook", "pen", "magnifying_glass", "binoculars"]
```

`items/item_db.gd`'s ids: the **Pedia notebook**, the **Pen**, the **Magnifying Glass** and the
**Binoculars**. The notebook leads the list because it is the thing the other three write into — the
book holds the survey, and the two instruments are how entries are made (a plant by close study with
the glass, an animal by watching it through the binoculars; see `ui/pedia.md`).

The **katana** is *not* in the crate. It lies out on the cape on its own, about 18 m from the
spawn — and it is a **prop**, not a pickup cube: `items/katana_pickup.gd` extends the ordinary pickup
(`items/item_pickup.gd`) and replaces only its look, so what lies in the grass is a blade beside its
saya, guard and wrapped handle toward whoever walks up, with the blade's edge a brighter strip of its
own. Walk into it and it is yours, exactly like every other pickup in the world; the base class keeps
the rules and this file is only the sword. The other katana in the world (`Pickup6`, up on the massif)
uses the same scene, so a sword is a sword wherever it is found.

Nothing here is a **keepsake by itself**: `player.gd`'s `KEEPSAKE_ITEMS` (notebook, pen, glass) are
still the items a death wipe gives back — but only once the run has actually held them. A drone that
dies before it reaches the crate comes back with the same empty hands it started with, and the crate is
still out there waiting. That is what `_keepsakes_found` is for, and it is read back off the restored
bag when a save is loaded.

## Where it stands, and how to move it

The crate is a plain node in `world/main.tscn`:

```
[node name="ExplorerKit" parent="." instance=ExtResource("22_kit")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -110, 2.3655, 70)
```

Two things are load-bearing about those numbers:

- **The y is the terrain's answer, not a guess.** `world/island.gd`'s `height_at(x, z)` is the height
  field `tools/build_terrain.gd` bakes the ground mesh from, so a crate placed at that y stands on the
  ground. `x` and `z` are both multiples of 2.5, which is the terrain mesh's own vertex spacing, so the
  height is exact rather than interpolated. `tests/test_explorer_kit.gd` fails if the crate floats,
  if it is not on dry land, or if it is more than 25 m from the spawn.
- **It stands unrotated, facing the spawn.** Its latch, lit mark and lid hinge are built into the
  **+Z** face, and +Z is where the player walks from.

Moving it is editing that transform (and the katana's `Pickup15` a few lines further down in `Items`),
then re-checking the test. There is no builder for either: they are two positions, not a bake, and
`world/main.tscn` is the file a hand-placed pickup already lives in.

## Opening it

Stand within **3.5 m** and press **E** (`interact`) — the bench's radius and the bench's key. The
contents go straight to the inventory, the lid tips back, and the lit mark on the front goes dark.
Standing beside a shut crate shows **"E — open the Explorer's Kit"**, built in code and parented to
the HUD exactly like the boat's and the bench's prompts, and only while the world holds the mouse.

Opening it is also a **screen**: the crate asks the HUD's milestone story screen
(`world/main.tscn`'s `HUD/StoryScreen`) for `ui/story_text.gd`'s `explorer_kit` page, which types
itself over the paused world and closes back into the run. That is why the drone's first find is
narrated — and why it is asked for on the *opening* path only: a crate a save remembers as already
emptied stands open and silent, so loading a run never replays the page. See `ui/story.md`.

Three rules, all of them in `explorer_kit.gd:use()`:

- **Nothing is handed out twice.** An item the drone already carries is skipped. This is what makes a
  reloaded save safe: without it the crate would refill a bag that already holds all four.
- **A full bag keeps the crate shut**, so the gear is come back for rather than dropped on the ground.
  The crate opens as soon as everything fits or is already carried.
- **What has been opened rides in the save**: `player.open_container(id)` appends the crate's id to
  `player.opened_containers`, which is written under `containers` and restored on load. A crate the
  drone has already been through therefore stands **open and empty** after Load Game instead of looking
  shut and offering gear it already has. The crate reads that list in a deferred call, because the
  player is the one that restores the save, in its own `_ready`.

Like the boat and the bench the crate is one merged, vertex-coloured mesh (`world/prop_mesh.gd`) on a
`StaticBody3D`, so it cannot be walked through; the lid is a second mesh on a pivot at the crate's back
top edge, so it swings open away from whoever pressed E. Its only light is the emissive mark, which
costs no light in the scene's budget — `tools/perf_test.sh` is what keeps that honest.

## Known rough edges

- **E now does four jobs**: board a boat, equip armour from the inventory, service a bench, and open the
  crate. None of them can collide at the spawn — the bench is 145 m away on the same island and the
  armour case only fires when an armour piece is in the held slot — but the key is doing a lot of work
  by now. See `world/bench.md` for the same note from the bench's side.
- **The crate is a prop, not a system.** One crate, one id, one contents list. A second crate wants its
  own `container_id` set on the placed instance, or the two share an entry in the save.
- **The katana glows a little.** A lying sword is barely taller than the grass, so `katana_pickup.gd`
  gives the whole prop a faint emission (0.3) — the same trick the pickup cube uses (0.35). Duller or
  brighter is one constant in that file; the alternative, no glow at all, means finding a white line in
  a field of tufts by eye.
- `Pickup6`, the massif katana, sits at the terrain's height (`11.9039`) where it used to float a metre
  above it (`12.6`, a number from before the last terrain bake). If a katana is ever moved, both x and z
  are on the terrain mesh's 2.5 m grid, so the ground height at that spot is exact rather than guessed.