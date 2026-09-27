# Boats: sailing between the islands

The route and the hull rules. `world/island.gd` holds the navigability test and
`tools/build_boats.gd` moors the hulls; this file is the behaviour.

Every island except the last has a boat moored off its **south coast**
(Ezo → Honshu → Shikoku → Kyushu, and Kyushu is the destination so it has none). Stand beside a
boat and press **E** to board, **W/S** to sail, **A/D** to steer, **E** again to go ashore — refused
in open water, because the sea floor past the shallows has no collision and stepping off would be a
fall-death. The hull only floats in water `Ezo.is_navigable` accepts (`world/island.gd`'s `HULL_DEPTH`,
the same depth `tools/build_boats.gd` moors in), so a bow aimed at a beach is refused with a message
and the boat cannot be sailed through an island or under its hills. Moored boats carry a lit lantern
so they can be found from the water after dark. The route order lives in `tools/build_boats.gd`; re-bake
placements with:

```bash
snap run godot-4 --headless --script res://tools/build_boats.gd
```

## A boat is the map

Sailing **right round** an island is what writes it into the Pedia's Islands chapter. While the drone
is aboard, `player/player.gd::_chart_step()` credits the compass sector the hull is in, for the island
whose coast it is nearest; all twelve sectors are required, and the geometry (the sectors, and the
90 m band that is a *measured* number) lives in `world/island.gd`'s charting section. Nothing is
written by standing on an island or landing on one — including the island a run wakes up on — so the
chapter is a map the player drew, and the book opens on four empty chapters. The **first boat a run
boards** plays `ui/story_text.gd`'s `boat_discovery` page, which is where that is said (`world/boat.gd`
asks for it once per process, the bench's rule; an id with no page written behind it plays nothing).
`ui/pedia.md` has the chapter's side of it, `todo.md` the decisions.

## A death puts a boat back on its mooring

`world/boat.gd::respawn()`, asked for by `player/player.gd::_restart` walking the `pickup` group:
the hull returns to `mooring()` with its bow yawed out to sea the way `tools/build_boats.gd` placed it,
and its **driver is let go** (`leave_boat()`) rather than just moved — while a boat has a driver it
pins the drone to its deck every physics frame (`_seat_driver`), so a boat that kept one would drag a
drone respawned at the spawn point straight back out to sea. A hull left mid-strait, or one the drone
died aboard (energy drains while sailing), is otherwise somewhere the next attempt cannot reach — and
boats are the only way past Ezo. `tests/test_respawn.gd` pins the lot.
