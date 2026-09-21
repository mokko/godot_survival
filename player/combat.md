# The combat system, in words

Combat is small on purpose. Everything in it follows from three rules:

1. **Anything that can be hurt is in the `damageable` group** and exposes
   `damage(amount)`. The player is the only thing in the game that deals
   damage, so "who hit me" never has to be passed along.
2. **A fight is group membership.** An animal that has been hurt joins
   `aggro_fauna`; the HUD reads that group, the animal leaves it when the
   fight is over, and nothing has to remember to end anything.
3. **Every hit is answered.** A landed blow flashes and shoves its target; a
   blow that lands on the player flashes the screen. If you cannot see what
   happened, it did not happen — that is the whole reason phases 5 and 6
   below exist separately from the numbers.

This file is the map: what runs in what order, and which function does which
job. Numbers are quoted so a tuning pass does not have to read the code first.

---

## The cast

| File | Owns |
| --- | --- |
| `player/player.gd` | input, energy/health, the damage the player *takes*, HUD, death |
| `player/combat.gd` | the player's weapons: katana, jab, bow, worn armour state |
| `player/slash.gd` | the katana swing animation and its trail; fires the damage callback at mid-swing |
| `player/equipment.gd` | the drone body, arms, weapon props, the trail mesh, the jab animation |
| `items/weapon.gd` | the damage table (per item id) |
| `items/armor.gd` | the armour table (absorption, durability) |
| `items/destroyable.gd` | `life`, death (puff + flopp), knockback, `sync_to_physics` unfreeze |
| `items/destroyable_area.gd` | the same contract for Area3D-based plants |
| `items/arrow_projectile.gd` | a shot arrow: flight, drop, and the hit that deals bow damage |
| `fauna/fauna_base.gd` | `class_name Fauna`: the shared "I was hurt, now I fight" behaviour |
| `fauna/*.gd` | six species: ambient movement + the aggro hooks that make each one different |
| `ui/energy_meter.gd` | the four-battery meter that draws `player.life` |
| `ui/inventory.gd` | slots, equipping, and the E-key path for wearing armour |

---

## Phase 1 — the player swings

`player.gd:_unhandled_input()` decides what a click means:

- **Left click, katana equipped** → `do_slash()` → `combat.try_slash()`
- **Left click, nothing equipped and nothing grabbable under the crosshair**
  → `_toggle_grab()` returns false → `do_punch()` → `combat.try_punch()`
- **Right click held / released** → `_begin_draw_bow()` / `_release_bow()` →
  `combat.begin_draw_bow()` / `combat.release_bow()`
- **E on an armour slot** (in `ui/inventory.gd`) → `player._on_armor_changed()`
  → `combat.load_armor_state()`, which is the single owner of a worn piece

`combat.try_slash()` builds the swing node lazily (`_ensure_slash()`, which
also wires the sword prop and the trail into it), plays the swing sound, and
calls `slash.slash()`. A swing already in flight is refused
(`slash.can_slash()`), which is the katana's only cooldown — the 0.35 s
animation is the rate limit. The jab has its own: `PUNCH_COOLDOWN = 0.4 s` in
`combat.gd:_process()`.

## Phase 2 — the swing becomes a strike

`player/slash.gd` owns the 0.35 s animation: it sweeps the sword pivot
`rotation.y` from -0.9 to +0.9 rad, sweeps and fades the crescent trail
(`TRAIL_SWEEP = 0.7 rad`, alpha `0.5 * sin(t*PI)`), and at half-swing
(`t >= 0.5`) calls the damage callback exactly once (`_hit_done`).

The callback is `combat._slash_damage()` → `combat._strike(range, half_angle,
item_id)`. **`_strike()` is the only place that decides what a blow hits.**
It scans the `damageable` group, keeps anything inside the range and within
the half-angle of the drone's forward direction (`-basis.z`, flattened to the
ground plane), then calls `damage(Weapon.damage_of(item_id))` on each. If
nothing was in the cone it returns 0 early — a whiff shows nothing at the
crosshair.

- Katana: `SLASH_RANGE = 2.2 m`, `SLASH_HALF_ANGLE = 0.7 rad`, item `"sword"` → 25
- Jab: `PUNCH_RANGE = 1.8 m`, `PUNCH_HALF_ANGLE = 0.6 rad`, item `""` → 5
  (reach is the katana's edge, not its only feature)
- Arrow: `items/arrow_projectile.gd:_on_body_entered()` → 15, with the arrow
  sticking where it lands

### The cone has eyes: line of sight

Reach is measured on the ground plane, so the cone is only half of "did that blow
land". `_strike()` asks `world/sight.gd` (`Sight.clear`) before each target it is about
to hurt, and an animal asks the same question in the other direction:
`fauna_base.gd:_try_hit()` before a contact bite, and `stalker.gd:_bite()` before the
wind-up lands — the latter also re-measuring the distance at the moment it lands
instead of reusing the one sampled before the telegraph.

Two rules, both deliberate:

- **A solid body in between stops the blow** — terrain, a boulder, a trunk. Without it
  a swing cut plants through a hill and a stalker bit through rock.
- **Flat ground cover does not** — embermoss and mirrorlily_small are `Area3D`-based,
  and a blow goes through them exactly as the player walks through them.

`tests/test_line_of_sight.gd` covers the swing, both animal paths, the cover rule, the
stalker's re-measurement, and places its blocker on the ray itself (a blocker fat
enough to contain the ray's start point blocks nothing at all).

## Phase 3 — the blow lands on the target

The target's own `damage()` decides what being hit means. Three cases:

- **`items/destroyable.gd:damage()`** (the Node3D base, and every animal):
  `life -= amount`; at or below zero `_die()` spawns the death puff and frees
  the node; a survivor is shoved 1.2 m away from the player via
  `knockback_from()` — gated on `AnimatableBody3D`, so animals slide and the
  Area3D/StaticBody3D plants stay rooted where they grow.
- **`items/destroyable_area.gd:damage()`** (plants that need a sensor): same
  50 life, same puff, no knockback.
- **`fauna/fauna_base.gd:damage()`** — the interesting one. It calls
  `super.damage()` first, then, if the animal is still alive, calls
  `provoke()`. **The hit that kills is not a fight**: a corpse does not aggro.

The dusk stalker adds two things on top (`fauna/stalker.gd`): a white-hot
emission flash on its body for 0.18 s, and, in `_die()`, loot — an
`emberstone` always and `arrows` half the time, dropped beside the corpse and
parented to the stalker's *parent* so it cannot be freed with the body.

## Phase 4 — the fight the animal starts

`fauna_base.gd` is the shared fight; species only state what is different.
Being provoked means:

- `provoke()` → `add_to_group("aggro_fauna")` → `_on_aggro()` → a growl.
  `calm_down()` is the exact inverse, and it is what takes the HUD line down
  when the last angry animal leaves the group.
- Each physics frame the animal calls **`aggro_frame(delta)`**. It returns
  true when the fight owns that frame, and the ambient wandering is skipped —
  that return value is the entire interface between "being an animal" and
  "being in a fight".
- `_aggro_process()` → `_aggro_move()` (charge at `aggro_speed()`) →
  `_try_hit()`: inside `aggro_reach()`, off cooldown, so
  `player.damage(aggro_damage())` and `_on_hit()`.
- `_aggro_tick()` runs the timers, and the fight ends by itself: the player
  gone past `AGGRO_LEASH = 30 m` (or unreachable at all — the rippleback
  cannot follow anyone ashore, the gull can) for `GIVE_UP_TIME = 5 s` →
  `calm_down()`.

Per species, for the record: grazer 5 m/s / 4 dmg / 1.7 m reach; scuttler
1.4 m reach / 3 dmg (a claw pinch); drifter 3 m/s / 3 dmg (six times its
drift); gull 9 m/s (a stoop, from the air); rippleback 8 dmg / 2.4 m (the big
one, and the only one that must fight inside the lake); stalker 5 dmg with a
0.4 s wind-up, and it sees 14 m instead of 10 m after sunset
(`sight_radius()` asks `world/day_cycle.gd` through the `day_cycle` group).

The stalker is deliberately the odd one out: it runs `_aggro_tick()` and keeps
its own patrol/chase/return state machine, biting through `_bite()` after the
wind-up instead of using `_try_hit()`. Provoked, it drops the territory and
sight leashes but keeps the telegraph — closing the distance is the tell for
the other five, the lunge is the tell for this one.

## Phase 5 — a blow lands on the player

Everything that can hurt the player arrives at **one** function,
`player.gd:damage(amount)`, in this order:

1. `_game_over` or still inside the grace window → ignored entirely.
2. `combat.absorb(amount)` — armour eats `absorption` (leather: 30%) and
   loses durability (0.5 per point eaten: 1.5 durability per 10-damage hit,
   so the 80-point leather piece survives roughly 53 such hits). Whatever
   passes through comes back.
3. Feedback, unconditionally on a hit that counted: `_invuln = INVULN_TIME`
   (0.6 s), the red screen flash to alpha 0.55, and the hurt sound.
4. `_apply_damage(through)` → `life -= through`; at zero
   `_trigger_game_over()`, otherwise `_update_hud()`.

Both the grace window and the flash exist because a contact-based enemy can
deliver several blows in one second of physics frames; without them a single
animal read as an instant kill. The grace window is shorter than every
species' blow cooldown, so a real fight still lands every bite.

Energy also drains on its own: `LIFE_DRAIN_PER_SEC = 0.25` against
`START_LIFE = 40`, a 160-second tank, four batteries of 40 s. Sunbulbs heal
15 (`heal()`, capped at a full tank) and count toward the collection.

## Phase 6 — feedback and HUD

- `show_hit_marker()` — four ticks around the crosshair for 0.16 s, called
  from `combat._strike()` **only** when something took the blow.
- `hurt_flash_alpha()` / `_hurt_rect` — the red overlay on damage
  (`HURT_FLASH_FADE = 2.5` alpha/s).
- `_update_hud()` — energy meter (`ui/energy_meter.gd:set_energy()`, four
  batteries, half-charge resolution), sunbulb count, armour label.
- `_update_enemy_hud()` → `nearest_aggro_enemy()` — the `Enemy: <name>
  <life>/<max>` line, driven purely by the `aggro_fauna` group. Nearest
  rather than first, because with a provoked herd the line should name the one
  in your face.

The hit marker and the hurt flash are built in code (`_build_hit_marker()`,
`_build_hurt_flash()`), not in `world/main.tscn`, so an editor save cannot
clobber them.

## Phase 7 — how it all ends

- **The animal dies**: puff, sound, loot, node freed; if it was the last one
  in `aggro_fauna`, the HUD line goes with it.
- **You die**: `_trigger_game_over()` calms *every* `aggro_fauna` member
  (`calm_down()`), clears the inventory and the savegame, shows the death
  screen and frees the mouse. ESC restarts (`_restart()`), which resets energy,
  the collection and the view, with the katana in hand.
- **You walk away**: leash + `GIVE_UP_TIME`, then the animal resumes its
  ambient life exactly where it left off.

## Where to change what

- Damage per weapon: `items/weapon.gd` (`damage_of`).
- How much a blow is answered with: `items/destroyable.gd`
  (`KNOCKBACK_DISTANCE`), `fauna/stalker.gd` (`FLASH_TIME`).
- How dangerous each animal is: the `aggro_*()` hooks at the top of each
  `fauna/*.gd`; the shared defaults are at the top of `fauna/fauna_base.gd`.
- How much punishment the player takes: `player/player.gd` (`START_LIFE`,
  `INVULN_TIME`, `LIFE_DRAIN_PER_SEC`) and `items/armor.gd`.
- What a swing hits: `combat._strike()` and its four constants.

## Tests

- `tests/test_slash.gd` — swing starts, trail is a crescent and sweeps, cone
  hits in front and misses behind/out of range, hit marker lights and fades.
- `tests/test_aggro.gd` — all six species aggro on a hit and land a blow, the
  leash ends the fight, the Enemy HUD line tracks it.
- `tests/test_stalker_ai.gd` — territory adoption, patrol, chase, wind-up
  before the bite, hit cooldown, leash, flash and knockback.
- `tests/test_stalker_reward.gd` — knockback away from the attacker, plants
  not sliding, loot beside the corpse and collectable, death sound.
- `tests/test_player_hurt.gd` — grace window, flash, armour absorbing and
  degrading, death still lethal.
- `tests/test_weapons_armor.gd` — weapon table, armour absorption and
  breakage, the E-key path.
- `tests/test_destroyable.gd` — 50 life and the death puff for every species.
- `tests/test_energy_meter.gd` — four batteries, half-charge rounding.
