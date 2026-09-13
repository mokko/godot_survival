class_name Armor
extends Resource
## Base for wearable armor. Mechanic: armor absorbs a percentage of
## incoming damage (absorption), and each hit costs durability. When
## durability reaches 0 the armor breaks and absorbs nothing.

@export var absorption: float = 0.2   # fraction of damage soaked up (0..1)
@export var max_durability: float = 100.0
var durability: float = max_durability


func absorb(raw_damage: float) -> float:
	## Returns the damage that gets through after the armor's share.
	## Broken armor absorbs nothing. Degrades by the damage it ate.
	if durability <= 0.0:
		return raw_damage
	var eaten: float = clampf(raw_damage * absorption, 0.0, raw_damage)
	durability = maxf(durability - eaten * 0.5, 0.0)   # degrade at half the absorbed amount
	return raw_damage - eaten


func is_broken() -> bool:
	return durability <= 0.0


## --- item-id table (inventory-held armor; no node needed) ----------------

const STATS := {
	"leather_armor": {"name": "Leather Armor", "absorption": 0.3, "durability": 80.0},
}


static func stats_of(item_id: String) -> Dictionary:
	return STATS.get(item_id, {})
