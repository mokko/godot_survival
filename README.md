# Survivalm

Survivalm is an experiment to learn more about Godot, games, and developing
with AI. It is the first experiment — others will follow.

We currently develop using [Hermes](https://hermes-agent.nousresearch.com)
and a GLM model.

The game starts out as a relatively generic 3D survival game with a sci-fi
theme. At this point it is not supposed to be an interesting game
experience, but rather a *complete* game including many elements games
have: a story, a world, a player, a main menu, graphics, sounds, etc. None
of these need to be fantastic.

## Team

- **Maurice** — executive director; has the last word in any decision.
- **Rowan** (Hermes + GLM) — makes suggestions and implements.
- **Wes** — may later design graphics or other elements.

## Running

Requires [Godot 4](https://godotengine.org) (developed on 4.7):

```bash
godot --path .
```

On this machine Godot is installed via snap: `snap run godot-4`.

## Development

Tests live in `tests/` and run headless:

```bash
flock /tmp/survivalm-godot.lock snap run godot-4 --headless --script res://tests/test_boot.gd
```

Project layout:

- `player/`, `orb/` — player and collectibles
- `world/` — main scene, island, terrain, water, movable blocks
- `flora/`, `fauna/` — plant and animal species
- `ui/` — splash menu, story screen, pause menu, fade-in
- `tools/` — scene builders (terrain, flora, fauna) and `make_sounds.py`
- `sounds/` — synthesized sound effects
