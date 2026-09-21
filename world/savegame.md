# Saves: five slots, and where they really are

`world/savegame.gd` owns all of it — this file is the behaviour, not a code walkthrough.

## The five slots

Saves live under `user://saves/`, one file per slot:

- `slot_1.json` … `slot_4.json` — the slots the player writes from the Saves screen and
  names by hand;
- `slot_5.json` — the **autosave**, rewritten by the player's clock every
  `AUTOSAVE_SECONDS` (300 s) into the same path every time, so it can only ever cost the
  player the last five minutes. It is a slot like any other when loading, and the player
  never names it or writes it by hand.

**The name is inside the file, not in its filename.** A fixed path per slot keeps saving
portable (Windows, macOS and Linux disagree about filenames) and lets a name be anything
the player types. `index.json` beside them remembers only which slot was *last played*,
which is what the splash's Continue opens: the run the player was in, so a more recent
autosave cannot hijack it. With no index it falls back to the newest `saved_at`, then to
slot 1.

A file is one flat dictionary: whatever the player's `save_state()` writes, plus the keys
this class adds — `name`, `saved_at`, `slot`, `version`. Flat rather than nested, because
`load_state()` reads its keys straight off the dictionary and ignores what it does not
recognise, which is also why a file written before slots existed still loads.

**Dying costs the run, not the save.** The death path no longer touches a file: the last
save stays loadable, and only a *fresh run* clears the notebook (`Notes.clear()`).

The Saves screen's rename and delete are the next step; `rename_slot()` and `delete_slot()`
are already here, and an emptied slot is a valid, empty save rather than a missing file.

## Where `user://` really is

Ask the engine (`OS.get_user_data_dir()`) rather than trusting any path written down,
including this one. Two things move it, and both were got wrong once:

- **The game's name.** `user://` follows `config/name`, so `project.godot` sets
  `config/use_custom_user_dir` + `config/custom_user_dir_name="Nakamoto"` — deliberately
  *not* the display title — to pin the folder. That works for **player builds only**: the
  engine forces the default `app_userdata/<project name>` location for editor and
  `--script` runs, so the test suite never sees the custom path.
- **The snap revision.** The snap sets `XDG_DATA_HOME` per revision (`godot-4/34`, not
  `godot-4/30`), so a snap refresh still hands out a fresh, empty directory.

Two migrations cover the leftovers, and both **copy — neither ever moves or deletes**:

- `migrate_legacy_file()` — a save written before slots existed (`user://savegame.json`)
  becomes slot 1, once;
- `adopt_legacy_save()`, called from the splash at startup — if this install has no save at
  all, it looks through the sibling `app_userdata` folders (an earlier title) and the same
  folders under sibling snap revisions, and adopts the newest file that is *really ours*
  (`SAVE_KEYS` is what tells our savegame apart from another project's file of the same
  name). Anywhere other than Linux it finds nothing, which is the intended outcome.

The pre-slot API still works: `SAVE_PATH` is slot 1, so `read()`, `write()`, `clear()` and
`exists()` with no slot argument mean slot 1 — and `exists()` with no argument asks whether
*any* slot holds a save.

## Which test covers what

- `tests/test_save_slots.gd` — the five slots, names in the file, the autosave, and that
  death does not wipe a save;
- `tests/test_savegame.gd` — the save/load round trip, armour and time of day included, and
  that Load Game skips the story;
- `tests/test_save_migration.gd` — the adoption rules: a real save is taken with its
  content, junk and another project's file are ignored, and an install that already has a
  save never adopts anything;
- `tests/test_pause_save_quit.gd`, `tests/test_saves_screen.gd` — the pause menu's Save and
  the Saves screen itself.
