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


static func has_blade(item_id: String) -> bool:
	## Does this weapon have a blade? It matters to the notebook: an animal is only
	## worth examining if it was killed with an edge (fauna/fauna_base.gd leaves a
	## specimen when the killing blow came from one). An arrow is a point, not a
	## blade, and fists are neither — so a killed-at-range animal is lost to the
	## survey, which is what makes the katana and the tanto the surveyor's tools.
	match item_id:
		"sword", "dagger":
			return true
	return false
