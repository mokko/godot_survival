extends RefCounted
## Which milestones a run has been shown — the count behind the story screen's "x/y".
##
## A static registry, like `ui/pedia_notes.gd` and `player/robot_parts.gd`: the story screen
## writes to it the moment a milestone page is accepted, the screen reads it back to draw the
## indicator, and the player saves and restores the whole set with the rest of its state (the
## `milestones` key).
##
## It records **what the player has been told**, not what they have done: the milestone itself
## is the discovering, so a page is counted at the moment it is played. And because a milestone
## is shown **once a run** (`ui/story.gd:play_milestone` refuses one this run has already been
## shown), the registry is also what stops a page being played twice — a second katana asks for
## the page and gets nothing, and a bench the run has already been told about opens straight to
## the Robo Editor instead of repeating itself.
##
## A fresh run clears it. Dying does not: like the notebook, this is the run's own record of
## what it has learned, not something the drone was carrying.

static var _seen: Dictionary = {}


static func discover(id: String) -> bool:
	## Records a milestone. True when it was new, so a caller can tell "just discovered" from
	## "already knew that" — which is what keeps the count honest for a replay.
	if id == "" or _seen.has(id):
		return false
	_seen[id] = true
	return true


static func has(id: String) -> bool:
	return _seen.has(id)


static func count() -> int:
	## How many milestones have been discovered — the x in "x/y".
	return _seen.size()


static func seen() -> Array:
	## Everything discovered, sorted so a save file does not churn between writes.
	var ids: Array = _seen.keys()
	ids.sort()
	return ids


static func restore(ids: Array) -> void:
	_seen.clear()
	for id in ids:
		_seen[str(id)] = true


static func clear() -> void:
	_seen.clear()