# WORLD_SPEC.md — Ezo build contract

Read this first. It is the single source of truth for how the world is assembled.
Worldbuilding canon (what things ARE): `plants.md`, `animals.md`.
World math (where things ARE): `island.gd` — read it before writing any placement code.
This file (how it's BUILT): file ownership, technical constraints, integration contract.

## Project facts

- Project dir: `/home/maurice/snap/godot-4/common/survivalm` (snap install).
- Godot **4.7**, renderer `gl_compatibility`, physics engine **Jolt** (see project.godot).
- All headless commands run from the project dir: `snap run godot-4 --headless ...`.
- Existing player: `player.tscn`/`player.gd` (CharacterBody3D, group `player`, WASD + mouse
  look + shift sprint, life system, `heal()`).
- The player spawns at `Ezo.spawn_point()` (SW cape, ground height ≈ 2.25).

## island.gd API (stable — do not edit, do not duplicate)

`class_name Ezo` — static functions, preload with `const Ezo := preload("res://world/island.gd")`:

- `Ezo.height_at(x: float, z: float) -> float` — terrain height; offshore ≈ −3.5.
- `Ezo.is_land(x, z) -> bool` / `Ezo.is_water(x, z) -> bool`
- `Ezo.signed_distance(p: Vector2) -> float` — +inside / −outside, ≈ meters to coast.
- `Ezo.random_land_point(biome: String) -> Vector3` — random land point; biome one of
  `"sw_cape"`, `"massif"`, `"caldera_rim"`, `"wetlands"`, `"ne_cape"`, `"coast"`, `"lake"`,
  `"anywhere"`. y = ground height (lake: `LAKE_LEVEL`).
- `Ezo.spawn_point() -> Vector3`
- Constants: `WATER_LEVEL = 0.0`, `LAKE_LEVEL = 2.5`, `CALDERA_CENTER = Vector2(-35, -20)`,
  `LAKE_RADIUS = 13.0`, `SPAWN_XZ = Vector2(-112, 82)`.

Conventions: **north = −Z, east = +X**. All heights in units. `island.gd` passes a
headless self-test (`test_island.gd`) — trust it, don't re-derive terrain math.

## File ownership (STRICT — three parallel workers)

| Worker | MAY create/modify | MUST NOT touch |
|--------|-------------------|----------------|
| Terrain | `terrain.gd`, `build_terrain.gd`, `scenes/terrain.tscn`, `scenes/water.tscn` | everything else |
| Plants | `plants/*.gd`, `plants/*.tscn`, `plants/build_plants.gd` | everything else |
| Animals | `animals/*.gd`, `animals/*.tscn`, `animals/build_animals.gd` | everything else |
| Integrator (lead) | `main.tscn`, `player.gd`, `player.tscn`, `orb.*`, `island.gd`, `WORLD_SPEC.md` | worker files |

No worker edits `main.tscn`, `project.godot`, `island.gd`, the player, the orbs, or the `.md`
docs. No `git` commands. Deliver scenes + builder scripts; the integrator wires `main.tscn`.

## Node & wiring contract (what the integrator will do — build for it)

`main.tscn` will instance these as children of root `Main` (Node3D), in this order:

1. `scenes/terrain.tscn` — root node **`Terrain`** (StaticBody3D with collision).
2. `scenes/water.tscn` — root node **`Water`** (sea plane + caldera lake disc, no collision).
3. `plants/plants_placed.tscn` — root node **`Plants`** (all plant instances).
4. `animals/animals_placed.tscn` — root node **`Animals`** (all animal instances).

So: each worker produces ONE placed scene with that exact root node name, plus the individual
scene files it instances. The old flat `Ground` node and its `WorldBoundaryShape3D` will be
removed — terrain supplies all ground collision. The existing `Orbs` stay until the Sunbulb
heal swap (a later step by the integrator).

## Technical constraints (hard-won project pitfalls)

- **Materials:** set `material_override` on the MeshInstance3D **node**, never `material` on
  the mesh sub-resource (renders black on gl_compatibility/ARM64).
- **UIDs:** never invent `uid="uid://..."` in new .tscn headers or ext_resource lines — omit
  them; Godot resolves by path.
- **load_steps** = ext_resource count + sub_resource count + 1.
- **Groups** go on the node line: `[node name="X" type="Y" groups=["foo"]]`.
- **`:=` inference fails** on methods of abstract/engine classes — annotate explicitly
  (`var n: int = obj.get_frames_available()`).
- **No scripts needed for static visuals.** Plants are decoration this phase: pure scenes,
  zero GDScript, unless genuinely needed.
- **Performance budget:** whole world ≤ ~700 placed instances, ≤ ~40k terrain vertices.
  Animals total ≤ 35. Use shared sub-resource meshes where possible (one SphereMesh reused).

## Validation each worker MUST run before reporting

```bash
cd /home/maurice/snap/godot-4/common/survivalm
snap run godot-4 --headless --script res://build_<yours>.gd   # builds + saves scenes
snap run godot-4 --headless --script res://<your_check>.gd    # or fold checks into the builder
```

The builder must `preload()` every scene it saved and re-instance it (proves they parse),
print the placed instance counts, and exit 0 with no ERROR/WARNING lines. Report back:
files created (absolute paths), instance counts per species/type, validation output tail,
any deviations from this spec (with reason).
