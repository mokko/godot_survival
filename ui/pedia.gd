extends Control
## The Pedia: the drone's research notes, opened from the pause menu.
##
## Three layers, named for what they are:
##  - **chapters** — the table of contents: a menu of the four chapters;
##  - **subchapters** — a menu of the things inside one chapter;
##  - **data pages** — one game element: a square picture top left, its name in a
##    larger font, and the text that describes it.
##
## The first two are menus, built from ui/pedia_data.gd (which holds every word);
## the third is a data page, built from the same record plus its plate from
## ui/pedia_art.gd. `Back` walks one layer up, and at the chapters page it closes
## the book and hands back to the pause menu. **Nothing here handles ESC**: the
## pause menu owns that key and calls back() for it, so there is exactly one owner
## and no race.
##
## Listing every subchapter is deliberate for now — the filter for "only what the
## player has met" belongs in one place, and that place is `_subchapters_of()`.

const PediaData := preload("res://ui/pedia_data.gd")

## Emitted when the book closes, so the pause menu can show itself again.
signal closed

const CONTENTS_INTRO := "Your research notes."

const LIST_COLUMNS := 3

@onready var title: Label = $Center/Padding/Panel/VBox/Title
@onready var chapters: VBoxContainer = $Center/Padding/Panel/VBox/Chapters
@onready var subchapters: ScrollContainer = $Center/Padding/Panel/VBox/Subchapters
@onready var blurb: Label = $Center/Padding/Panel/VBox/Subchapters/Column/Blurb
@onready var grid: GridContainer = $Center/Padding/Panel/VBox/Subchapters/Column/Grid
@onready var data_page: VBoxContainer = $Center/Padding/Panel/VBox/DataPage
@onready var plate: Control = $Center/Padding/Panel/VBox/DataPage/Head/Plate
@onready var data_name: Label = $Center/Padding/Panel/VBox/DataPage/Head/Headings/Name
@onready var data_subtitle: Label = $Center/Padding/Panel/VBox/DataPage/Head/Headings/Subtitle
@onready var text_scroll: ScrollContainer = $Center/Padding/Panel/VBox/DataPage/Text
@onready var data_text: Label = $Center/Padding/Panel/VBox/DataPage/Text/Body
@onready var back_button: Button = $Center/Padding/Panel/VBox/Back

var chapter := ""        ## "" on the chapters page, else the chapter being shown
var subchapter_id := ""  ## "" unless a data page is open


func _ready() -> void:
	visible = false
	back_button.pressed.connect(back)
	_build_chapters()


func open() -> void:
	## A reference book, not a place you resume: it always opens on the chapters.
	visible = true
	show_chapters()


func close() -> void:
	visible = false
	closed.emit()


func back() -> void:
	## One layer up: data page → subchapter menu → chapters → closed.
	if subchapter_id != "":
		show_subchapters(chapter)
	elif chapter != "":
		show_chapters()
	else:
		close()


func page() -> String:
	## Which layer is up — for tests and for anything that wants to know.
	if subchapter_id != "":
		return "data"
	return "subchapters" if chapter != "" else "chapters"


## ------------------------------------------------------------------- the pages

func show_chapters() -> void:
	chapter = ""
	subchapter_id = ""
	title.text = "Pedia"
	chapters.show()
	subchapters.hide()
	data_page.hide()
	_focus_first()


func show_subchapters(chapter_id: String) -> void:
	if PediaData.chapter(chapter_id).is_empty():
		return
	chapter = chapter_id
	subchapter_id = ""
	var info: Dictionary = PediaData.chapter(chapter_id)
	title.text = str(info["title"])
	blurb.text = str(info["blurb"])
	chapters.hide()
	data_page.hide()
	subchapters.show()
	subchapters.scroll_vertical = 0
	grid.columns = LIST_COLUMNS
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for record in _subchapters_of(chapter_id):
		var button := Button.new()
		button.text = str(record["name"])
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(show_data_page.bind(chapter_id, str(record["id"])))
		grid.add_child(button)
	_focus_first()


func show_data_page(chapter_id: String, id: String) -> void:
	var record: Dictionary = PediaData.subchapter(chapter_id, id)
	if record.is_empty():
		return
	chapter = chapter_id
	subchapter_id = id
	title.text = PediaData.chapter_title(chapter_id)
	data_name.text = str(record["name"])
	data_subtitle.text = str(record["subtitle"])
	data_text.text = str(record["text"])
	chapters.hide()
	subchapters.hide()
	data_page.show()
	# Fresh page: start at the top of the text, not where the last one scrolled to.
	text_scroll.scroll_vertical = 0
	plate.set_entry(chapter_id, id)
	_focus_first()


func _subchapters_of(chapter_id: String) -> Array:
	## Everything in the chapter. The one place to filter, when the notes start
	## listing only what the player has actually met.
	return PediaData.subchapters(chapter_id)


## ------------------------------------------------------------------- plumbing

func _build_chapters() -> void:
	## The four chapters, built from the data so a new chapter needs no scene edit.
	var intro := Label.new()
	intro.text = CONTENTS_INTRO
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 740.0
	intro.add_theme_font_size_override("font_size", 18)
	chapters.add_child(intro)
	for c in PediaData.chapters():
		var button := Button.new()
		button.text = str(c["title"])
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(show_subchapters.bind(str(c["id"])))
		chapters.add_child(button)


func _focus_first() -> void:
	## Keep the keyboard usable: whatever page is up, its first button has focus.
	var buttons := _page_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()
	else:
		back_button.grab_focus()


func _page_buttons() -> Array:
	## The buttons a player can reach without the mouse, page order.
	var out: Array = []
	for container in [chapters, grid]:
		for child in container.get_children():
			if child is Button and child.visible:
				out.append(child)
	return out