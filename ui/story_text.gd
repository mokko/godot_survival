extends RefCounted
## The intro's words, one screen per entry — the story screen shows these in order
## (`ui/story.gd`), typing each out and moving on when the player clicks or presses ESC.
##
## The words live here and not in `ui/story.gd` or in the scene, the way
## `ui/pedia_data.gd` keeps the notebook's words: `story.md` is the narrative bible this
## intro is lifted from, and this file is the only place the game's own wording sits.
## **Add a page by adding an entry** — nothing else has to change.
##
## Writing rules, because the typewriter is unforgiving:
##  - a blank line is a paragraph break, and the machine takes a carriage-return beat
##    there;
##  - a single newline is the end of a line, so keep lines under ~71 characters or they
##    re-wrap in the middle of a sentence in the monospace face;
##  - the text is typed from a fixed left margin, so a page reads as a page.

const PAGES := [
	"""You are a mind without a body.

Not dead — displaced. Somewhere behind you is a life you can no longer
reach, and a name you cannot remember.
""",
	"""What you have is a drone: small, patient. Through it you see and hear and
touch this place — all of it secondhand, remote.
""",
	"""You wake on a shore that is not Japan, and is shaped like Japan.
Someone built this. Someone put you here.
""",
	"""You do not yet know why.
""",
]