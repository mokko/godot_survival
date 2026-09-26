extends RefCounted
## The robot parts the drone owns — what the Frame screen can fit onto it.
##
## A static registry, like `ui/pedia_notes.gd`: the world writes to it
## (`items/part_pickup.gd`, the moment a part is found), the Frame screen reads it, and
## the player saves and restores the whole set with the rest of its state (the `parts`
## key).
##
## **Parts never touch the inventory** (Maurice's call, 26 Sep): finding one puts it
## straight onto the robot's own list, so a part needs no `items/item_db.gd` id, no
## inventory icon and no Pedia subchapter — the coverage `tests/test_pedia.gd` enforces
## for equipment simply does not apply to them. It also keeps the inventory a bag of
## tools and loot rather than a drawer of limbs.
##
## A fresh run clears it; dying does not. Parts belong to the drone the way the notebook
## does, not to the loot it drops.

static var _owned: Dictionary = {}


static func own(id: String) -> bool:
	## Records a part. True when it was new, so a caller can tell "just found" from
	## "already had that" — the pickup says something different for each.
	if id == "" or _owned.has(id):
		return false
	_owned[id] = true
	return true


static func has(id: String) -> bool:
	return _owned.has(id)


static func owned() -> Array:
	## Everything owned, sorted so a save file does not churn between writes.
	var ids: Array = _owned.keys()
	ids.sort()
	return ids


static func restore(ids: Array) -> void:
	_owned.clear()
	for id in ids:
		_owned[str(id)] = true


static func clear() -> void:
	_owned.clear()