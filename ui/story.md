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

- **The text block has to stay wide enough for the longest line** (~71 characters): the
  prose is hand-wrapped with hard newlines, so a narrower block re-wraps it mid-sentence
  and the composition falls apart. The block is 900 px at `font_size = 20`; check
  `label.get_line_count()` still equals the text's own line count if you change either.
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