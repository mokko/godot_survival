class_name Armor
extends Resource
## Wearable-armor table. Mechanic: armor absorbs a percentage of incoming
## damage (absorption) and each hit costs durability; at 0 it breaks and
## absorbs nothing. The absorption arithmetic deliberately lives in exactly one
## place — player/combat.gd, the only thing that tracks a worn piece.

const STATS := {
	"leather_armor": {"name": "Leather Armor", "absorption": 0.3, "durability": 80.0},
}
