extends RefCounted
## What the drone has actually drawn into its notebook, and what it calls it.
##
## A static registry, like ui/options.gd: the study code (player/study.gd) and the
## player's own discovery pass write to it, the Pedia reads it, and the player saves
## and restores the whole set with the rest of its state. Keys are
## "chapter/subchapter", so nothing here has to know the shape of the book.
##
## Two things live here, and they are different in kind:
##  - **the drawings** (`_drawn`) — which entries the notebook holds, `key -> true` and
##    nothing else. What a species *is* lives in ui/pedia_data.gd, the shared, read-only
##    book;
##  - **the names** (`_names`) — what *this* drone calls it, `key -> String`. A name is
##    the first value the notebook has ever stored, which is why it needs its own calls
##    rather than a second registry.
##
## A player's name never goes back into ui/pedia_data.gd: the records keep saying what
## the thing *is* no matter what it has been called. Identity is always the key and never
## the name, so two species may share a name without anything breaking, and there is no
## uniqueness rule to invent.
##
## A fresh run clears both — the notebook starts empty — while dying does not: the
## notebook is a keepsake, and the notes are the drone's own record.

const PediaData := preload("res://ui/pedia_data.gd")

## The chapters whose entries the player may name: species, only. Equipment, islands and
## the rest keep their data-table names. Gating it in one place means the Pedia page, the
## discovery prompt and anything added later cannot disagree about what is nameable.
const NAMEABLE_CHAPTERS := ["animals", "plants"]

## Long enough for a proper name, short enough to sit in the title slot of a Pedia page
## (a single line, ui/pedia.tscn) and on a list button in the grid.
const NAME_MAX := 24

static var _drawn: Dictionary = {}
static var _names: Dictionary = {}


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


static func count_drawn(chapter: String) -> int:
	## How many entries of one chapter the notebook holds. One reader so far — the study
	## code's survey beat (`player/study.gd`), which asks whether enough of this place has
	## been written down to say anything about it — but the count is a property of the
	## notebook, not of that beat, so it lives here beside the keys it counts.
	var prefix := chapter + "/"
	var total := 0
	for key in _drawn:
		if str(key).begins_with(prefix):
			total += 1
	return total


static func restore(keys: Array) -> void:
	_drawn.clear()
	for key in keys:
		_drawn[str(key)] = true


static func clear() -> void:
	## Both halves: a new run starts with an empty notebook, names included. Names are
	## notes, not settings — if they were meant to outlive a run they would live beside
	## ui/options.gd, and that would be a deliberate choice and not this one.
	_drawn.clear()
	_names.clear()


static func can_name(chapter: String) -> bool:
	## Species only, decided here and nowhere else.
	return NAMEABLE_CHAPTERS.has(chapter)


static func give_name(chapter: String, id: String, chosen: String) -> String:
	## Records what the player calls this entry, and returns what was recorded: the
	## sanitised name, or "" for a field left empty — which *removes* the name, falls back
	## to the data table, and is how a mistaken rename gets undone.
	##
	## Sanitising lives here rather than in the text field so every caller behaves the same
	## way. Anything past NAME_MAX is dropped rather than refused: a field that quietly
	## loses the end of a long paste is less annoying than one that refuses a name for being
	## three characters too long. An entry that cannot be named keeps whatever it had.
	##
	## Not called `set_name`: the engine already has one, and a call under that name
	## resolves to the built-in instead of to this function — `Invalid call ... Expected 1
	## argument(s)`, which is a confusing way to spend an afternoon. Names here are given,
	## not set.
	if not can_name(chapter):
		return name_of(chapter, id)
	var clean := _sanitise(chosen)
	var key := _key(chapter, id)
	if clean == "":
		_names.erase(key)
	else:
		_names[key] = clean
	return clean


static func name_of(chapter: String, id: String) -> String:
	## The player's own name, or "" when they have not given one.
	return str(_names.get(_key(chapter, id), ""))


static func display_name(chapter: String, id: String) -> String:
	## The one resolver. Everything that shows a name asks this — the Pedia's list buttons,
	## a data page's title, the study meter's line — so a renamed species reads the same
	## everywhere. The data table's name is the fallback, so a player who ignores the whole
	## feature sees exactly what they saw before it existed.
	var chosen := name_of(chapter, id)
	if chosen != "":
		return chosen
	return str(PediaData.subchapter(chapter, id).get("name", ""))


static func names() -> Dictionary:
	## Every name, in sorted key order so a save file does not churn between writes.
	var out: Dictionary = {}
	var keys: Array = _names.keys()
	keys.sort()
	for key in keys:
		out[str(key)] = str(_names[key])
	return out


static func restore_names(saved: Variant) -> void:
	## Names come back with the drawings (player/player.gd, save key `names`). A save
	## written before this feature existed has no such key, so this has to accept whatever
	## arrives — an old run simply shows data-table names until something is renamed.
	_names.clear()
	if not saved is Dictionary:
		return
	var source: Dictionary = saved
	for key in source:
		var k := str(key)
		# A save is not trusted to be well-formed: the same gate that refuses to *store*
		# a name on a non-nameable entry refuses to *load* one, so a hand-edited file (or
		# one written by a build with different chapters) cannot smuggle one in.
		if not can_name(k.get_slice("/", 0)):
			continue
		var clean := _sanitise(str(source[key]))
		if clean != "":
			_names[k] = clean


static func _sanitise(chosen: String) -> String:
	## Surrounding whitespace goes, control characters and newlines go, the rest is capped.
	var out := ""
	var text := chosen.strip_edges()
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32 or code == 127:
			continue
		out += text[i]
		if out.length() >= NAME_MAX:
			break
	return out


static func _key(chapter: String, id: String) -> String:
	return "%s/%s" % [chapter, id]
