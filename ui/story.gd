extends Control
## The story screen — a page of words typed out on a near-black background **as a
## mechanical typewriter**: a monospace typewriter face, a clack per character, and a
## carriage return with its bell at every line break. The words are `ui/story_text.gd`'s.
##
## ESC or a left click moves on — to the next page, or on to what comes after the last one.
## It is deliberately **one press, one thing**: there is no skip-then-confirm two-stage, and
## no "press to finish typing this page" state either, so a press always moves the story
## forward by exactly one step.
##
## It is shown in two places, and `enters_game` is what tells them apart:
##
##  - **The intro** — the scene itself, entered by `ui/splash.gd` on a fresh run only (Load
##    Game skips it), with `enters_game = true`: the last press loads `world/main.tscn`.
##    `PAGES` is **one** screen now; the rest of the story is told in milestones.
##  - **Milestones** — instanced in `world/main.tscn` as `HUD/StoryScreen`, hidden, with
##    `enters_game = false`: a world node that has just *done* something asks for its page
##    (`play_milestone()`, called by `world/explorer_kit.gd`, `items/katana_pickup.gd` and
##    `world/bench.gd`), and the last press closes the screen and hands the run back. The
##    world is paused behind it and **no scene is ever reloaded** — entering the game from a
##    milestone would restart the very run the page is narrating. See `ui/story.md`.
##
## The click is handled in _unhandled_input, so every node in story.tscn must
## keep mouse_filter = MOUSE_FILTER_IGNORE: a Control on the default STOP grabs
## the click during GUI hit-testing, marks it handled, and the event never
## reaches this script (that is why only ESC used to work). If you add a button
## here later, give it STOP but connect it — do not re-enable STOP on the
## full-rect Background/Center container, which would swallow every click.
##
## The typing is paced in _process: characters come out at CHARS_PER_SEC, a line
## break stops the reveal for RETURN_PAUSE so the carriage can travel, and the
## sounds are fired from the characters actually revealed rather than from a
## separate clock, so they can never drift from the text.

const GAME_SCENE := "res://world/main.tscn"
const StoryText := preload("res://ui/story_text.gd")
const StoryProgress := preload("res://ui/story_progress.gd")
## Typewriter speed. 28 cps reads as deliberate narration; 40 rushed it (a page lands in a
## few seconds, and a click or ESC still moves on at any point).
const CHARS_PER_SEC := 28.0
## A clack does not fire faster than this however fast the reveal runs. At 28 cps
## a clack on every single character is one solid buzz rather than typing, so the
## shortest gap wins and the rest of the characters come out silently.
const KEY_MIN_GAP := 0.055
## The beat at the end of a line. A typewriter's carriage return is not instant,
## and the pause is what makes a newline read as a newline instead of as the next
## sentence arriving on its own.
const RETURN_PAUSE := 0.26
## Sits at the end of the revealed text while the machine is still typing, the way
## a cursor waits for the next keystroke. Dropped once a page is complete, so a
## finished page is the finished text.
const CURSOR := "▌"
## Key clacks are the loudest thing here because they repeat ~18 times a second;
## the return is a one-off and can ring.
const KEY_VOLUME_DB := -12.0
const RETURN_VOLUME_DB := -7.0
## What the finished page says to do next.
const PROMPT_NEXT := "click or press ESC for the next page"
const PROMPT_BEGIN := "click or press ESC to begin"
## A milestone screen is not the start of anything: the player was already playing, and
## presses were only ever moving the text aside.
const PROMPT_RESUME := "click or press ESC to carry on"

## A milestone screen closed: the world may react (it is unpaused and has the mouse back by
## the time this fires).
signal finished

## The intro screen loads the world when its last page is done; a **milestone** screen —
## the same machine, instanced in `world/main.tscn` with this turned off — hands the run
## back instead. See the class comment.
@export var enters_game := true

@onready var label: Label = $Center/VBox/Text
@onready var hint: Label = $Center/VBox/Hint
@onready var progress: Label = $Progress

## The records this screen walks: the intro's list, or a single milestone page. Never
## `ui/story_text.gd`'s catalogue directly, because a milestone is not in it.
var _pages: Array = []
## Which milestone is up, "" for the intro.
var _milestone := ""
var _page := 0               # which of _pages is up
var _text := ""              # that page's words, cached for _process
var _shown := 0.0            # characters revealed so far (float accumulator)
var _done := false
var _starting := false
var _hold := 0.0             # seconds left of a carriage-return beat
var _since_key := 99.0       # seconds since the last clack
var _snd_key: AudioStreamPlayer = null
var _snd_return: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()


func _make_snd(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func _ready() -> void:
	# Two players on purpose: the carriage return has to ring on while the next
	# line's clacks start, and one player would cut it off.
	_snd_key = _make_snd("res://sounds/type_key.wav", KEY_VOLUME_DB)
	_snd_return = _make_snd("res://sounds/type_return.wav", RETURN_VOLUME_DB)
	_rng.seed = 20260926          # the same intro sounds the same every run
	if enters_game:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pages = StoryText.PAGES
		_begin_page(0)
	else:
		# A milestone screen **waits to be asked**: it is instanced in the world scene, so
		# it must not type the intro into the void, must not come up before anything asks
		# for it, and must not touch the mouse — the player is mid-run and the world has
		# it captured. All three are the same fact, so all three are decided here rather
		# than in the scene that instances it.
		#
		# It must not listen either, for the same reason: a hidden Control still draws
		# `_unhandled_input`, so a screen waiting to be asked would answer the first ESC
		# or click of the run — and `_advance()` on an empty screen unpauses the tree and
		# takes the mouse off whatever *is* up (the pause menu is PROCESS_MODE_WHEN_PAUSED,
		# so it then cannot act, and ESC reads as broken). `play_milestone()` is what
		# switches this on, `_finish_milestone()` what switches it off again.
		hide()
		set_process(false)
		set_process_unhandled_input(false)


# --------------------------------------------------------------------- the pages

func play_milestone(id: String) -> bool:
	## Put a mid-run screen up: **one** page from `ui/story_text.gd`'s milestones, on the
	## same machine as the intro. True when there was a page to play — an id with no words
	## behind it is refused rather than shown blank.
	##
	## The world is paused while it is up (a day cycle turning and an animal charging
	## behind a text screen would both be wrong) and it is handed back when the screen
	## closes. Whoever asked is free to react to `finished` — or not.
	var record: Dictionary = StoryText.milestone(id)
	if record.is_empty():
		return false
	_milestone = id
	_pages = [record]
	# The milestone is discovered by being shown, so it is recorded here — before the
	# indicator is drawn, so the page the player is reading is already counted.
	StoryProgress.discover(id)
	progress.text = progress_text()
	progress.show()
	# Typing and the ESC/click that ends it both have to keep running while the tree is
	# paused, so the screen outruns the pause it just applied.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)   # ...and it is the one listening while it is up
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	set_process(true)
	_begin_page(0)
	return true


func milestone_id() -> String:
	## Which milestone page is up — "" for the intro, or nothing at all.
	return _milestone


func progress_text() -> String:
	## The milestone indicator, drawn in the screen's bottom right: how many milestones this
	## run has been **shown**, out of how many there are. Counted including the one on screen,
	## because being shown it is the discovering — so the page the player is reading is
	## already the last of the x, not the one before it.
	##
	## The total is the catalogue's size, so writing a new milestone into
	## `ui/story_text.gd` moves the denominator on its own.
	return "%d/%d" % [StoryProgress.count(), StoryText.MILESTONES.size()]


func milestones_seen() -> int:
	## How many milestones the run has been shown — the number behind the indicator, for
	## anything that wants it without the string.
	return StoryProgress.count()


func is_playing() -> bool:
	## Whether a screen is actually **up**. A milestone screen sits in the world scene
	## hidden, waiting to be asked, which is not the same thing as being shown.
	return visible


func page_count() -> int:
	## How many screens this screen holds.
	return _pages.size()


func page_index() -> int:
	## Which page is up, from 0.
	return _page


func page_text() -> String:
	## The page's words — what the tests measure against, and what is being typed.
	return _text


func is_last_page() -> bool:
	return _page + 1 >= page_count()


func page_title() -> String:
	## The page's title as written in the catalogue (not as displayed).
	return str(_page_record().get("title", ""))


func page_body() -> String:
	## The page's prose as written in the catalogue.
	return str(_page_record().get("body", ""))


func _page_record() -> Dictionary:
	## A page is {"title": …, "body": …}; anything else in the list is treated as empty
	## rather than crashing the screen. Guarded on the index too: a milestone screen with
	## no page up (nothing asked for it yet) is not an error.
	if _page < 0 or _page >= _pages.size():
		return {}
	var record = _pages[_page]
	return record if record is Dictionary else {}


func display_title(title: String) -> String:
	## How a typist set a heading, because a typewriter has no bold: **CAPITALS, and
	## letterspaced**, with a wider gap between words. That spacing is the one emphasis
	## available — the other historical trick, overstriking a character twice for a
	## heavier look, cannot be done in a Label and would read as a typo anyway.
	var words: PackedStringArray = []
	for word in title.to_upper().split(" ", false):
		var letters: PackedStringArray = []
		for i in word.length():
			letters.append(word[i])
		words.append(" ".join(letters))
	return "   ".join(words)


func _begin_page(index: int) -> void:
	## Show a page from its first character. Everything a page owns resets here, so a
	## page can never inherit half a line, a running beat or a stale cursor from the
	## one before it. The heading goes in as the first line of the typed text, which is
	## what gives it clacks of its own and a carriage-return beat under it (the blank
	## line between heading and body).
	_page = index
	_text = display_title(page_title()) + "\n\n" + page_body()
	_shown = 0.0
	_done = false
	_hold = 0.0
	_since_key = 99.0            # the first clack of a page comes at once
	label.text = ""
	hint.text = ""
	if _snd_return != null:
		_snd_return.stop()       # the previous page's bell does not ring into this one


func next_page() -> bool:
	## Move on: the next page, or false once the last one is up — which means the screen is
	## finished, and what that leads to is `enters_game`'s business (the world, or the run
	## the milestone borrowed). Public so a test can drive pages without input events.
	if is_last_page():
		return false
	_begin_page(_page + 1)
	return true


func _process(delta: float) -> void:
	if _done or _starting:
		return
	_since_key += delta
	if _hold > 0.0:
		# Mid carriage-return: the text stands still and the beat runs out.
		_hold = maxf(_hold - delta, 0.0)
		return
	var before := int(_shown)
	var limit := _text.length()
	_shown = minf(_shown + CHARS_PER_SEC * delta, float(limit))
	var now := int(_shown)
	# A line break among the characters just revealed stops the reveal *at* the break,
	# so the carriage return happens at the end of a line and the next line starts
	# after the beat. Without this the break would be ordinary and the bell would ring
	# somewhere inside the following sentence.
	var brk := _text.find("\n", before)
	if brk != -1 and brk < now:
		now = brk + 1
		_shown = float(now)
		if _snd_return != null:
			_snd_return.play()
		_hold = RETURN_PAUSE
	if now > before:
		_clack()
	label.text = _text.substr(0, now) + (CURSOR if now < limit else "")
	if now >= limit:
		_done = true
		label.text = _text
		if not enters_game:
			hint.text = PROMPT_RESUME      # a milestone hands the run back
		else:
			hint.text = PROMPT_BEGIN if is_last_page() else PROMPT_NEXT


func _clack() -> void:
	## One key clack, if enough time has passed for a separate one to be heard, and a
	## little pitch scatter so a line of them does not sound like a machine gun.
	if _since_key < KEY_MIN_GAP:
		return
	_since_key = 0.0
	if _snd_key == null:
		return
	_snd_key.pitch_scale = _rng.randf_range(0.92, 1.08)
	_snd_key.play()


# ----------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_advance()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	## One press moves the story on by one step, whether the page is still typing or
	## long finished — and the last step is the world's or the run's, never both.
	##
	## A screen that is **not up** refuses: nothing is being asked of it, and the last
	## step would unpause the run and re-capture the mouse from under whatever else is
	## on screen (a hidden screen is still reachable through this method, and through
	## input if anything ever re-enables the listener).
	if not visible or _starting:
		return
	if next_page():
		return
	if enters_game:
		_start_game()
	else:
		_finish_milestone()


func _finish_milestone() -> void:
	## Hand the run back. **Nothing here loads a scene**: entering the game would restart
	## the very run the page is narrating. Unpause, give the mouse back, stop making
	## noise, get out of the way — and say so, because whoever asked for the screen may
	## want to act on it being done.
	if _snd_key != null:
		_snd_key.stop()
	if _snd_return != null:
		_snd_return.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()
	set_process(false)
	# Stop listening, and stop outrunning the pause: while the screen is down, ESC and
	# the click belong to the world again (the pause menu, the inventory, the boat).
	# Leaving the listener on was a real bug — a hidden screen still draws
	# `_unhandled_input`, so the next ESC was answered by *the page that had just closed*,
	# which unpaused the run and handed the mouse back out from under the screen the
	# player was actually looking at (the Frame screen, whose ESC then never arrived).
	set_process_unhandled_input(false)
	process_mode = Node.PROCESS_MODE_INHERIT
	finished.emit()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	# The machine stops with the screen: no clacks under the loading wait.
	if _snd_key != null:
		_snd_key.stop()
	if _snd_return != null:
		_snd_return.stop()
	# Immediate visual feedback: the world scene takes a while to load (several
	# seconds on a Rock 5B), so the player must see the skip register the
	# instant they press.
	label.hide()
	hint.text = "Loading..."
	hint.show()
	# The hint has to actually reach the screen before the load blocks the
	# main thread. `process_frame` is emitted *before* drawing, and
	# RenderingServer.frame_post_draw never fires in headless runs, so wait a
	# few real frames on a short timer instead: change_scene_to_file()
	# instantiates the new scene on the spot and freezes everything.
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file(GAME_SCENE)