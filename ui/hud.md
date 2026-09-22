# The HUD

What the drone's own surface shows. Built in code rather than in `world/main.tscn`,
so an editor save cannot clobber it (`player/player.gd`).

## The drone's charge: four batteries

The drone's charge shows in the top-left of the HUD as **four batteries**, each full,
half or empty — the hearts of this game, and what the `Life: 42` label used to be. The
tank is 40 (`player/player.gd`'s `START_LIFE`), so a battery is 10 and a half is 5, and
the display rounds *up* to the next half: one point left still shows half a battery, so
a battery only reads empty when that quarter of the tank is really gone
(`ui/energy_meter.gd`, where the rule is a static the tests check without a renderer).
Just being switched on costs 0.25 a second — 160 s on a full tank, or 40 s a battery —
and **Sunbulbs** feed 15 (a battery and a half) back, never past a full tank. A stalker
bite takes 5, one battery's half.

## Also on this surface

The crosshair, the four white ticks that say a swing connected
(`player.gd:show_hit_marker()`), and the red flash for taking damage
(`_build_hurt_flash()`) — see `player/combat.md` for when each one fires.

The top-right corner used to carry a **Sunbulbs** counter. It is gone: how many
you have picked up is a number about the past, not a reading the drone needs
while it is walking, and the count is still kept and still written into every
save (`SaveGame`), where the Saves screen shows it per slot. The energy meter
is the live reading — Sunbulbs are what refill it.

## Tests

`tests/test_energy_meter.gd` — four batteries, half-charge rounding, without a
renderer.
