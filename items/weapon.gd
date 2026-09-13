class_name Weapon
extends "res://items/destroyable.gd"
## Base for wieldable weapons: how much damage a hit deals.
## Weapons in the inventory are stats-only; the world model is separate.

@export var attack_damage: float = 10.0


static func damage_of(item_id: String) -> float:
	## Lookup for inventory-held weapons (no node needed).
	match item_id:
		"sword":
			return 25.0
		"dagger":
			return 12.0
		"bow":
			return 15.0   # per arrow, before distance falloff
		_:
			return 5.0    # bare hands
