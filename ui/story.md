# The story screen: the intro and the milestones, typed out

The screen that opens a new run between the splash menu and the game — and, in the world, the
screen a **milestone** puts up. It is a **mechanical typewriter**: a monospace typewriter face,
a clack per character, and a carriage return with its bell at every line break. `ui/story.gd`
is the behaviour, `ui/story.tscn` the layout, `ui/story_text.gd` holds the words, and
`sounds/type_key.wav` and `sounds/type_return.wav` are the two noises.

## The pages

`ui/story_text.gd` holds **two catalogues**, and they are shown at different times:

- **`PAGES` is the intro** — what a new run opens on, and it is **one screen**, deliberately.
  The run's opening statement, not a lecture: everything after it is told by the world and by
  the player's own arrival at things.
- **`MILESTONES` is one screen per thing that happens mid-run**, keyed by an id the world asks
  for when it happens (`world/explorer_kit.gd` plays `explorer_kit`; `items/katana_pickup.gd`
  plays `katana`). **Add a screen by adding an entry** to whichever catalogue it belongs in —
  the count, the paging and the prompt all read from the list.

One press moves exactly one step — the next page, or whatever comes after the last one. It is
deliberately **one press, one thing**: no skip-then-confirm, and no "press to finish typing this
page" state in between either, so a press can never do something the player did not predict.
What the finished page's hint says tells them which step they are about to take (`PROMPT_NEXT` /
`PROMPT_BEGIN`, and `PROMPT_RESUME` for a milestone, where the next step is *back to the game*).

Every page starts clean: the reveal, the carriage-return beat, the clack clock and the cursor
all reset in `_begin_page()`, and the previous page's bell is cut off rather than ringing into
the new page.

## The two kinds of screen

`enters_game` on the screen's root is the whole difference, and it is set in the scene that
instances it:

- **The intro** — `ui/story.tscn` *as* the current scene, entered by `ui/splash.gd` on a fresh
  run only (Load Game skips it), `enters_game = true`: the last press loads `world/main.tscn`.
- **A milestone** — the same scene instanced in `world/main.tscn` as `HUD/StoryScreen`, with
  `enters_game = false`. The world asks for a page with `play_milestone(id)`, and the last press
  closes the screen and hands the run back.

`enters_game = false` also makes the screen **hide itself and stop processing** in `_ready`, so
it sits in the world invisible until something asks for a page — one flag decides all of that,
rather than the scene file half-declaring it.

Three things about the milestone case are load-bearing:

- **Nothing is ever loaded over the run.** `_finish_milestone()` unpauses, re-captures the
  mouse, hides the screen and emits `finished` — it must never enter the game, because the run
  the page is narrating is the one the player is standing in.
- **The world is paused while it is up** (a day cycle turning, or an animal charging, behind a
  text screen would both be wrong), so the screen sets `PROCESS_MODE_ALWAYS` to keep typing and
  to keep its own key. While a milestone is up it is the only thing listening: the player is
  paused with everything else, and the pause menu is invisible, so its ESC handler does nothing.
- **It is not the ESC owner when it is not up.** The pause menu owns that key in the world
  (`ui/pause_menu.gd`), and it only listens while it is visible — which is why the milestone
  screen does not have to hand the key back to anyone.

A crate that a save remembers as already opened stands open and **silent**: the page is played
by the *event* of opening it, not by the crate's state, so loading a run does not replay it.

## The heading

Every page opens with its **title**, set the way a typist set a heading: **CAPITALS, and
letterspaced** (`T H E   B E G I N N I N G`), on its own line, with a blank line under it.

Why that and not something else: a mechanical typewriter has **no bold and no italic** — one
ribbon colour, one weight of type — so the emphasis a typist actually had was capitals,
spacing, and rules made of hyphens. Overstriking a character twice for a heavier look is the
other historical trick, and it cannot be faked in a Label: a doubled letter just reads as a
typo.

`display_title()` in `ui/story.gd` does the letterspacing, so **the catalogue holds plain
words** (`"The beginning"`, never `"T H E   B E G I N N I N G"`) — the display form is not
writing, and it is not typed into the data. The heading is the first line of the typed text,
which is what gives it clacks of its own and a carriage-return beat under it (the blank line
after it).

Three limits, all enforced by `tests/test_story.gd`:

- **Titles are short** (`TITLE_MAX`, 23 letters): letterspacing roughly triples the length, so
  a long title re-wraps and the heading falls apart. `"CHAPTER 2: EXPLORER'S KIT"` is 25 and so
  is over the line; `"The Explorer's Kit"` is 18.
- **Titles are sentence case in the data**: capitals in the catalogue mean somebody typed the
  rendering into the words.
- The *displayed* heading has to fit the measure like any other line (`MAX_LINE`, 75).

Prose pasted in from anywhere is worth a second look: a leading **tab** or a run of trailing
spaces is invisible in a diff, types onto the screen as characters of its own, and breaks the
"every line starts at the same edge" rule above. The test fails on both.

A **centred** heading is what a typist did with a page title — counting characters and spacing
over from the margin — and it is available if wanted: pad the line with leading spaces. The
cost is that the padding is typed like everything else, so a centred heading opens with about
a second of the carriage travelling with nothing appearing on screen.

## The typing

Characters come out at `CHARS_PER_SEC` (28), and **every sound is fired from the characters
that were actually revealed** in that frame rather than from a clock of its own — so the
clacks cannot drift from the text however the frame rate wanders.

- **A clack per character**, but not faster than `KEY_MIN_GAP` (0.055 s): at 28 cps a clack
  on every single character is one continuous buzz rather than typing, so the shortest gap
  wins and the characters in between come out silently. Each one gets a little pitch
  scatter, or a line of them sounds like a machine gun.
- **A line break is a beat, not a character.** The reveal stops *at* the break (the
  character index is clamped), `type_return.wav` plays — the carriage sliding back, then
  the little bell — and typing holds for `RETURN_PAUSE` (0.26 s). Without that pause the
  newline is ordinary and the bell rings somewhere inside the next sentence.
- **A cursor** (`▌`) sits after the last revealed character while the machine is still
  typing and is dropped when the intro finishes, so the finished screen is the finished
  text.

Tuning lives in the constants at the top of `ui/story.gd`: the pacing, the clack gap, the
beat, the cursor, and the two volumes (the clacks are much quieter than the return, because
they repeat ~18 times a second and the return does not).

## The face

A `SystemFont` — the OS picks the first of `Nimbus Mono PS`, `Courier New`, `Courier`,
`DejaVu Sans Mono`, `Liberation Mono`, `Noto Sans Mono`, `monospace` that it has. That
gives a real typewriter face with no font file vendored into the repo, and it degrades to
whatever monospace the machine has rather than to a missing-glyph box.

Two things to know if you touch the layout:

- **The text block has to stay wide enough for the longest line** (`MAX_LINE`, 75
  characters — measured: the face advances 12.00 px a character and the block is 900 px at
  `font_size = 20`): the prose is hand-wrapped with hard newlines, so a narrower block
  re-wraps it mid-sentence and the composition falls apart. If you change the block or the
  size, `tests/test_story.gd` measures the rendered label against the text and says so.
- **The text starts at a fixed left margin and runs ragged right**, like a typed page: both
  labels are `horizontal_alignment = 0`, and the 900 px block is centred on screen, so the
  column sits in the middle but every line begins at the same edge. Centred text reads as a
  terminal, which is not what a typewriter does.

## Skipping

ESC or a left click moves the screen on at any point, including mid-typing — one press, no
skip-then-confirm. On the intro that means entering the game; on a milestone it means closing
the screen and carrying on. The typing stops with the screen, so no clacks play under the
loading wait.

**`mouse_filter` is load-bearing.** The click is handled in `_unhandled_input`, so every
node in `story.tscn` must keep `MOUSE_FILTER_IGNORE`: a Control on the default `STOP` grabs
the click during GUI hit-testing, marks it handled, and the event never reaches the script
— which is why only ESC used to work. A button added here later wants `STOP` **and** a
connection; do not put `STOP` back on the full-rect `Background` or `Center`, which would
swallow every click.

`tests/test_story.gd` steps the typing with a fixed delta to pin the line-break clamp and
the beat, checks the two sound files actually resolved (a failed load is a null stream and
plays silence), and measures the reveal **without the cursor** — with it, an empty reveal
still reads as "something on screen" and the test could not tell typing from a stall. It holds
both catalogues to the same page rules, drives a milestone screen through play → pause → close
and checks that closing it did **not** load a scene. `test_story_click.gd` and
`test_story_skip.gd` cover the skip through real input, and `tests/test_explorer_kit.gd` checks
that opening the crate is what puts a page up — through a real click, because that is the path
that decides whether anything in the HUD eats it first.
