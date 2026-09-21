# The Pedia and the study loop

The notebook the drone carries, the three layers it opens in, and the two
instruments that fill it. Words live in `ui/pedia_data.gd`, plates in
`ui/pedia_art.gd`, what has been drawn in `ui/pedia_notes.gd`; the filling is
`player/study.gd`.

The drone carries a brown leather **notebook** with `Pedia` on the cover — an
inventory item from the first minute of a run — and the pause menu opens it as a
screen of its own (same dim and panel as the menu, which hides while it is up).
It opens on the line *Your research notes.* and three layers:

1. **chapters** — the table of contents: Islands, Plants, Animals, Equipment,
   each with its progress — `Animals (2/6)`;
2. **subchapters** — the things inside one chapter, as a menu of buttons;
3. **data pages** — one game element: a square picture at the top left, its name
   in a larger font, and the text describing it.

**The notebook starts empty and fills by being out in the world** (`ui/pedia_notes.gd`
holds what has been drawn; the Pedia reads it and nothing else). Each chapter
fills its own way:

- **Plants** are drawn where they grow with the **Magnifying Glass**, by close
  observation: equip it (number key), left click with the crosshair on the plant,
  and hold it in view for **eight seconds** — `player/study.gd`, with a meter under
  the crosshair and a loupe view over the screen. Slip off the subject for more
  than a moment and the drawing starts again from nothing. The glass works close:
  **6 m**.
- **Animals** have two routes to the same page, because an explorer has more than
  one way of looking:
  - **watch one through the Binoculars** for eight seconds — the observation route,
    and they are what makes an animal that flees at twice your walking speed
    drawable at all. The binoculars reach **45 m**;
  - **kill one with a blade** (the katana or the tanto — `items/weapon.gd`
    `has_blade`) and it leaves a **specimen** (`items/carcass.gd`, 90 s, lit so it
    can be found after dark); hold that in the **Magnifying Glass** for eight
    seconds and the **autopsy** records it. An animal killed with an arrow, or
    beaten down with fists, leaves nothing to open, and is lost to the survey.
  - Each instrument has its own subject and says so when it is the wrong one: the
    glass refuses a living animal ("Watch it through the binoculars — or open it
    with a blade"), the binoculars refuse close work ("Close work — use the
    magnifying glass").
- **Equipment** notes itself the moment the drone carries it.
- **Islands** write themselves down when the drone is on one or moored off its
  coast (60 m), so sailing the boat route fills that chapter.

Fresh run: empty. Death: the notes stay, along with the notebook, the pen and the
glass (`KEEPSAKE_ITEMS`) — they are the drone's own record and its instruments.
Save/load: they ride in the savegame's `notes` list. A species with no data page of
its own (mirrorlily's small ground cover) is not studyable, and a chapter with
nothing drawn in it says how to fill it.

The first two layers are menus built from `ui/pedia_data.gd` (the words) and the
third adds the plate from `ui/pedia_art.gd` (the picture). **Back** (or `ESC`,
which the pause menu owns and routes here) walks one layer up; at the chapters
page it closes the book and hands back to the menu. An opened Pedia always starts
at the chapters again.

Two lists are enforced by `tests/test_pedia.gd`: the Equipment chapter covers
exactly the ids in `items/item_db.gd`, and every subchapter in every chapter has
text and a plate to draw. `tests/test_study.gd` walks the filling: the empty start,
the plant drawn after the eight-second hold, an animal observed through the
binoculars at 12 m (out of the glass's reach), the autopsy of the specimen a blade
kill leaves, the specimen an arrow kill does *not* leave, both tools refusing the
other's subject, and the notes surviving a save.

The pictures are vector art, like the inventory icons: `ui/pedia_art.gd` draws an
island from its real outline in `world/island.gd` (Ezo gets its caldera lake and
the arrival point drawn in), an item from the same art its inventory slot uses,
and a plant or animal from a silhouette authored in a 0..1 square. The shared op
vocabulary — op constructors, scaling, drawing, text, scanline fills — is
`ui/vector_art.gd`, used by both the icons and the Pedia.
