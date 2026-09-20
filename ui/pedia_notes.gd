extends RefCounted
## What the drone has actually drawn into its notebook.
##
## A static registry, like ui/options.gd: the study code (player/study.gd) and the
## player's own discovery pass write to it, the Pedia reads it, and the player saves
## and restores the whole set with the rest of its state. Keys are
## "chapter/subchapter", so nothing here has to know the shape of the book.
##
## A fresh run clears it — the notebook starts empty — while dying does not: the
## notebook is a keepsake, and the notes are the drone's own record.

static var _drawn: Dictionary = {}


static func unlock(chapter: String, id: String) -> bool:
	## Records one entry. True when it was new, so a caller can tell "just drawn"
	## from "already had that" (the study code plays a different cue for each).
	var key := _key(chapter, id)
	if _drawn.has(key):
		return false
	_drawn[key] = true
	return true


static func has(chapter: String, id: String) -> bool:
	return _drawn.has(_key(chapter, id))


static func drawn() -> Array:
	## Everything drawn, sorted so a save file does not churn between writes.
	var keys: Array = _drawn.keys()
	keys.sort()
	return keys


static func restore(keys: Array) -> void:
	_drawn.clear()
	for key in keys:
		_drawn[str(key)] = true


static func clear() -> void:
	_drawn.clear()


static func _key(chapter: String, id: String) -> String:
	return "%s/%s" % [chapter, id]