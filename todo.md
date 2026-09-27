# TODO — Nakamoto's Paradigm

The three wants from the first iteration, with where they actually stand. Done items are
kept until they are pruned.

- [x] **Improve UI** — pause menu, the Pedia notebook, the energy and study meters, procedural
  icons and plates (`ui/`, `ui/vector_art.gd`).
- [ ] **Improve graphics** — landed so far: MSAA 2×, SSAO, ground detail maps, ground clutter,
  procedural boats. The rest of the list is in `graphics_tips.md`.
- [x] **Sounds** — synthesized effects in `sounds/` (`tools/make_sounds.py`).
- [ ] **Magnify through the instruments** — right now `ui/instrument_view.gd` only draws the
  mask (two tubes / one loupe, dimmed outside, rim, reticle); `camera.fov` is untouched, so
  the world inside the circles renders at the same FOV as everything else. Plan:
  - Save the pre-instrument FOV, then lerp `camera.fov` toward a per-tool target while a tool
    is held, and restore the saved value on unequip — never write `FOV_DEFAULT` back, the
    scroll wheel owns the base zoom (50–150, step 5, `player/player.gd:43-46`).
  - Binoculars (distant observing, 45 m): mild pull, ~35. Magnifying glass (close work, 6 m,
    the loupe): stronger, ~25–28 — a loupe is the stronger glass of the two.
  - Return the held tool's FOV target from one place in `player/study.gd::_update_view()`
    (it already knows which tool is held) so the mask and the zoom can't disagree.
  - Keep the scroll wheel live while a tool is up: the restored value is whatever the player
    had, so a zoom made with the glasses up is theirs to keep or lose on unequip.
  - Design notes (agreed before implementing):
    - The FOV pull magnifies the whole camera, not just what is under the lens. That is
      deliberate: everything outside the circle is dimmed by the mask, so the trick is
      invisible. State the reason in a comment so nobody "fixes" it into a second viewport —
      a `Viewport` rendering the reticle region into the circle is true lens magnification and
      is the better long-term end state for the loupe (it also works on a subject the mask
      would clip), but it costs viewport, texture and alignment work and breaks the single
      draw path in `instrument_view.gd`. FOV route first, viewport later as its own item.
    - Zoom in makes the 8-second hold harder: the same mouse movement swings the view across
      more of the target, so keeping a wiggling specimen inside the loupe gets twitchy. Either
      keep the loupe pull modest (~28–30, not 25) or scale mouse sensitivity down while a tool
      is held. This is what will generate the complaint, not the visuals.
    - Engage the zoom only when a *valid* subject is under the reticle, not the moment the tool
      comes up. The pull then reads as the glass focusing instead of the player fumbling a
      zoom, and it also avoids the "holding a tool while running looks drunk" problem.
  - Check the tests: `tests/test_study.gd` asserts on `instrument_view` and the study meter,
    and `tools/capture_views.gd` sets its own `cam.fov` for screenshots. Study range and the
    aim ray are distance/direction based, so they should be unaffected — verify, don't assume.
- [ ] **Name the things you discover** — the player gets to name a species. Every plant and
  animal already has a name from the data table (`ui/pedia_data.gd`); this feature gives the
  player's own name for it, chosen once when it is first drawn into the notebook and editable
  afterwards. The default name stays the fallback, so ignoring the feature costs nothing.
  - **When**: the moment a species is first drawn (the `entry_drawn` signal in
    `player/study.gd`), *and* later, from its Pedia page. Do **not** force a modal text field
    on discovery mid-play: the player is standing in front of an animal with the mouse
    captured and eight seconds of observation just paid off. The default name is written
    immediately and the drone says so ("Drawn: Grazer — press N to name it", a short window,
    not a blocker); declining or missing it leaves the species namable from the notebook
    forever after. Losing the chance to name something is unacceptable, so the Pedia page is
    the guaranteed path and the discovery prompt is only a convenience.
  - **Where**: species only — animals and plants. Items, islands and equipment keep their
    data-table names. Gate it in one place (`Notes.can_name(chapter)`, true for `animals` and
    `plants`) so the Pedia, the prompt and any future caller cannot disagree about what is
    nameable.
  - **How it lives**: `ui/pedia_notes.gd` is the notebook registry and today holds nothing but
    `key -> true`; a name is the first *value* the notebook has ever stored, so the registry
    grows a parallel `_names: Dictionary` keyed the same way (`"chapter/id"`), with its own
    `set_name`/`name_of`/`clear`/restore siblings. Identity stays `chapter/id` — never the
    name — so two species may share a name without anything breaking, and no uniqueness rule
    should be invented.
  - **Display**: one resolver, `Notes.display_name(chapter, id)`, falling back to the data
    table's `name` when the player has not renamed anything. Everything that shows a species
    name goes through it: the Pedia data page title (`data_name`), the subchapter buttons in
    the grid, and the study meter's line (`player/study.gd`: `"Drawn: %s"` / `"Autopsy: %s"`).
    Never write the player's name back into `pedia_data.gd` — the records are the shared,
    read-only book, and the species' own prose ("Real-world anchor", the descriptive text)
    must keep saying what the thing *is* regardless of what it has been called.
  - **The name field**: reuse the pattern already proven in `ui/saves.gd` — a `LineEdit` built
    in code with an accessor (`saves.gd::slot_field`) so tests and callers never guess at a
    child index, and repaint-in-place rather than rebuilding the list, so a half-typed name is
    never thrown away. Two things that screen does not have to deal with and this one does:
    the Pedia runs with the tree **paused** (opened from the pause menu), so the field needs
    `process_mode = PROCESS_MODE_ALWAYS` to accept keystrokes at all; and the pause menu owns
    ESC, so ESC while the field has focus must **cancel the edit and keep its focus**, not
    close the book — the single-owner rule still has to hold, and the owner has to be told the
    difference between "typing" and "browsing".
  - **Editing rules**: trim surrounding whitespace; cap the length (24 characters reads well in
    the title slot and keeps the page from breaking); reject control characters and newlines;
    an empty field means *remove the name* and fall back to the data-table default, which is
    also how a mistaken rename gets undone. No profanity filter, no uniqueness check — it is
    the player's own notebook and a single-player island.
  - **Saving**: `world/savegame.gd` stores the notebook as the sorted key array under `notes`
    (`Notes.drawn()` / `Notes.restore(keys)`). Keep that key exactly as it is — `SAVE_KEYS`
    uses it to tell this savegame apart from a foreign file of the same name — and add the
    names as a sibling entry (e.g. `names`, `"chapter/id" -> the player's name`), restored
    after the keys, so an existing save loads unchanged with no names and every species simply
    shows its data-table name. Sorted on write like everything else, so a save file does not
    churn between writes.
  - **Lifetime**: names belong to the notebook, so a fresh run clears them along with the
    drawings (`Notes.clear()`), while dying keeps them — the notebook is a keepsake. That is
    the consistent choice and it is cheap. The alternative (names in a profile store beside
    `ui/options.gd` so they survive a new run) is a real option but a different feature:
    it makes a name a setting rather than a note, and it should be a deliberate decision, not
    a side effect of where the code happened to land. Decide before implementing.
  - **Tests**: add `tests/test_naming.gd` — a fresh registry falls back to the data-table name;
    naming a species shows everywhere it is displayed; renaming replaces it; clearing reverts;
    an old save without the names key restores with defaults and does not error; a new run
    clears names. Existing assertions that will need attention rather than a rescue:
    `tests/test_pedia.gd:137` compares `pedia.data_name.text` against the record's name
    directly, so it should compare against the display resolver once the feature lands. Run
    with `flock /tmp/survivalm-godot.lock snap run godot-4 --headless --script res://tests/test_naming.gd`,
    or the whole suite via `tests/run_all.sh`.