# Fauna of Ezo — 6 Animal Species

All six animals use **simple NPC-style movement** — no pathfinding, no navigation mesh. Each entry
documents its movement pattern precisely enough to become a short GDScript state machine
(idle / walk / flee / chase / orbit, chosen by distance checks to the player).

## 1. Velvetback Grazer — *Cervocorpus mollis*
- **Found in:** SW Cape meadows, highland benches — herds of 3–5
- **Look:** deer-analog with six low legs and a moss-green velvet back; about 1.2 units tall.
- **Behavior:** grazes on Sunbulbs; flees everything — until it is hit (see *Provoked* below).
- **Movement (wander–flee):** idle 2–6 s → walk to a nearby point 3–8 units away → repeat. If the player comes within 6 units: flee directly away at 2× walk speed for 4 s, then resume wandering.
- **Ecology:** staple prey of the Dusk Stalker.

## 2. Pebble Scuttler — *Petroscutellum laterale*
- **Found in:** coastlines, caldera rim
- **Look:** knee-high sideways-walking crab, stone-gray shell with lichen patches — genuinely easy to mistake for a rock.
- **Behavior:** grazes the edges of Embermoss carpets (the moss dims where it walks). Harmless until hit.
- **Movement (hop–scuttle):** pick a random point 2–5 units away, scuttle sideways to it (body always facing the player — it's a crab), pause, repeat. If player within 3 units: scuttle away at 3× speed.
- **Ecology:** keeps Embermoss carpets trimmed; food for nothing so far — it's too crunchy.

## 3. Lantern Drifter — *Aeromedusa lucens*
- **Found in:** wetlands, anywhere at night
- **Look:** 1.5-unit balloon-bell with hanging glowing tendrils, floating 2–5 units up.
- **Behavior:** feeds on Sporebell spores. Ignores the player — until it is hit (see *Provoked* below).
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
  Never interacts with the player unless hit (*Provoked*, below) — and it still
  cannot leave the lake.
- **Movement (surface–loop):** swims a large rounded-triangle loop under the lake surface; every 40–70 s it surfaces for ~5 s (back plates rise, water sound), then dives again. Provoked, the loop stops and it comes up to ram (see below).
- **Ecology/gameplay:** pure mystery and ambiance; optional future hook (rideable? fishing minigame?).

---

## Provoked: every animal fights back

Hurt one and the fight is on. The rules are the same for all six species and live
in one place — `fauna/fauna_base.gd`, which every species extends; a species only
states what makes it different (name, speed, reach, damage, cooldown, how it gets
about).

- **Trigger:** any damage from the player — katana, jab or arrow.
- **The fight:** the animal drops its ambient behaviour (wandering, orbiting,
  drifting, patrolling) and closes on the player, striking on its own cooldown.
- **Over when:** the animal dies, the player outruns it (further than
  `AGGRO_LEASH` = 30 units away for `GIVE_UP_TIME` = 5 s), the player dies, or —
  for the Rippleback — the player simply climbs out of the water.
- **HUD:** while anything is in the `aggro_fauna` group the HUD shows
  `Enemy: <name>  <life>/50` under the sunbulb count; the nearest angry animal
  wins when several are provoked at once. The line lives and dies with the group.

| Animal | Charge speed | Reach | Damage | Cooldown | Gait once provoked |
|--------|--------------|-------|--------|----------|--------------------|
| Velvetback Grazer | 5.0 | 1.7 | 4 | 1.5 s | runs at you on foot |
| Pebble Scuttler | 4.5 | 1.4 | 3 | 1.0 s | scuttles straight at you, hops and all |
| Lantern Drifter | 3.0 | 1.6 | 3 | 1.6 s | drifts at you, sinking to head height |
| Windvane Gull | 9.0 | 1.8 | 4 | 1.5 s | stoops: comes down and stays on you, never lands |
| Dusk Stalker | 7.5 | 1.9–2.5 | 5 | 1.0 s | its usual wind-up and bite, but territory and sight limits no longer apply |
| Rippleback | 5.0 | 2.4 | 8 | 2.0 s | charges at the surface, held inside the lake |

---

## Movement style summary

| Animal | Pattern | Speeds | Reacts to player? |
|--------|---------|--------|-------------------|
| Velvetback Grazer | wander–flee | walk 2, flee 4 (2×) | flees within 6 units, fights when hit |
| Pebble Scuttler | hop–scuttle | walk 1.5, flee 4.5 (3×) | flees within 3 units, fights when hit |
| Lantern Drifter | drift + bob | drift 0.5 | ignores you, fights when hit |
| Windvane Gull | orbit | orbit ~3 | ignores you, fights when hit |
| Dusk Stalker | patrol–chase | patrol 2, chase 7.5 (1.5× player walk) | chases within 10 units, hunts harder when hit |
| Rippleback | surface–loop | swim 2 | ignores you, fights when hit (in the water only) |

## Ecology at a glance

- Sunbulbs → Grazers → Dusk Stalker (and you).
- Thornlash ambushes Grazers along the meadow paths.
- Sporebell spores → Lantern Drifters.
- Gulls nest in Windsinger trunks; gulls circling = landmark below.
- Scuttlers trim Embermoss; Rippleback does whatever Rippleback does.

*Status: all six species are in the game (`fauna/*.tscn`, placed by
`tools/build_animals.gd`); this file stays their behavioural spec. The aggro rules
every one of them shares are in the *Provoked* section above.*
