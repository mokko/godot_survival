# Survivalm

Survivalm is an experiment to learn more about Godot, games, and developing
with AI. It is the first experiment — others will follow.

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

Project layout:

- `player/`, `orb/` — player and collectibles
- `world/` — main scene, island, terrain, water, movable blocks
- `flora/`, `fauna/` — plant and animal species
- `ui/` — splash menu, story screen, pause menu, fade-in
- `tools/` — scene builders (terrain, flora, fauna) and `make_sounds.py`
- `sounds/` — synthesized sound effects
