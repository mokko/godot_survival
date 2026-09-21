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
