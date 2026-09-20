extends Control
## One Pedia entry's picture. Every plate is drawn from ui/pedia_art.gd's ops —
## no image assets, like the rest of the game — so setting the entry and
## redrawing is the whole job here.
##
## Slot usage mirrors the inventory icons: set_entry() then the redraw happens
## on its own; an unset entry draws the frame only.

const PediaArt := preload("res://ui/pedia_art.gd")
const VectorArt := preload("res://ui/vector_art.gd")

const BACKDROP := Color(0.13, 0.17, 0.22, 0.85)
const FRAME := Color(0.42, 0.5, 0.58, 0.9)

var chapter := ""
var entry_id := ""


func _ready() -> void:
	## A Control is not guaranteed to repaint when the layout resizes it, and the
	## plates are drawn to their own size, so ask for it explicitly.
	resized.connect(queue_redraw)


func set_entry(chapter_id: String, entry_id_: String) -> void:
	if chapter == chapter_id and entry_id == entry_id_:
		return
	chapter = chapter_id
	entry_id = entry_id_
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, BACKDROP, true)
	draw_rect(frame, FRAME, false, 1.0)
	if entry_id == "":
		return
	VectorArt.draw_ops(self, PediaArt.plate_ops(chapter, entry_id, size))