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

	# 1. More than one screen, and every page is a page worth typing.
	if StoryText.PAGES.size() < 2:
		fails.append("the intro is a single screen (%d page)" % StoryText.PAGES.size())
	for i in StoryText.PAGES.size():
		var page := str(StoryText.PAGES[i])
		if page.strip_edges() == "":
			fails.append("page %d has no words" % (i + 1))
		if not page.ends_with("\n"):
			fails.append("page %d does not end on a newline" % (i + 1))

	# 2. The line break is its own beat. Stepped with a fixed delta so this does not
	#    depend on how fast headless frames happen to run.
	var fresh = load("res://ui/story.tscn").instantiate()
	root.add_child(fresh)
	for i in 2:
		await process_frame
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
	if not fresh.next_page():
		fails.append("there is no second page to move to")
	if fresh.page_index() != 1:
		fails.append("the page index did not move (%d)" % fresh.page_index())
	if fresh.page_text() != str(StoryText.PAGES[1]):
		fails.append("page 2 is not the second entry in the catalogue")
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
	if story.page_text() != str(StoryText.PAGES[0]):
		fails.append("the story opens on something other than page 1")
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

	print("RESULT pages=%d typing=%d/%d loading_hint=%s in_game=%s floor=%s cr_held=%s cr_at=%d sounds=%s"
			% [StoryText.PAGES.size(), partial_len, full_len, loading_shown, in_game,
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