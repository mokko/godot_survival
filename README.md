# Nakamoto's Paradigm (v0.0.1-alpha)

*Display name: **Nakamoto's Paradigm**. The working label is still `survivalm` —
the folder, `project/assembly_name`, the test lock and the macOS bundle id all
keep it, because those are identifiers rather than titles.*

Nakamoto's Paradigm is an experiment to learn more about Godot, games, and
developing with AI. It is the first experiment — others will follow.

We currently develop using [Hermes](https://hermes-agent.nousresearch.com)
and a GLM model.

FIRST ITERATION

The game starts out as a relatively generic 3D survival game with a sci-fi
theme. At this point it is not supposed to be an interesting game
experience, but rather a *complete* game including many elements games
have: a story, a world, a player, a main menu, graphics, sounds, etc. None
of these need to be fantastic.

Beyond survival, we want the game to teach the player something about
Japan. The working idea: we are in a fictional world that someone created
to commemorate Japan, and they left puzzles for us to solve — shrine sites,
kana and counting locks, haiku collectibles — so the knowledge is part of
the world itself rather than a quiz layered on top. Games to be inspired
by: Myst and Riven (an authored world whose puzzles teach its culture),
Outer Wilds (progression through understanding), Tunic (learning a
language by immersion), and Subnautica (survival loop + story told through
ruins).

## Decisions

- **One hand-made map.** The world is a single, hand-designed map — not
  procedural generation. Terrain, biomes and placement all come from a
  fixed, readable definition (`world/island.gd`), so coordinates stay
  stable across rebuilds and every feature can be tuned deliberately.
- **The map is Japan.** The archipelago is modeled on real Japan at
  1:1000 scale — Ezo (Hokkaido) with Honshu, Shikoku, Kyushu and the
  Seto Inland Sea, real capes, straits and highlands. We are looking for
  ways to work more knowledge about Japan into the game this way: the
  geography is the first layer, and later content (flora, fauna, story)
  should keep pointing back at the real places.
- **Single player.** The game is a single-player experience — no
  multiplayer or network play.

## Team

- **Maurice** — executive director; has the last word in any decision.
- **Rowan** (Hermes + GLM) — makes suggestions and implements.
- **Wes** — may later design graphics or other elements.

## Running

Requires **Godot 4.7** (developed and tested on `4.7.stable.mono`; installed
via snap on this machine, run as `snap run godot-4`):

```bash
godot --path .
```

## Story

Currently we are exploring this story: you have to survive while finding
out who you are and why you are on this planet.

## Development

Tests live in `tests/` and run headless. Run one:

```bash
flock /tmp/survivalm-godot.lock snap run godot-4 --headless --script res://tests/test_boot.gd
```

Or run the whole suite with a pass/fail summary:

```bash
tests/run_all.sh
```

### Sail between the islands

Every island except the last has a boat moored off its **south coast**
(Ezo → Honshu → Shikoku → Kyushu, and Kyushu is the destination so it has none). Stand beside a
boat and press **E** to board, **W/S** to sail, **A/D** to steer, **E** again to go ashore — refused
in open water, because the sea floor past the shallows has no collision and stepping off would be a
fall-death. The hull only floats in water `Ezo.is_navigable` accepts (`world/island.gd`'s `HULL_DEPTH`,
the same depth `tools/build_boats.gd` moors in), so a bow aimed at a beach is refused with a message
and the boat cannot be sailed through an island or under its hills. Moored boats carry a lit lantern
so they can be found from the water after dark. The route order lives in `tools/build_boats.gd`; re-bake
placements with:

```bash
snap run godot-4 --headless --script res://tools/build_boats.gd
```

### Energy (the HUD batteries)

The drone's charge shows in the top-left of the HUD as **four batteries**, each full,
half or empty — the hearts of this game, and what the `Life: 42` label used to be. The
tank is 40 (`player/player.gd`'s `START_LIFE`), so a battery is 10 and a half is 5, and
the display rounds *up* to the next half: one point left still shows half a battery, so
a battery only reads empty when that quarter of the tank is really gone
(`ui/energy_meter.gd`, where the rule is a static the tests check without a renderer).
Just being switched on costs 0.25 a second — 160 s on a full tank, or 40 s a battery —
and **Sunbulbs** feed 15 (a battery and a half) back, never past a full tank. A stalker
bite takes 5, one battery's half.

### Fight

A new run begins with the **Katana** in hand (`player/player.gd`'s `STARTING_ITEMS`,
handed out because the splash's Start button marks the run as fresh), so the fight can
be met on the first stroll rather than after a crafting chain. **Left click** swings
it: a cone 2.2 m deep and ±0.7 rad ahead of the drone, 25 damage a swing, drawn as a
crescent trail that sweeps through the arc — and when the cone actually catches
something, four ticks around the crosshair say so (`player/combat.gd`). With no weapon
equipped the same click is a bare-handed **jab** — a shorter, narrower cone (1.8 m,
±0.6 rad, 0.4 s between jabs) dealing the weapon table's bare-hand 5 — and it lands:
before it was animation and sound only, which read in game as "this animal cannot be
hurt". **Right click** draws and releases an arrow (15 damage) if a bow and arrows are
carried.

Every animal fights back once the player hurts it — all six species, not just the
dangerous one. A hit adds the animal to the `aggro_fauna` group and it charges, using
its own speed, reach and bite; the HUD's `Enemy:` line names the nearest one with its
life points. The fight ends by itself when the animal dies, is left behind past the
leash, or comes back to its senses — and an animal you never touch never notices you.
The **Dusk Stalker** — the low red-black quadruped with the lit eye strip, the
fox-shaped thing in the dusk — is the one exception: it hunts on sight, stops,
telegraphs for 0.4 s, then bites for 5, and after dark it sees 14 m instead of its
daytime 10 m. A kill drops Emberstone, and arrows half the time. Dying still wipes the
inventory, katana included, so a respawn is back to fists (`ESC` restarts).

**`player/combat.md` describes the whole system in prose** — the phases in the order
they run, which function is called for what, every constant, and which test covers
each mechanic. Read that before changing anything here.

### Pedia

The pause menu has a **Pedia**: the island's handbook, opened as its own screen
(it draws the same dim and panel as the pause menu, and the menu is hidden while
it is up). It opens on a table of contents — **Islands, Plants, Animals,
Equipment** — each chapter lists its things, and each thing has a page with a
picture and its text. **Back** (or `ESC`, which the pause menu owns and routes
here) walks one page up; at the contents page it closes the book and hands back
to the menu. An opened Pedia always starts at the contents again.

Everything written in it lives in `ui/pedia_data.gd`, so a page cannot disagree
with another page. Two lists are enforced by `tests/test_pedia.gd`: the Equipment
chapter covers exactly the ids in `items/item_db.gd`, and every entry in every
chapter has real text and a plate to draw. For now every entry is listed; when the
Pedia starts showing only what the player has met, that filter goes in one place
(`pedia.gd:_entries_of()`).

The pictures are vector art, like the inventory icons: `ui/pedia_art.gd` draws an
island from its real outline in `world/island.gd` (Ezo gets its caldera lake and
the arrival point drawn in), an item from the same art its inventory slot uses,
and a plant or animal from a silhouette authored in a 0..1 square. The shared op
vocabulary — op constructors, scaling, drawing, scanline fills — is
`ui/vector_art.gd`, used by both the icons and the Pedia.

### Run the frame-rate benchmark before every release

The headless suite cannot see rendering at all (`--headless` has no renderer), so a graphics change
that halves the frame rate still passes every test. Run the benchmark and keep its output with the
release:

```bash
tools/perf_test.sh | tee screenshots/$(date +%Y%m%d)/perf-$(date +%Y%m%d).txt
```

It toggles SSAO, MSAA and the ground clutter in one session and reports fps, draw calls and
primitives per frame for each combination, exiting non-zero if the window was never presented (in
which case the fps numbers mean nothing). It needs a real display — on the Rock 5B the session is
Xwayland and the script detects the env itself; see `screenshots/README.md`.

### Screenshots

`screenshots/YYYYMMDD/` holds the first screenshots of each week, rendered from fixed poses with
`tools/capture_views.gd`. See `screenshots/README.md` for how to re-take them.

Project layout:

- `player/`, `orb/` — player and collectibles
- `world/` — main scene, island, terrain, water, movable blocks, ground clutter
- `flora/`, `fauna/` — plant and animal species
- `ui/` — splash menu, story screen, pause menu, pedia, fade-in, HUD meters,
  procedural icons and plates (`item_icons.gd`, `vector_art.gd`, `pedia_art.gd`)
- `tools/` — scene builders (terrain, flora, fauna), `capture_views.gd` (screenshots),
  `perf_test.sh` (benchmark), `make_sounds.py`
- `sounds/` — synthesized sound effects
- `research/` — worldbuilding and reference notes (geography, premise)
