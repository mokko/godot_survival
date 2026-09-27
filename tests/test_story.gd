extends SceneTree
## Headless check: the story is typed letter by letter as a typewriter — a clack per
## character and a carriage return with its bell at every line break, which is a beat and
## not just another character. One press moves exactly one step.
##
## Two kinds of screen, both built here: the **intro** (`PAGES`, one screen, ends by
## entering the game) and a **milestone** (`MILESTONES`, one page the world hands over
## mid-run, ends by handing the run back). `enters_game` is what tells them apart, and
## `tests/test_explorer_kit.gd` checks that opening the satchel is what plays one.

const StoryText := preload("res://ui/story_text.gd")

## How many times a milestone screen has said it is done (`finished`).
var _closed := 0


func _on_screen_finished() -> void:
	_closed += 1


func _letters(node: Node) -> String:
	## The revealed text without the cursor the machine leaves while it is still typing.
	return node.get_node("Center/VBox/Text").text.replace(node.CURSOR, "")


func _check_page(fails: PackedStringArray, screen: Node, label: String, record) -> void:
	## The rules a page has to obey, in **one** place so the intro and the milestone
	## screens cannot drift apart: they are typed by the same machine into the same block.
	if not (record is Dictionary):
		fails.append("%s is not a title-and-body record" % label)
		return
	var page: Dictionary = record
	var title := str(page.get("title", ""))
	var body := str(page.get("body", ""))
	if title.strip_edges() == "":
		fails.append("%s has no title" % label)
	if body.strip_edges() == "":
		fails.append("%s has no words" % label)
	if not body.ends_with("\n"):
		fails.append("%s does not end on a newline" % label)
	# A heading is set in capitals *and letterspaced*, which is about three times as
	# long — past the measure it re-wraps and the heading falls apart. Typed
	# explicitly: the node is untyped here, so `:=` cannot infer a String.
	var shown: String = screen.display_title(title)
	if shown.length() > StoryText.MAX_LINE:
		fails.append("%s's heading is %d characters letterspaced (max %d)"
				% [label, shown.length(), StoryText.MAX_LINE])
	if title.length() > StoryText.TITLE_MAX:
		fails.append("%s's title is %d letters (max %d)"
				% [label, title.length(), StoryText.TITLE_MAX])
	# The catalogue holds the words, not the display form: a title already in
	# capitals means somebody typed the rendering into the data.
	if title == title.to_upper() and title != title.to_lower():
		fails.append("%s's title is written in capitals" % label)
	for line in body.split("\n"):
		if line.length() > StoryText.MAX_LINE:
			fails.append("%s has a %d-character line (max %d)"
					% [label, line.length(), StoryText.MAX_LINE])
	# A line is indented by the block, never by its own words: prose that arrived with a
	# tab or a run of trailing spaces in it types those onto the screen (and a leading tab
	# is invisible in a diff, which is how it got in once).
	if body.contains("	"):
		fails.append("%s has a tab in its words" % label)
	for line in body.split("\n"):
		if line != line.strip_edges(false, true):
			fails.append("%s has a line with trailing whitespace" % label)
			break


func _init() -> void:
	var fails: PackedStringArray = []

	# 1. The intro is **one** screen — the run's opening statement — and every page in the
	#    catalogue is a page worth typing: a heading is the first line of what gets typed,
	#    so it has to fit the measure like any other line. The milestones are held to the
	#    same rules, because the same machine types them.
	var fresh = load("res://ui/story.tscn").instantiate()
	root.add_child(fresh)
	for i in 2:
		await process_frame
	if StoryText.PAGES.size() != 1:
		fails.append("the intro is %d screens, not one" % StoryText.PAGES.size())
	for i in StoryText.PAGES.size():
		_check_page(fails, fresh, "page %d" % (i + 1), StoryText.PAGES[i])
	for id in StoryText.MILESTONES.keys():
		_check_page(fails, fresh, "milestone '%s'" % id, StoryText.MILESTONES[id])

	# 1b. No page re-wraps in the real block. This is the property that actually matters,
	#     and it is measured against the resolved font rather than trusted to a character
	#     count: MAX_LINE was first estimated at 71 and the prose already runs to 73.
	var body_label: Label = fresh.get_node("Center/VBox/Text")
	var face: Font = body_label.get_theme_font("font")
	if face == null:
		fails.append("the story label resolved no font")
	else:
		var size: int = body_label.get_theme_font_size("font_size")
		var advance: float = face.get_char_size("M".unicode_at(0), size).x
		print("MEASURE advance=%.2f chars=%.1f block=%.0f capacity=%d"
				% [advance, body_label.size.x / advance, body_label.size.x,
				int(body_label.size.x / advance)])
	fresh.set_process(false)          # the manual text below must not be overwritten
	for i in StoryText.PAGES.size():
		fresh._begin_page(i)
		fresh.set_process(false)
		var text: String = fresh.page_text()
		body_label.text = text
		await process_frame
		var rendered: int = body_label.get_line_count()
		var wanted: int = text.count("\n") + 1
		if rendered != wanted:
			fails.append("page %d re-wraps: %d rendered lines for %d lines of text"
					% [i + 1, rendered, wanted])
	# ...and the milestones, which are typed into the same block by the same machine, so a
	# heading that falls apart there is a bug in the same way.
	for id in StoryText.MILESTONES.keys():
		fresh.play_milestone(id)
		fresh.set_process(false)
		var text: String = fresh.page_text()
		body_label.text = text
		await process_frame
		var rendered: int = body_label.get_line_count()
		var wanted: int = text.count("\n") + 1
		if rendered != wanted:
			fails.append("milestone '%s' re-wraps: %d rendered lines for %d lines of text"
					% [id, rendered, wanted])
		fresh._finish_milestone()
	fresh._pages = StoryText.PAGES      # the checks below are about the intro again
	fresh._begin_page(0)

	# 2. The line break is its own beat. Stepped with a fixed delta so this does not
	#    depend on how fast headless frames happen to run.
	var break_at: int = fresh.page_text().find("\n")
	var steps := 0
	while int(fresh._shown) < break_at + 1 and steps < 400:
		fresh._process(0.05)          # 1.4 characters a step at CHARS_PER_SEC
		steps += 1
	var held: bool = fresh._hold > 0.0
	var stopped_at: int = _letters(fresh).length()
	var has_sounds: bool = fresh._snd_key != null and fresh._snd_return != null
	if has_sounds:
		# A stream that failed to load is null and plays silence, so check the two
		# files actually resolved rather than only that the players exist.
		has_sounds = fresh._snd_key.stream != null and fresh._snd_return.stream != null \
				and fresh._snd_key.stream.get_length() > 0.0 \
				and fresh._snd_return.stream.get_length() > 0.0
	if break_at < 0:
		fails.append("page 1 has no line break to test")
	if not held:
		fails.append("a line break did not take the carriage-return beat")
	if stopped_at != break_at + 1:
		fails.append("the reveal stopped at %d, not at the break (%d)"
				% [stopped_at, break_at + 1])
	if not has_sounds:
		fails.append("the typewriter has no sounds loaded")

	# 3. The intro is **one** screen, so it has nothing to page forward to: `next_page()`
	#    says so, and one press from here is what enters the game (section 4). The second
	#    kind of screen — a milestone the world hands over — is section 5, and *it* is
	#    where "a screen starts from its own first character" is checked, because a
	#    one-page intro can never show it.
	fresh._process(0.05)
	if fresh.next_page():
		fails.append("a one-screen intro paged forward")
	if fresh.page_index() != 0:
		fails.append("the page index moved on a one-screen intro (%d)" % fresh.page_index())
	if not fresh.is_last_page():
		fails.append("the intro's only page is not the last one")
	if fresh.page_count() != 1:
		fails.append("the intro screen holds %d pages" % fresh.page_count())
	root.remove_child(fresh)
	fresh.free()

	# 4. A milestone screen: the same machine, **one** page the world hands over. It sits
	#    hidden in the world scene with `enters_game = false` (that is how `world/main.tscn`
	#    instances it), so it must stay quiet until it is asked, refuse an id with no words
	#    behind it, and hand the run back — never reload it, because the run is what the
	#    page is narrating. "Quiet" includes the keyboard: a hidden Control still receives
	#    unhandled input, so a screen waiting to be asked must not be listening.
	var screen = load("res://ui/story.tscn").instantiate()
	screen.enters_game = false
	root.add_child(screen)
	for i in 3:
		await process_frame
	if screen.is_playing():
		fails.append("the milestone screen was up before anything asked for it")
	if screen.is_processing_unhandled_input():
		fails.append("the milestone screen listens before anything asked it for a page")
	if screen.page_count() != 0:
		fails.append("the milestone screen started with %d pages" % screen.page_count())
	if screen.play_milestone("no_such_milestone"):
		fails.append("a milestone with no page played anyway")
	if screen.play_milestone(""):
		fails.append("an empty milestone id played")
	if not screen.play_milestone("explorer_kit"):
		fails.append("the Explorer's Kit milestone did not play")
	if not screen.is_playing():
		fails.append("the milestone screen did not come up")
	if not screen.is_processing_unhandled_input():
		fails.append("the milestone screen is up but not listening to the keyboard")
	if screen.milestone_id() != "explorer_kit":
		fails.append("the milestone screen says it is playing '%s'" % screen.milestone_id())
	if screen.enters_game:
		fails.append("the milestone screen was asked to enter the game")
	if not paused:
		fails.append("the world was not paused behind the milestone screen")
	var kit_page: Dictionary = StoryText.milestone("explorer_kit")
	if screen.page_title() != str(kit_page.get("title", "")):
		fails.append("the milestone screen is not showing its own page ('%s')"
				% screen.page_title())
	if screen.page_count() != 1:
		fails.append("a milestone screen is %d screens, not one" % screen.page_count())
	# It types from its own first character, like any other page, rather than arriving
	# finished: the world was running when it opened.
	screen.set_process(false)
	screen._process(0.05)
	var milestone_len: int = _letters(screen).length()
	if milestone_len <= 0 or milestone_len >= screen.page_text().length():
		fails.append("the milestone page is not typing (%d/%d)"
				% [milestone_len, screen.page_text().length()])
	# One press ends it: the run comes back, nothing was loaded over it, and the screen
	# says it is done.
	screen.finished.connect(_on_screen_finished)
	screen._advance()
	if screen.is_playing():
		fails.append("the milestone screen stayed up after a press")
	if paused:
		fails.append("the world stayed paused after the milestone screen closed")
	if current_scene != null and current_scene.name == "Main":
		fails.append("the milestone screen loaded a scene instead of closing")
	if _closed != 1:
		fails.append("closing the milestone screen said so %d times" % _closed)
	if screen.is_processing_unhandled_input():
		fails.append("the milestone screen is still listening after it closed")
	# ...and a press aimed at a screen that is not up does nothing at all: with the guard
	# removed this unscopes the run under whatever else is on screen (it did, once).
	screen._advance()
	if _closed != 1:
		fails.append("a closed milestone screen answered a press")
	# ...and it can be played again (a run may find a second katana), from its own first
	# character rather than the end of the last one.
	if not screen.play_milestone("katana"):
		fails.append("the katana milestone did not play")
	screen.set_process(false)
	if _letters(screen).length() >= screen.page_text().length():
		fails.append("a replayed milestone came up already finished")
	screen._finish_milestone()
	root.remove_child(screen)
	screen.free()

	# 5. Typing, and the loading hint, on a fresh screen.
	var story = load("res://ui/story.tscn").instantiate()
	root.add_child(story)
	var label: Label = story.get_node("Center/VBox/Text")
	for i in 20:
		await process_frame
	# Measured without the cursor: with it, an empty reveal would still read as
	# "something on screen" and this could not tell typing from a stall.
	var partial_len: int = _letters(story).length()
	var full_len: int = story.page_text().length()
	if partial_len <= 0 or partial_len >= full_len:
		fails.append("typing=%d/%d" % [partial_len, full_len])
	var page1: Dictionary = StoryText.PAGES[0]
	if story.page_title() != str(page1.get("title", "")):
		fails.append("the story opens on something other than page 1")
	# The heading is the first line of what is typed, in its displayed form — so it
	# clacks like the rest of the page and takes the carriage-return beat under it.
	var first_line: String = story.page_text().split("\n")[0]
	if first_line != story.display_title(story.page_title()):
		fails.append("page 1 does not open with its heading ('%s')" % first_line)
	# From the last page, one press enters the game.
	while story.next_page():
		pass
	story._start_game()
	# The hint is set synchronously (before the loading timer), so it can be
	# checked now: the player must be told the load is happening.
	var hint: Label = story.get_node("Center/VBox/Hint")
	var loading_shown: bool = hint.text == "Loading..." and hint.visible \
			and not label.visible
	if not loading_shown:
		fails.append("the loading hint is not up")
	var in_game: bool = await _await_game()
	var player: CharacterBody3D = current_scene.get_node("Player")
	for i in 90:
		await physics_frame
	if not in_game:
		fails.append("the story did not hand over to the game")
	elif not player.is_on_floor():
		fails.append("the player is not on the floor after the story")

	print("RESULT pages=%d milestones=%d title='%s' typing=%d/%d loading_hint=%s in_game=%s floor=%s cr_held=%s cr_at=%d sounds=%s"
			% [StoryText.PAGES.size(), StoryText.MILESTONES.size(),
			story.display_title(str(page1.get("title", ""))),
			partial_len, full_len, loading_shown, in_game,
			player.is_on_floor(), held, stopped_at, has_sounds])
	if fails.is_empty():
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)


func _await_game(max_frames := 900) -> bool:
	## The scene swap sits behind a short "Loading..." timer, so poll instead of
	## counting frames — headless frames are much shorter than real ones.
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == "Main":
			return true
	return false