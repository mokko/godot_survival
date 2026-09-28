# The service bench: how the robot editor opens

The bench is the diegetic way into the robot editor — the screen's heading reads **Robo Editor**, and
its file, node and the code's own name for it still say **Frame** — where the drone the player is
steering is re-fitted. `tools/build_benches.gd` places the benches, `world/bench.gd` is the behaviour,
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

That rule holds for the `bench` page too: the one thing a bench remembers is a `static var` in
`world/bench.gd` (`_page_played`), which lasts as long as the process and no longer. A run hears the
page once, at whichever bench it works at first; a run loaded into a fresh process hears it again,
which is exactly what walking up to a bench for the first time is. A flag in the savegame would make
*hearing the page* recorded state, which is the thing this section rules out.

`tests/test_bench.gd` pins the decision: it fails if anything bench-shaped appears in the notebook, and
if the pause menu grows a button.

## Opening it

Stand within **4 m** of a bench and press **E** (`interact`). The bench asks the pause menu to open the
screen (`PauseMenu.open_editor()`), which is the *only* way in from the world — there is deliberately no
pause-menu button, because a bench you have to find is the whole point.

**One exception, and it is a debug one** (Maurice's call, 27 Sep): the pause menu now carries a
**Robo Editor** entry (`ui/pause_menu.gd`), greyed out until a bench has been worked at
(`world/bench.gd::found()`) — and `ROBO_EDITOR_ALWAYS_ENABLED`, a `const` at the top of that file, is
**on** for now so the Frame screen can be reached without sailing to a bench. Set it to `false` when
that is no longer wanted; the gate behind it is already the shipping behaviour, and
`tests/test_bench.gd` section 8 pins both the switch and the gate.

**The first bench a run is worked at introduces itself.** `world/bench.gd` asks the HUD's milestone
story screen for `ui/story_text.gd`'s `robo_editor` page (`play_milestone`), and the Frame screen opens when
that page is done. The page is the *preface* to the screen and not a substitute for it, so `E` means
what it always meant and the player never has to press it twice. Later benches are silent — the page
is a one-off, and `bench.gd`'s `static var _page_played` is the whole record of it (see below).

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

## The screen, the parts and the picture

The screen is **three rows**, one per family — **Body** (`player/torsos.gd`), **Head**
(`player/heads.gd`) and **Legs** (`player/legs.gd`) — each showing the part that is on the drone now
between ◀ ▶ buttons that walk that family's own catalogue. The walk **wraps**, so no row is ever a
dead end, and the stock part is a row like any other: the machine the drone was built with is
somewhere you can walk back to.

Beside the rows is a **picture of the machine as it stands** (Maurice, 27 Sep). It is a
`SubViewport` in `ui/editor.tscn` holding a real `player/drone_model.gd` — the same builder the
player's machine uses — with a camera and two lights, dressed from the same three ids the drone is
wearing. So a cycle is something the player *sees* and not only a name that changed, and the picture
cannot drift from the machine on the beach. **The camera stands in front of it** (`-Z` is the side the
drone faces): the player's own camera sits behind the machine and would show its back, which is not
what a picture of the robot is for. The viewport renders only while the screen is open
(`UPDATE_WHEN_PARENT_VISIBLE`), so a closed bench costs nothing.

**Every variant is reachable for now** (Maurice, 27 Sep): the parts are cosmetics that change nothing
yet and the screen is still being built, so all of them have to be selectable without finding
anything. Fitting goes through **one door**, `player/player.gd::fit_body_part(kind, id)` — and that
function is exactly where the ownership rule lands when parts start to matter ("eventually we'll work
with the parts we have found"). The found-parts loop below is untouched, and `fit_legs()` still
carries the old gate for that path.

**Robot parts go straight to the robot, not into the inventory** (decided). Two things follow, and both
are the point:

- A part needs no `items/item_db.gd` id, so it needs no inventory icon and no Pedia subchapter — the
  coverage `tests/test_pedia.gd` enforces for equipment never applies to robot parts. They get their own
  small registry instead, saved with the run like the notebook is.
- The inventory stays what it is — tools and loot — instead of filling with limbs.

The bench remains the only way into the editor: seeing what the drone is made of and changing it both
happen at a bench.

The catalogues: **legs** — *triangle treads*, *three legs* (R2-D2's two side legs plus the third centre
one) and *telescope legs*, on top of the stock twin treads; **bodies** — *slim*, *plated* and *barrel*
on top of the stock body; **heads** — *visor*, *twin-lens* and *dish* on top of the stock dome. Each
file is the one place its family is described — the names, the geometry and the colour a part shows as
lying in the world. The drone's side is `player/equipment.gd`'s `set_legs`/`set_torso`/`set_head` and
`fitted_*()`, which hand straight to the one builder. A head carries one contract: a child named
**`Eye`**, the lens the hurt flash dims, so `set_head()` re-reads it.

- **Finding one**: `items/part_pickup.gd` sits in the world, and walking into it calls
  `player.collect_part()`. `tools/build_parts.gd` bakes `world/parts_placed.tscn` from a `SITES` table
  (one line per part), the same shape as the bench builder. They are placed near paths the player
  already walks rather than beside the benches they are fitted at — you find a part out on the island
  and carry it back, which is the loop.
- **Owning one**: `player/robot_parts.gd`, a static registry saved under `parts`. A fresh run clears it;
  dying does not.
- **Fitting one**: only at a bench, and only through the screen's rows, which call
  `player.fit_body_part()`. The found-part path keeps the ownership rule in `player.fit_legs()` — the
  stock fit is always the drone's, anything else must have been found. `ui/editor.gd` never touches the
  equipment directly, so nothing can be fitted by guessing an id.
- **Keeping it**: the three parts ride in the save under `legs`, `torso` and `head`; the parts list
  under `parts`.

## Known rough edges

- The benches sit near the landings, which makes them forgiving rather than hidden. Moving a `SITES`
  entry further inland is a one-line change if they should take more finding.
- `E` already does three other jobs in this game — board a boat, equip armour from the inventory, and
  open the Explorer's Kit by the spawn. The boat case cannot collide, because there are no boats at
  benches. The armour case is **accepted rather than engineered around** (Maurice's call, 26 Sep):
  *close to a bench, `E` opens the robot editor* — and if the armour piece also equips on the same
  press, so be it. A 4 m radius makes that a corner of the world rather than a problem, and one key
  doing different things in different places is already how the boat behaves.