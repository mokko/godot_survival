extends SceneTree
## Headless check: the story is told as a stack of pages (`ui/story_text.gd`), each typed
## letter by letter as a typewriter — a clack per character and a carriage return with its
## bell at every line break, which is a beat and not just another character. One press
## moves exactly one step: the next page, and then the game.

const StoryText := preload("res://ui/story_text.gd")


func _letters(node: Node) -> String:
	## The revealed text without the cursor the machine leaves while it is still typing.
	return node.get_node("Center/VBox/Text").text.replace(node.CURSOR, "")


func _init() -> void:
	var fails: PackedStringArray = []

	# 1. More than one screen, and every page is a page worth typing. A heading is the
	#    first line of what gets typed, so it has to fit the measure like any other line.
	var fresh = load("res://ui/story.tscn").instantiate()
	root.add_child(fresh)
	for i in 2:
		await process_frame
	if StoryText.PAGES.size() < 2:
		fails.append("the intro is a single screen (%d page)" % StoryText.PAGES.size())
	for i in StoryText.PAGES.size():
		var record = StoryText.PAGES[i]
		if not (record is Dictionary):
			fails.append("page %d is not a title-and-body record" % (i + 1))
			continue
		var page: Dictionary = record
		var title := str(page.get("title", ""))
		var body := str(page.get("body", ""))
		if title.strip_edges() == "":
			fails.append("page %d has no title" % (i + 1))
		if body.strip_edges() == "":
			fails.append("page %d has no words" % (i + 1))
		if not body.ends_with("\n"):
			fails.append("page %d does not end on a newline" % (i + 1))
		# A heading is set in capitals *and letterspaced*, which is about three times as
		# long — past the measure it re-wraps and the heading falls apart. Typed
		# explicitly: the node is untyped here, so `:=` cannot infer a String.
		var shown: String = fresh.display_title(title)
		if shown.length() > StoryText.MAX_LINE:
			fails.append("page %d's heading is %d characters letterspaced (max %d)"
					% [i + 1, shown.length(), StoryText.MAX_LINE])
		if title.length() > StoryText.TITLE_MAX:
			fails.append("page %d's title is %d letters (max %d)"
					% [i + 1, title.length(), StoryText.TITLE_MAX])
		# The catalogue holds the words, not the display form: a title already in
		# capitals means somebody typed the rendering into the data.
		if title == title.to_upper() and title != title.to_lower():
			fails.append("page %d's title is written in capitals" % (i + 1))
		for line in body.split("\n"):
			if line.length() > StoryText.MAX_LINE:
				fails.append("page %d has a %d-character line (max %d)"
						% [i + 1, line.length(), StoryText.MAX_LINE])

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
	fresh._begin_page(0)              # the checks below are about page 1

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

	# 3. One step moves one page, and a page starts from its own first character rather
	#    than inheriting the last one's text, cursor or running beat.
	fresh._process(0.05)
	var first_page_len: int = _letters(fresh).length()
	var page2: Dictionary = StoryText.PAGES[1]
	if not fresh.next_page():
		fails.append("there is no second page to move to")
	if fresh.page_index() != 1:
		fails.append("the page index did not move (%d)" % fresh.page_index())
	if fresh.page_text() != fresh.display_title(str(page2.get("title", ""))) \
			+ "\n\n" + str(page2.get("body", "")):
		fails.append("the second page is not the one the catalogue holds")
	if _letters(fresh).length() >= first_page_len:
		fails.append("the next page inherited the previous page's text")
	if fresh._done or fresh._hold > 0.0:
		fails.append("the next page started finished or mid-beat")
	while fresh.next_page():
		pass
	if not fresh.is_last_page():
		fails.append("paging forward did not stop at the last page")
	if fresh.page_index() != fresh.page_count() - 1:
		fails.append("the last page is not page_count() - 1 (%d of %d)"
				% [fresh.page_index() + 1, fresh.page_count()])
	root.remove_child(fresh)
	fresh.free()

	# 4. Typing, and the loading hint, on a fresh screen.
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

	print("RESULT pages=%d title='%s' typing=%d/%d loading_hint=%s in_game=%s floor=%s cr_held=%s cr_at=%d sounds=%s"
			% [StoryText.PAGES.size(), story.display_title(str(page1.get("title", ""))),
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