# The story screen: the intro, typed out

The screen between the splash menu and the game, and the only place the intro is told. It is
a **mechanical typewriter**: a monospace typewriter face, a clack per character, and a
carriage return with its bell at every line break. `ui/story.gd` is the behaviour,
`ui/story.tscn` the layout, `ui/story_text.gd` holds the words, and
`sounds/type_key.wav` and `sounds/type_return.wav` are the two noises.

## The pages

The intro is a **stack of screens, not one**: `ui/story_text.gd` holds `PAGES`, one entry per
screen, and `ui/story.gd` types them in order. **Add a page by adding an entry to `PAGES`** —
nothing else has to change, because the count, the paging and the last-page prompt all read
from that list.

One press moves exactly one step — the next page, or the game once the last page is done. It
is deliberately **one press, one thing**: no skip-then-confirm, and no "press to finish typing
this page" state in between either, so a press can never do something the player did not
predict. What the finished page's hint says tells them which step they are about to take
(`PROMPT_NEXT` / `PROMPT_BEGIN`).

Every page starts clean: the reveal, the carriage-return beat, the clack clock and the cursor
all reset in `_begin_page()`, and the previous page's bell is cut off rather than ringing into
the new page.

## The heading

Every page opens with its **title**, set the way a typist set a heading: **CAPITALS, and
letterspaced** (`D I S P L A C E D`), on its own line, with a blank line under it.

Why that and not something else: a mechanical typewriter has **no bold and no italic** — one
ribbon colour, one weight of type — so the emphasis a typist actually had was capitals,
spacing, and rules made of hyphens. Overstriking a character twice for a heavier look is the
other historical trick, and it cannot be faked in a Label: a doubled letter just reads as a
typo.

`display_title()` in `ui/story.gd` does the letterspacing, so **the catalogue holds plain
words** (`"Displaced"`, never `"D I S P L A C E D"`) — the display form is not writing, and it
is not typed into the data. The heading is the first line of the typed text, which is what
gives it clacks of its own and a carriage-return beat under it (the blank line after it).

Two limits, both enforced by `tests/test_story.gd`:

- **Titles are short** (`TITLE_MAX`, 23 letters): letterspacing roughly triples the length, so
  a long title re-wraps and the heading falls apart.
- The *displayed* heading has to fit the measure like any other line (`MAX_LINE`, 75).

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

ESC or a left click enters the game at any point, including mid-typing — one press, no
skip-then-confirm. The typing stops with the screen, so no clacks play under the loading
wait.

**`mouse_filter` is load-bearing.** The click is handled in `_unhandled_input`, so every
node in `story.tscn` must keep `MOUSE_FILTER_IGNORE`: a Control on the default `STOP` grabs
the click during GUI hit-testing, marks it handled, and the event never reaches the script
— which is why only ESC used to work. A button added here later wants `STOP` **and** a
connection; do not put `STOP` back on the full-rect `Background` or `Center`, which would
swallow every click.

`tests/test_story.gd` steps the typing with a fixed delta to pin the line-break clamp and
the beat, checks the two sound files actually resolved (a failed load is a null stream and
plays silence), and measures the reveal **without the cursor** — with it, an empty reveal
still reads as "something on screen" and the test could not tell typing from a stall.
`test_story_click.gd` and `test_story_skip.gd` cover the skip through real input.