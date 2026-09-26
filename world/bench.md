# The service bench: how the robot editor opens

The bench is the diegetic way into the **Frame screen**, where the drone the player is steering is
re-fitted. `tools/build_benches.gd` places the benches, `world/bench.gd` is the behaviour,
`ui/editor.gd` + `ui/editor.tscn` are the screen, and `ui/pause_menu.gd` owns the key that closes it.

## Where the benches are

**One bench on every island** — Ezo, Honshu, Shikoku, Kyushu. Each stands on dry ground roughly 30 m
inland of that island's boat mooring, so it is found by walking up from the beach you came ashore on.
The coordinates are a plain table at the top of `tools/build_benches.gd`:

```gdscript
const SITES := {
	"Ezo": Vector2(33.0, 81.0),
	...
}
```

Move a bench by editing its `Vector2` and re-baking — never by dragging the node, because the builder
overwrites `world/benches_placed.tscn` wholesale. The builder refuses to bake a bench that is not on
land or that sits outside 1-9 m of height, so a misplaced one is an error rather than a bench in the
sea.

```bash
snap run godot-4 --headless --script res://tools/build_benches.gd
```

The bench's working face (slab, vice, hung tools) is its **+Z** side; the builder yaws each instance so
that face looks at the shore.

## Nothing records a bench

No HUD marker, no waypoint, no Pedia entry, no save flag. Finding a bench is the player's job and
remembering it is the player's memory — the same rule the README records under **"No minimap — the
world is the map"**. This is deliberate, and it is also *why the feature is simple*: with nothing to
write down there is no discovery radius, no notebook entry and no save state. "Found" is purely
physical, and placement is the only thing that makes a bench a discovery.

`tests/test_bench.gd` pins the decision: it fails if anything bench-shaped appears in the notebook, and
if the pause menu grows a button.

## Opening it

Stand within **4 m** of a bench and press **E** (`interact`). The bench asks the pause menu to open the
screen (`PauseMenu.open_editor()`), which is the *only* way in — there is deliberately no pause-menu
button, because a bench you have to find is the whole point.

The screen is a child of `pause_menu.tscn` and is shown in place of the menu, exactly like the Pedia and
the Saves screen. Two consequences worth keeping:

- **ESC stays owned by `pause_menu.gd`.** It routes the key to `editor.close()`, so there is still one
  listener and no race. The bench never handles ESC itself.
- **Closing it resumes play**, rather than showing the menu: a bench is used mid-run, so the player
  should come back to the world standing where they were. Entering from the world is why
  `open_editor()` does the whole open dance itself (pause the tree, release the mouse, step the menu
  aside) instead of assuming the menu is already up.

Standing at a bench shows the prompt **"E — service the frame"**. Like the boat's, the label is built in
code and parented to the HUD; it shows only while the world holds the mouse, so a menu or the inventory
takes `E` first.

## The screen, and the parts

The Frame screen is a **first cut**: it names the bench's island and says that nothing is fitted yet.
The slot list arrives with the parts.

**Robot parts go straight to the robot, not into the inventory** (decided). Two things follow, and both
are the point:

- A part needs no `items/item_db.gd` id, so it needs no inventory icon and no Pedia subchapter — the
  coverage `tests/test_pedia.gd` enforces for equipment never applies to robot parts. They get their own
  small registry instead, saved with the run like the notebook is.
- The inventory stays what it is — tools and loot — instead of filling with limbs.

The bench remains the only way into the editor: seeing what you have collected and fitting it both
happen at a bench.

The first three parts exist as geometry: **`player/legs.gd`** holds the drone's locomotion as
swappable fits — *triangle treads*, *three legs* (R2-D2's two side legs plus the third centre one)
and *telescope legs*, on top of the stock twin treads the drone is built with. `equipment.set_legs()`
is the one way to change them, and the fit rides in the save under `legs`. Nothing collects or offers
them yet: the Frame screen's slot list is the next piece.

## Known rough edges

- The benches sit near the landings, which makes them forgiving rather than hidden. Moving a `SITES`
  entry further inland is a one-line change if they should take more finding.
- `E` already does two other jobs in this game — board a boat, and equip armour from the inventory. The
  boat case cannot collide, because there are no boats at benches. The armour case is **accepted
  rather than engineered around** (Maurice's call, 26 Sep): *close to a bench, `E` opens the robot
  editor* — and if the armour piece also equips on the same press, so be it. A 4 m radius makes that a
  corner of the world rather than a problem, and one key doing different things in different places is
  already how the boat behaves.