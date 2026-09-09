# Flora of Ezo — 12 Plant Species

**Ezo** is the island we're building: a medium-sized landmass (~300 × 250 units — about a minute to
sprint coast to coast) whose outline is a 1:1000 homage to **Hokkaido**: a diamond body with two long
peninsulas — the southwest cape (spawn point, like arriving by ferry at Hakodate) and the northeast
cape — a central highland massif, a caldera lake, and eastern wetlands. The survey crew named the
island after Hokkaido's old name. Nobody has bothered naming the planet yet.

## Biomes

| # | Biome | Hokkaido analog | Character |
|---|-------|-----------------|-----------|
| 1 | SW Cape | Oshima Peninsula | temperate meadows, player arrival |
| 2 | Central Massif | Daisetsuzan | cold ridgelines, dense strange flora |
| 3 | Caldera Lake | Tōya | deep clear water, island-in-lake |
| 4 | Eastern Wetlands | Kushiro | glowing bogs, shallow water |
| 5 | NE Cape | Shiretoko | remote, wind-scoured, weirdest flora |
| 6 | Coastlines | — | cliffs, tide pools, drift fields |

---

## 1. Windsinger — *Aerophonex columnaris*
- **Found in:** Central Massif ridgelines, NE Cape (groves of 3–10)
- **Look:** hollow, branchless column 8–15 units tall, tapering; a crown of thin spines at the top; faint emissive rings at the trunk segments.
- **Behavior:** wind through the hollow trunk makes deep organ drones — each tree has its own pitch (longer trunk = lower note). Groves drone in slow chords.
- **Gameplay (later):** a landmark you can *hear*; thumping the trunk plays its note.
- **Godot sketch:** tapered cylinder + emissive rings; drone via `AudioStreamGenerator` (same technique as tone440).

## 2. Sunbulb — *Lumenradix esculenta*
- **Found in:** SW Cape meadows, wetland margins
- **Look:** squat plant, one glossy orange bulb half-buried in soil, glowing warmly; dims when picked.
- **Behavior:** photosynthesizes so hard it cooks its own corm — the bulb is edible and packed with water and sugar.
- **Gameplay (later):** primary heal item — candidate to **replace the orb pickups** (+15 life, 5 s respawn, random spot, reusing the existing orb logic).
- **Godot sketch:** sphere half-sunk in ground + emissive orange material.

## 3. Lantern Reed — *Phosphostachys virgata*
- **Found in:** Eastern Wetlands, caldera shore
- **Look:** thin reed 2–3 units tall, teardrop seed head glowing cyan; sways in wind.
- **Behavior:** seed heads charge in light and glow all night; groves look like streetlights across the bogs.
- **Gameplay (later):** free night lighting; marks safe paths through the bogs (reeds don't grow where the ground is soft).
- **Godot sketch:** thin cylinder + emissive teardrop; gentle sine sway.

## 4. Mirrorlily — *Speculiflora rotunda*
- **Found in:** Caldera Lake only
- **Look:** floating disc 1–2 units across, mirror-chrome upper surface, dark underside rim.
- **Behavior:** the metallic leaf reflects the sky so well birds attack their own reflections.
- **Gameplay (later):** water-crossing platforms — the larger discs hold your weight and bob when you land on them.
- **Godot sketch:** flat cylinder + metallic material, slow bob on the water.

## 5. Glasspetal — *Vitripetala campana*
- **Found in:** Central Massif, NE Cape
- **Look:** waist-high bellflower with transparent silica petals that chime in wind — high, glassy tinkling, a pitched counterpoint to the Windsinger drones.
- **Behavior:** petals shatter if something sprints through; regrow over a day.
- **Gameplay (later):** harvestable glass shards; the tinkling stops near you — a sound-based "someone/something moved here" cue.
- **Godot sketch:** small cone flower head, transparent material.

## 6. Embermoss — *Pyrotapetum molle*
- **Found in:** wetland hummocks, highland rocks, old hot-spring lines
- **Look:** carpet of glowing red-orange moss, follows the ground contour.
- **Behavior:** dims where stepped on, then slowly re-brightens — footprints glow for a few seconds.
- **Gameplay (later):** night-time trail marker (you can see where you've been); Pebble Scuttlers graze its edges, dimming it as they pass.
- **Godot sketch:** flattened disc mesh on rocks/ground, emissive with a proximity-dim shader later.

## 7. Thornlash — *Flagellumspinex agilis*
- **Found in:** SW Cape tallgrass, wetland margins
- **Look:** coiled tendril 2 units long, studded with hooked thorns; hard to spot until it moves.
- **Behavior:** ambush hunter — lashes anything warm that comes within 3 units, then re-coils for ~5 s (safe window to grab things near it).
- **Gameplay (later):** the first hazard; teaches aggro radius. Contact costs a chunk of life.
- **Godot sketch:** curved cylinder segment + small spike cones, animated arc swing on proximity.

## 8. Sporebell — *Vaporcapsa alta*
- **Found in:** Eastern Wetlands, NE Cape
- **Look:** tall pale dome cap on a 1.5-unit stem, pulsing faintly.
- **Behavior:** releases a soft spore cloud when anything comes within 2 units; the cloud hangs, blurs vision, then disperses. Harmless — but it feeds the Lantern Drifters.
- **Gameplay (later):** vision-obscuring ambiance; popping one attracts Driftjellies (crowd-control tool later?).
- **Godot sketch:** dome (sphere half) + stem cylinder; a transparent expanding sphere for the cloud.

## 9. Hoverfern — *Levifrons pumilio*
- **Found in:** Central Massif (densest), caldera rim
- **Look:** small fern whose spore clumps hover 0.5–1 unit above it, faintly violet, gently bobbing.
- **Behavior:** electrostatic lift keeps the clumps airborne; they drift away if you walk through them.
- **Gameplay (later):** ambiance for now; the lift effect is a hook for a future updraft/glider mechanic.
- **Godot sketch:** small cone leaves + 3 floating emissive spheres per fern, sine bob.

## 10. Frostneedle — *Cryoconifera acuta*
- **Found in:** Central Massif (dense forest on the massif flanks)
- **Look:** conifer analog, ice-blue needles, frost-sheened trunk, 6–10 units tall.
- **Behavior:** antifreeze sap keeps it from freezing; the blue cones are edible and taste like cucumber.
- **Gameplay (later):** minor heal + brief cold resistance when we add the massif cold zone; the densest cover to hide from Dusk Stalkers.
- **Godot sketch:** stacked cones, blue-white material.

## 11. Pulsegrass — *Pulsogramen radians*
- **Found in:** SW Cape meadows, highland benches (everywhere there's open grass)
- **Look:** ordinary-looking meadow grass that carries waves of soft light sweeping across whole slopes.
- **Behavior:** the whole meadow pulses on a shared ~20 s rhythm; each region's wave travels in a slightly different direction.
- **Gameplay (later):** gorgeous night ambiance (a global pulse shader); wave direction is a natural compass once you learn the regions.
- **Godot sketch:** ground-level emissive tint that sweeps by region — shader experiment, keep for later.

## 12. Ghostsilk — *Parasitex filum*
- **Found in:** anywhere plants cluster, worst on the NE Cape
- **Look:** pale thread-vine webbing over other plants; infested clearings full of white husks.
- **Behavior:** parasite — drains Sunbulbs and Lantern Reeds dry, leaving bleached skeletons.
- **Gameplay (later):** marks "drained zones" where no Sunbulbs spawn; cutting the silk (future tool) releases the trapped light as a heal burst. Low-key creepy.
- **Godot sketch:** thin white cylinder strands draped between plants.

---

## Ecology at a glance

- **Sunbulbs** feed the Velvetback Grazers → grazers feed the **Dusk Stalker** (and you).
- **Thornlash** ambushes grazers along the same meadow paths.
- **Sporebell** spores feed the **Lantern Drifters**.
- **Ghostsilk** drains Sunbulbs and Lantern Reeds — barren white patches.
- **Windsinger** groves: Windvane Gulls nest in the hollow trunks; the drone keeps the eggs warm.
- **Rippleback**: lives in the caldera. Eats nobody knows what. One blurry photo exists.

## Summary table

| # | Plant | Biome | Role |
|---|-------|-------|------|
| 1 | Windsinger | Massif, NE Cape | landmark + sound |
| 2 | Sunbulb | SW Cape, wetland edges | heal (orb replacement) |
| 3 | Lantern Reed | Wetlands, lake shore | light, path marking |
| 4 | Mirrorlily | Caldera Lake | water platform |
| 5 | Glasspetal | Massif, NE Cape | resource + sound cue |
| 6 | Embermoss | Wetlands, Massif | trail marking |
| 7 | Thornlash | SW Cape, wetland edges | hazard |
| 8 | Sporebell | Wetlands, NE Cape | vision blocker |
| 9 | Hoverfern | Massif, lake rim | ambiance (future lift) |
| 10 | Frostneedle | Massif | cover, minor heal |
| 11 | Pulsegrass | SW Cape, Massif | ambiance, compass |
| 12 | Ghostsilk | everywhere, esp. NE Cape | zone marker |

*Status: draft for approval. Godot step comes after plants.md + fauna/animals.md are approved.*
