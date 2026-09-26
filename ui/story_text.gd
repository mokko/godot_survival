extends RefCounted
## The intro's words, one screen per entry — the story screen shows these in order
## (`ui/story.gd`), typing each out and moving on when the player clicks or presses ESC.
##
## The words live here and not in `ui/story.gd` or in the scene, the way
## `ui/pedia_data.gd` keeps the notebook's words: `story.md` is the narrative bible this
## intro is lifted from, and this file is the only place the game's own wording sits.
## **Add a page by adding an entry** — nothing else has to change.
##
## A page is `{"title": …, "body": …}`: the title is shown the way a typist set a heading
## (`ui/story.gd`'s `display_title()`), and the body is the prose.
##
## Writing rules, because the typewriter is unforgiving:
##  - **titles are short.** There was no bold on a typewriter, so a heading is set in
##    CAPITALS *and letterspaced*, which roughly triples its length — too long and it
##    re-wraps and the heading falls apart. TITLE_MAX is what still fits on one line.
##  - a blank line is a paragraph break, and the machine takes a carriage-return beat
##    there. The blank line between title and body is what gives a heading its beat;
##  - a single newline is the end of a line, so keep body lines under MAX_LINE characters
##    or they re-wrap in the middle of a sentence in the monospace face;
##  - a page ends with a newline, and the text is typed from a fixed left margin.

## The measure: the monospace block holds this many characters at `font_size = 20` in its
## 900 px width — **measured**, not estimated: the face advances 12.00 px a character, so
## 900 / 12 = 75. Longer lines re-wrap. (It was written down as 71 first, guessed from the
## typewriter rule of thumb, and the prose already runs to 73 — which renders fine, so the
## number was wrong rather than the words. `tests/test_story.gd` now also checks the real
## thing: that the rendered label has no more lines than the text has.)
const MAX_LINE := 75
## A letterspaced CAPITAL title takes about three times its letters, so this is the longest
## title that still fits the measure on one line.
const TITLE_MAX := 23

const PAGES := [
	{
		"title": "Displaced",
		"body": """You are a mind without a body.

Not dead — displaced. Somewhere behind you is a life you can no longer
reach, and a name you cannot remember.
""",
	},
	{
		"title": "The drone",
		"body": """What you have is a drone: small, patient. Through it you see and hear and
touch this place — all of it secondhand, remote.
""",
	},
	{
		"title": "The shore",
		"body": """You wake on a shore that is not Japan, and is shaped like Japan.
Someone built this. Someone put you here.
""",
	},
	{
		"title": "Why",
		"body": """You do not yet know why.
""",
	},
]