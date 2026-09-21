# Nakamoto's Paradigm (v0.0.2-alpha)

Nakamoto's Paradigm (aka survivalm) is an experiment to learn more about Godot,
games, and developing with AI. It is the first experiment — others will follow.

We currently develop using Hermes (agent) with GLM Flash and Deepseek Flash.

## Story

Your consciousness is placed into a robot on a foreign planet. You are supposed
to explore and survive and find why you have been placed there.

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

SECOND ITERATION

We added a combat system. At the moment it's still generic and doesn't feel
good, but should have basic function. Plus exploration storyline where
magnifying glass etc. leads to entries in encyclopedia (the Pedia). Will take some time
to work as intended. We also thought about a crafting system where we find
robot parts on the island that let us modify our robot. Still no mechanism to
change the environment.

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
- **Rowan** — makes suggestions and does testing.
- **Wes** — may later design graphics or other elements.

## Running

Requires **Godot 4.7** (developed and tested on `4.7.stable.mono`; installed
via snap on this machine, run as `snap run godot-4`):

```bash
godot --path .
```

## Development

Tests live in `tests/` and run headless. Run one:

```bash
flock /tmp/survivalm-godot.lock snap run godot-4 --headless --script res://tests/test_boot.gd
```

Or run the whole suite with a pass/fail summary:

```bash
tests/run_all.sh
```

## Before a release

The headless suite cannot see rendering at all (`--headless` has no renderer), so a
graphics change that halves the frame rate still passes every test. Run the
benchmark and keep its output with the release:

```bash
tools/perf_test.sh | tee screenshots/$(date +%Y%m%d)/perf-$(date +%Y%m%d).txt
```

It needs a real display and exits non-zero if the window was never presented — in
which case the fps numbers mean nothing. `tools/perf_test.sh` explains the
environment it needs; `screenshots/README.md` covers the weekly screenshots.

## Where to read more

- **Combat** — `player/combat.md`: the phases in the order they run, which
  function is called for what, every constant, which test covers what.
- **Pedia and study** — `ui/pedia.md`: the notebook, its three layers, the
  magnifying glass and the binoculars.
- **The HUD** — `ui/hud.md`: the four batteries and the rest of that surface.
- **Boats** — `world/boats.md`: the sailing route and the hull rules.
- **Saves** — `world/savegame.md`: where `user://` really is and what moves it.
- **Species** — `flora/plants.md`, `fauna/animals.md`.
- **Research** — `research/`: the geography, the older premise notes, the
  researchers.

Project layout:

- `player/` — the drone: input and energy, combat, study, equipment
- `world/` — main scene, island, terrain, water, movable blocks, ground clutter
- `flora/`, `fauna/` — plant and animal species
- `ui/` — splash menu, story screen, pause menu, pedia, fade-in, HUD meters,
  procedural icons and plates (`item_icons.gd`, `vector_art.gd`, `pedia_art.gd`)
- `tools/` — scene builders (terrain, flora, fauna), `capture_views.gd` (screenshots),
  `perf_test.sh` (benchmark), `make_sounds.py`
- `sounds/` — synthesized sound effects
- `research/` — worldbuilding and reference notes (geography, premise)
