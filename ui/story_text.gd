extends RefCounted
## The story's words — the screen itself is `ui/story.gd`, which types these out.
##
## Two kinds of page live here, and they are shown at different times:
##
##  - `PAGES` is the **intro**: what a new run opens on (splash Start → `ui/story.tscn`
##    → the world). It is **one screen**, deliberately — the run's opening statement
##    rather than a lecture, because everything after it is told by the world and by the
##    player's own arrival at things.
##  - `MILESTONES` is one screen per **thing that happens mid-run**, keyed by an id the
##    world asks for when it happens: `world/explorer_kit.gd` plays `explorer_kit` the
##    moment the satchel is emptied, `items/katana_pickup.gd` plays `katana` when a
##    sword is picked up, and `world/bench.gd` plays `bench` at the first bench the
##    player works at, before the Frame screen opens. `ui/story.gd:play_milestone()` puts
##    one up over the paused world and closes it back into the run — see `ui/story.md`.
##
## The words live here and not in `ui/story.gd` or in the scene, the way
## `ui/pedia_data.gd` keeps the notebook's words: `story.md` is the narrative bible this
## intro is lifted from, and this file is the only place the game's own wording sits.
## **Add a screen by adding an entry** — to `PAGES` for the intro, to `MILESTONES` for a
## milestone. Nothing else has to change.
##
## A page is `{"title": …, "body": …}`: the title is shown the way a typist set a heading
## (`ui/story.gd`'s `display_title()`), and the body is the prose.
##
## Writing rules, because the typewriter is unforgiving. The numbers are spelled out here so
## they are readable at the point of writing; the constants below are what the code and the
## test actually enforce, so they win if the two ever disagree — and both move together if the
## block width or the font size changes.
##  - **titles: 23 letters or fewer** (TITLE_MAX), and written in **sentence case**: the
##    catalogue holds the words, not the display form, and `display_title()` is what makes a
##    heading CAPITALS. There was no bold on a typewriter, so a heading is set in capitals
##    *and letterspaced*, which roughly triples it — a title longer than that sets past 75
##    characters letterspaced, re-wraps, and the heading falls apart.
##  - **body lines: 75 characters or fewer** (MAX_LINE). A single newline is the end of a line,
##    so a longer one re-wraps in the middle of a sentence in the monospace face;
##  - a blank line is a paragraph break, and the machine takes a carriage-return beat
##    there. The blank line between title and body is what gives a heading its beat;
##  - a page ends with a newline, and the text is typed from a fixed left margin — a line is
##    indented by the block, never by spaces or tabs in the words themselves.

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

## The intro: **one screen**, and the only page a run is shown before it starts — the bare
## drone that wakes on the cape, and the question it cannot answer.
const PAGES := [
	{
		"title": "The beginning",
		"body": """You wake up. Something is wrong. Where are you? Your eyes don't open.

Then you discover a different way to see, to hear. This is different.
It's like coming from a camera. What is this? You appear to be inside a
robot. You can move. Let's see what you can find out.

Another thought. How did you get here? Who are you? So far you thought,
you knew who you were, but now you realize you don't remember your name.
""",
	},
]

## Mid-run screens, one per milestone, keyed by the id the world asks for. Each is a single
## screen shown over the paused world and closed straight back into the run
## (`ui/story.gd:play_milestone`), so a milestone screen can never cost the player the run
## it is narrating. An id that is not in here plays nothing at all.
##
## A screen is played by whoever **causes** it, which is why the trigger lives in the world
## node and not in a list here: the satchel knows it was opened, and the page about finding a
## weapon is about the finding. `explorer_kit` is therefore played once a run — the satchel
## opens once — while `katana` is played by **any** katana picked up, on purpose: the page
## is about recognising the sword, not about that particular blade. `bench` is played by the
## first bench the player works at (`world/bench.gd`), which opens the Frame screen when the
## page closes: the page is that screen's preface.
##
## A page is asked for on the **event** and never from saved state, so loading a run does not
## replay what the player already heard.
const MILESTONES := {
	"explorer_kit": {
		"title": "The Explorer's Kit",
		"body": """You found a leather satchel with several items in it. A book with a
leather binding. It's empty. No text. It's a notebook. Like people
used hundreds of years ago. A pen to write in it. There is also a
pair of binoculars through which you can study far away things and
a magnifying glass for a close inspection.

Apparently someone wants you to study your surroundings like the
explorers on Earth a long time ago.
""",
	},
	"katana": {
		"title": "The katana",
		"body": """You found a weapon. It's a blade with a handle. Not quite straight,
gently curved. Someone put this here. They can be lucky that you
can recognize this for what it is: a Japanese sword used by the
Samurai. How come you know that? Many people know katanas, but who
knows that they have been made in this form since the 14th century?
You must be someone with knowledge of Japanese history.
""",
	},
	"bench": {
		"title": "The Workbench",
		"body": """You found the workbench where you can edit your robot.

You may find new parts for your robot and you can implement
them here.
""",
	},
}


static func milestone(id: String) -> Dictionary:
	## The page behind a milestone id. An empty record means "nothing is written for
	## that", which the caller reads as *no screen* rather than as a blank one — a
	## milestone is only ever played when there are words to play.
	var record = MILESTONES.get(id, {})
	return record if record is Dictionary else {}
