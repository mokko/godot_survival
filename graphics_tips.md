# Graphics Improvement Tips — Survival M (Ezo)

Order = payoff per effort. Renderer: **Compatibility (GLES3)** — required for the
Rock 5B Mali GPU; rules out SDFGI/voxel GI, SSR, high-res shadow cascades.

## 1. Materials & lighting (biggest jump, cheapest)
- Replace flat emissive with `StandardMaterial3D`: albedo + emission + roughness.
- `DirectionalLight3D` with shadows + `WorldEnvironment`: sky, distance fog (sells
  an island instantly), glow.
- Day/night cycle: rotate the sun, tint ambient — pairs with glow-plant lore
  (Lantern Reeds charge in light, glow at night).

## 2. Ground textures
- Terrain mesh is bare; bake **vertex colors from `island.gd` biomes**:
  sand near shore, grass, rock above a height. `biome_at(x, z)` already exists.
- Or a triplanar grass/rock/sand blend shader.

## 3. Better meshes
- Deform primitives: vertex jitter on trunks, irregular cones for Frostneedle,
  curved segments for Thornlash. Cheap, more organic.
- `MultiMeshInstance3D` for grass tufts and scattered detail = density for free.

## 4. Particles & water
- `GPUParticles3D` for Sporebell clouds, drifting spores, wind.
- Water plane: scrolling-UV normal-map shader — waves + shore foam.

## 5. Post-processing
- Glow/bloom on emissive plants at night — the single most "sci-fi island"
  effect; built into WorldEnvironment, works in Compatibility.

## Don'ts (Mali GPU)
- SDFGI / voxel GI, screen-space reflections, shadow map > 2k, multiple
  shadow-casting lights. One directional light with shadows is the budget.

## Suggested first move
Day/night cycle + fog + glow, then biome vertex colors on the terrain.
