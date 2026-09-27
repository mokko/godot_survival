extends LineEdit
## The field a species is named in, built in code by the Pedia page (ui/pedia.gd).
##
## It exists for one reason: **ESC already has an owner.** `ui/pause_menu.gd` is the only
## listener for the key, and while a screen is open the key walks that screen back — with
## the book open, one page up or out of the Pedia altogether. That cannot be allowed to
## happen to someone halfway through typing a name, where ESC plainly means "forget this
## edit". So the field swallows the key, puts the stored name back and releases focus, and
## the menu never sees it. Focus is released on purpose: it makes ESC a ladder rather than
## a dead end — the first press abandons the edit, the second one walks back out of the
## book, which is what a player who changed their mind expects.
##
## `PROCESS_MODE_ALWAYS` because the book is normally open over a **paused** tree, where
## its parent (the pause menu) runs in `PROCESS_MODE_WHEN_PAUSED`. Inheriting that would
## leave the field deaf whenever the Pedia is opened without pausing — which is exactly
## what a test does — and a text field that only accepts typing while the game is paused
## is a trap for the next caller.

## Emitted when an edit is abandoned, after the stored name is back in the field. The page
## uses it to put its own heading back in step.
signal edit_cancelled

var _stored := ""   ## what the registry holds, to put back when an edit is abandoned


func remember(name_text: String) -> void:
	## Called before the page is shown, so ESC knows what to restore. An empty string is
	## honest: it means this species has no player name and falls back to the data table.
	_stored = name_text
	text = name_text


func stored() -> String:
	## What ESC would put back — for tests and for anything reporting state.
	return _stored


func _gui_input(event: InputEvent) -> void:
	## Nothing is forwarded to the parent: a native class' own handling (typing, the
	## caret, the selection) still runs — this callback is *in addition* to it, which is
	## the whole reason a LineEdit can be filtered like this. Only the key the field must
	## not let past is taken.
	if event.is_action_pressed("ui_cancel"):
		# Accept first: the whole point is that the pause menu never sees this key.
		accept_event()
		text = _stored
		release_focus()
		edit_cancelled.emit()
