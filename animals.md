# Fauna of Ezo — 6 Animal Species

All six animals use **simple NPC-style movement** — no pathfinding, no navigation mesh. Each entry
documents its movement pattern precisely enough to become a short GDScript state machine
(idle / walk / flee / chase / orbit, chosen by distance checks to the player).

## 1. Velvetback Grazer — *Cervocorpus mollis*
- **Found in:** SW Cape meadows, highland benches — herds of 3–5
- **Look:** deer-analog with six low legs and a moss-green velvet back; about 1.2 units tall.
- **Behavior:** grazes on Sunbulbs; harmless. Flees everything.
- **Movement (wander–flee):** idle 2–6 s → walk to a nearby point 3–8 units away → repeat. If the player comes within 6 units: flee directly away at 2× walk speed for 4 s, then resume wandering.
- **Ecology:** staple prey of the Dusk Stalker.

## 2. Pebble Scuttler — *Petroscutellum laterale*
- **Found in:** coastlines, caldera rim
- **Look:** knee-high sideways-walking crab, stone-gray shell with lichen patches — genuinely easy to mistake for a rock.
- **Behavior:** grazes the edges of Embermoss carpets (the moss dims where it walks). Harmless.
- **Movement (hop–scuttle):** pick a random point 2–5 units away, scuttle sideways to it (body always facing the player — it's a crab), pause, repeat. If player within 3 units: scuttle away at 3× speed.
- **Ecology:** keeps Embermoss carpets trimmed; food for nothing so far — it's too crunchy.

## 3. Lantern Drifter — *Aeromedusa lucens*
- **Found in:** wetlands, anywhere at night
- **Look:** 1.5-unit balloon-bell with hanging glowing tendrils, floating 2–5 units up.
- **Behavior:** feeds on Sporebell spores. Ignores the player completely.
- **Movement (drift):** constant slow linear drift (~0.5 units/s) in a slowly rotating wind direction, bobbing ±0.3 units on a sine wave. Turns toward nearby Sporebell clouds and lingers.
- **Ecology:** mobile night lighting; the wetlands look inhabited because of them.

## 4. Windvane Gull — *Circulus alatus*
- **Found in:** overhead everywhere; most visible over Windsinger groves and the caldera
- **Look:** falcon-gull analog with wide stabilizer wings; never lands.
- **Behavior:** nests inside hollow Windsinger trunks — the drone keeps the eggs warm.
- **Movement (orbit):** each gull flies a slow circle (radius 20–40 units) around a fixed anchor point, with a slight vertical bob; flocks of 2–4 at staggered altitudes.
- **Ecology/gameplay:** pure ambiance and a landmark hint — gulls circling means something interesting is below.

## 5. Dusk Stalker — *Noctursor venator*
- **Found in:** Central Massif and NE Cape only — never near spawn
- **Look:** low-slung quadruped, matte black, faint red eye-strip that gives it away at distance.
- **Behavior:** hunts at dusk; patrols alone. The island's only real danger.
- **Movement (patrol–chase):** patrols between 2–3 fixed points inside a ~30-unit territory. If the player comes within 10 units: chase in a straight line at 1.5× player walk speed (a sprint barely outruns it). Gives up when you leave its territory or survive 8 s, then returns to patrol.
- **Contact:** −5 life per touch, 1 s grace between hits.
- **Ecology:** apex predator; Velvetback Grazers flee on sight.

## 6. Rippleback — *Undosaurus lacus*
- **Found in:** Caldera Lake only
- **Look:** 6-unit slow swimmer; segmented back plates break the surface like a row of moving islands.
- **Behavior:** unknown diet, unknown purpose. The survey crew has one blurry photo.
- **Movement (surface–loop):** swims a large rounded-triangle loop under the lake surface; every 40–70 s it surfaces for ~5 s (back plates rise, water sound), then dives again. Never interacts with the player.
- **Ecology/gameplay:** pure mystery and ambiance; optional future hook (rideable? fishing minigame?).

---

## Movement style summary

| Animal | Pattern | Speeds | Reacts to player? |
|--------|---------|--------|-------------------|
| Velvetback Grazer | wander–flee | walk 2, flee 4 (2×) | flees within 6 units |
| Pebble Scuttler | hop–scuttle | walk 1.5, flee 4.5 (3×) | flees within 3 units |
| Lantern Drifter | drift + bob | drift 0.5 | ignores you |
| Windvane Gull | orbit | orbit ~3 | ignores you |
| Dusk Stalker | patrol–chase | patrol 2, chase 7.5 (1.5× player walk) | chases within 10 units |
| Rippleback | surface–loop | swim 2 | ignores you |

## Ecology at a glance

- Sunbulbs → Grazers → Dusk Stalker (and you).
- Thornlash ambushes Grazers along the meadow paths.
- Sporebell spores → Lantern Drifters.
- Gulls nest in Windsinger trunks; gulls circling = landmark below.
- Scuttlers trim Embermoss; Rippleback does whatever Rippleback does.

*Status: draft for approval. Godot step comes after flora/plants.md + animals.md are approved.*
