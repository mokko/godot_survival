# TODO — Nakamoto's Paradigm

The three wants from the first iteration, with where they actually stand. Done items are
kept until they are pruned.

- [x] **Improve UI** — pause menu, the Pedia notebook, the energy and study meters, procedural
  icons and plates (`ui/`, `ui/vector_art.gd`).
- [ ] **Improve graphics** — landed so far: MSAA 2×, SSAO, ground detail maps, ground clutter,
  procedural boats. The rest of the list is in `graphics_tips.md`.
- [x] **Sounds** — synthesized effects in `sounds/` (`tools/make_sounds.py`).
- [x] **Magnify through the instruments** — done. Half of what a glass does is the mask
  (`ui/instrument_view.gd`, unchanged), half is the camera's field of view, pulled in by
  `player/player.gd` and asked for by `player/study.gd::_pull_glass()`. What landed, and
  where it differs from the plan above:
  - **Targets**: binoculars **35**, loupe **30** (the plan said 25–28). 30 keeps the loupe
    the stronger glass of the two without making the 8-second hold a fight; the
    twitchiness note below is the reason, and scaling mouse sensitivity while a tool is
    held is still the lever if 30 turns out to be too strong in the hand.
  - The wheel owns a named `base_fov` instead of a save-and-restore pair: same behaviour
    ("a zoom made with the glasses up is theirs to keep"), with no saved value to desync.
    `_set_base_fov()` clamps to 50–150 and applies immediately when nothing is raised; the
    instrument pull deliberately goes **below** `FOV_MIN`, because it is not the wheel.
  - `move_toward` at `FOV_PULL_SPEED = 80` degrees per second in `_physics_process`, not a
    lerp: an ease that arrives and stops, so a half-second pull and an exact assertion.
  - "Only with a valid subject under the reticle" was first realised as **only while a
    session is running** (`is_studying()`) — no extra raycast per frame, and a carried
    tool zooms nothing while the drone runs about. **Changed on Maurice's call (27 Sep):
    a raised glass magnifies, session or no session.** Both instruments read as broken in
    the hand: you cannot aim the binoculars at an animal you cannot see, and with the pull
    waiting on a click, raising either one did nothing at all. `_pull_glass()` now asks
    for the tool's own field of view whenever one is out (30 loupe / 35 binoculars), the
    drawing session asks for the same target so the click moves nothing, and putting the
    tool away is what releases the view. `tests/test_instrument_zoom.gd` steps 7-9 pin the
    new rule. The cost, accepted: the wheel is not felt while a glass is up (it still
    moves `base_fov`, which is where the view returns), and the loupe's tunnel view is the
    price of looking through a lens.
  - `_pull_glass()` is called **before** the `if _view == null: return` guard in
    `_update_view()`: the view is the one thing allowed to be missing, and it must not be
    able to leave the field of view stuck narrow.
  - `player/player.gd` writes `camera.fov` in four places and no more: the start and
    respawn resets (which now reset `base_fov` and `_fov_target` with them),
    `_set_base_fov()` and `_update_fov()`.
  - `ui/instrument_view.gd`'s header comment forbade exactly this. It now explains the
    split instead — including why it is *not* a second `Viewport` — so the next reader
    does not "fix" it.
  - `tests/test_instrument_zoom.gd` is new (target reached and stopped, release restores
    the player's own zoom, the wheel moves the base under a raised glass, both clamps, and
    that only a live session asks for the pull). `tests/test_study.gd` needed no change.
- [ ] **True lens magnification** (carved out of the item above) — a second `Viewport`
  rendering the reticle region into the circle, instead of narrowing the whole camera. That
  is real lens magnification and it would keep working when a specimen is bigger than the
  lens instead of being clipped by the mask, at the cost of a viewport, a texture and an
  alignment to keep right. Not needed while the mask hides the cheat; worth doing when the
  loupe has to show something the circle cannot hold.
- [x] **Name the things you discover** — done for the guaranteed path (naming from a
  Pedia page); the mid-play prompt is carved out below. The player gets to name a species. Every plant and
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
  - **What landed**, and where it differs from the plan above:
    - `ui/pedia_notes.gd` grew the first *value* the notebook has ever stored:
      `give_name`/`name_of`/`display_name`/`names`/`restore_names`/`can_name`, with
      the sanitising in the registry rather than in the text field, so two callers
      cannot sanitise differently. Identity is still `chapter/id`; no uniqueness rule.
    - The field is `ui/name_field.gd`, a `LineEdit` subclass, and it exists to own
      **ESC**: the pause menu listens for that key and would otherwise close the book
      out from under a half-typed name. It swallows the key, restores the stored name
      and **releases focus** — so ESC is a ladder (abandon the edit, then walk back
      out) instead of a dead end. `PROCESS_MODE_ALWAYS`, so it takes keystrokes with
      the book open over a paused tree *and* in a test that opens it unpaused.
    - It is called `give_name`, not `set_name`: under that name a static call resolves
      to the engine's own method instead of ours and fails with "Expected 1
      argument(s)" — a confusing way to lose an afternoon.
    - One resolver, three readers: the Pedia's list buttons, a data page's title, and
      the study meter's line (`player/study.gd::subject_name()`). `tests/test_pedia.gd`
      now compares the heading against the resolver, not against the data table.
    - Saved as `names` beside `notes` (`player/player.gd::save_state`/`load_state`); a
      save written before the feature has no such key and loads as plain defaults. A
      name on a non-nameable entry is refused on the way in *and* on the way out, so a
      hand-edited save cannot smuggle one in.
    - **Dying keeps names and drawings** — the notebook is a keepsake, and only a fresh
      run clears it (`Notes.clear()`, called under `take_pending_new_run()`). Pinned in
      `tests/test_naming.gd`: the drone dies, respawns, and the book still lists it.
    - `tests/test_naming.gd` is new: fallbacks, the species gate, sanitising and the cap,
      rename/clear, junk in the names slot, typing over a paused tree, Enter commits,
      ESC cancels without closing the book, save round trip, death, the meter's line.
  - [ ] **The discovery prompt** ("press N to name it", carved out of this item) — the
    convenience path, and the only part not built. The plan above is explicit that it is
    not the guaranteed one: the field is on the page whenever the player wants it, so
    missing the moment a species is drawn costs nothing. Worth doing when the naming
    itself has been played and the wording can be judged in the hand.
- [x] **The notebook fills by doing** (Maurice's calls, 27 Sep) — a run opens the Pedia on four
  **empty** chapters, and every entry in it is something the drone did:
  - **species** by study (`player/study.gd`), and **equipment** by carrying it — both as before,
    because picking something up is an act;
  - **islands** by **sailing right round** them, not by standing on them and not by landing on
    one: the chapter is a map the player drew. `player/player.gd::_chart_step()` credits the
    compass sector the hull is in while it is aboard, `world/island.gd`'s charting section owns
    the geometry and the band, and all twelve sectors are required. **`CHART_BAND` is a measured
    number, not a taste** (worst sea in a sector: Ezo 2 m, Honshu 35 m, Shikoku 68 m, Kyushu 50 m
    off the coast, so 90 m with margin), and `tests/test_boat.gd` section 10 walks the ring — a
    coastline change that walled a sector off fails a test instead of quietly making a page
    unobtainable;
  - **the survey's beat**: three plants **and** three animals drawn on one island plays that
    island's own page (`player/study.gd::_play_survey_beat` → `ui/story_text.gd`'s `ezo` for
    Ezo) — one page, in the drone's own voice, on the drawing that completes the count and never
    again. Islands with no content have no page and play nothing: `play_milestone()` refuses an
    id with no words, which is right for a survey nobody has written up yet;
  - **the boat's page** (`boat`, "The Boat Discovered") is played by the first boat a run
    boards (`world/boat.gd::_play_page_once`), which is where a player is told that a boat is
    what charts an island. `tests/test_boat.gd` checks it on that first boarding.
  - Answered the open question in the same pass: the reward is a **milestone page**, and the
    voice is the drone's own knowledge coming back — not a message left by someone else. The
    world has no second character, the kit already supplies the absent giver ("someone wants you
    to study your surroundings"), and the intro's own move is a drone that recognises a sword and
    asks itself how it knows. A deduction needs evidence, which is what the count is for.
