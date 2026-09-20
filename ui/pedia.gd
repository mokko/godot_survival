extends Control
## The Pedia: the island's handbook, opened from the pause menu.
##
## Three kinds of page, all built from ui/pedia_data.gd (the words) and
## ui/pedia_art.gd (the pictures):
##
##   contents — the four chapters
##   list     — every entry in a chapter; the chapter's blurb, then its things
##   entry    — one thing: its plate, its name and subtitle, and its text
##
## `Back` walks one page up and at the contents page closes the book and hands
## back to the pause menu. **Nothing here handles ESC**: the pause menu owns that
## key and calls back() for it, so there is exactly one owner and no race.
##
## Listing every entry is deliberate for now — the filter for "only what the
## player has met" belongs in one place, and that place is `_entries_of()`.

const PediaData := preload("res://ui/pedia_data.gd")

## Emitted when the book closes, so the pause menu can show itself again.
signal closed

const CONTENTS_INTRO := "What is on this island, and what it is called. Everything the survey has \
recorded so far, chapter by chapter — the four islands, the plants that grow on them, the animals \
that live there, and what the drone can carry."

const LIST_COLUMNS := 3

@onready var title: Label = $Center/Padding/Panel/VBox/Title
@onready var contents: VBoxContainer = $Center/Padding/Panel/VBox/Contents
@onready var list: ScrollContainer = $Center/Padding/Panel/VBox/List
@onready var blurb: Label = $Center/Padding/Panel/VBox/List/Column/Blurb
@onready var grid: GridContainer = $Center/Padding/Panel/VBox/List/Column/Grid
@onready var entry_page: VBoxContainer = $Center/Padding/Panel/VBox/Entry
@onready var plate: Control = $Center/Padding/Panel/VBox/Entry/Head/Column/Plate
@onready var entry_name: Label = $Center/Padding/Panel/VBox/Entry/Head/Column/Name
@onready var entry_subtitle: Label = $Center/Padding/Panel/VBox/Entry/Head/Column/Subtitle
@onready var text_scroll: ScrollContainer = $Center/Padding/Panel/VBox/Entry/Head/Text
@onready var entry_text: Label = $Center/Padding/Panel/VBox/Entry/Head/Text/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

var chapter := ""    ## "" on the contents page, else the chapter being shown
var entry_id := ""   ## "" unless a single entry is open


func _ready() -> void:
	visible = false
	back_button.pressed.connect(back)
	_build_contents()


func open() -> void:
	## A reference book, not a place you resume: it always opens on the contents.
	visible = true
	show_contents()


func close() -> void:
	visible = false
	closed.emit()


func back() -> void:
	## One page up: entry → chapter list → contents → closed.
	if entry_id != "":
		show_list(chapter)
	elif chapter != "":
		show_contents()
	else:
		close()


func page() -> String:
	## Which page is up — for tests and for anything that wants to know.
	if entry_id != "":
		return "entry"
	return "list" if chapter != "" else "contents"


## ------------------------------------------------------------------- the pages

func show_contents() -> void:
	chapter = ""
	entry_id = ""
	title.text = "Pedia"
	contents.show()
	list.hide()
	entry_page.hide()
	_focus_first()


func show_list(chapter_id: String) -> void:
	if PediaData.chapter(chapter_id).is_empty():
		return
	chapter = chapter_id
	entry_id = ""
	var info: Dictionary = PediaData.chapter(chapter_id)
	title.text = str(info["title"])
	blurb.text = str(info["blurb"])
	contents.hide()
	entry_page.hide()
	list.show()
	list.scroll_vertical = 0
	grid.columns = LIST_COLUMNS
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for e in _entries_of(chapter_id):
		var button := Button.new()
		button.text = str(e["name"])
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(show_entry.bind(chapter_id, str(e["id"])))
		grid.add_child(button)
	_focus_first()


func show_entry(chapter_id: String, id: String) -> void:
	var e: Dictionary = PediaData.entry(chapter_id, id)
	if e.is_empty():
		return
	chapter = chapter_id
	entry_id = id
	title.text = PediaData.chapter_title(chapter_id)
	entry_name.text = str(e["name"])
	entry_subtitle.text = str(e["subtitle"])
	entry_text.text = str(e["text"])
	contents.hide()
	list.hide()
	entry_page.show()
	# Fresh page: start at the top of the text, not where the last one scrolled to.
	text_scroll.scroll_vertical = 0
	plate.set_entry(chapter_id, id)
	_focus_first()


func _entries_of(chapter_id: String) -> Array:
	## Everything in the chapter. The one place to filter, when the Pedia starts
	## listing only what the player has actually met.
	return PediaData.entries(chapter_id)


## ------------------------------------------------------------------- plumbing

func _build_contents() -> void:
	## The four chapters, built from the data so a new chapter needs no scene edit.
	var intro := Label.new()
	intro.text = CONTENTS_INTRO
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 740.0
	intro.add_theme_font_size_override("font_size", 18)
	contents.add_child(intro)
	for c in PediaData.chapters():
		var button := Button.new()
		button.text = str(c["title"])
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(show_list.bind(str(c["id"])))
		contents.add_child(button)


func _focus_first() -> void:
	## Keep the keyboard usable: whatever page is up, its first button has focus.
	var buttons := _page_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()
	elif back_button.has_focus() == false:
		back_button.grab_focus()


func _page_buttons() -> Array:
	## The buttons a player can reach without the mouse, page order.
	var out: Array = []
	for container in [contents, grid]:
		for child in container.get_children():
			if child is Button and child.visible:
				out.append(child)
	return out