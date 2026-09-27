@tool
extends EditorPlugin
## Turns off middle-mouse pasting in the editor's text fields.
##
## Why this exists: the paste is Godot's own doing, in `TextEdit` and `LineEdit`, and it
## ignores the desktop's version of the same setting (GNOME's "Middle Click Paste" does
## not reach it — see godot-proposals#6450, where a maintainer notes that "mice with
## broken scroll wheels that send middle clicks for no good reason are quite common out
## there"). So a wheel that fires the middle button while scrolling pastes whatever was
## last selected *into the script you are editing*, which is exactly what a duplicated
## fragment in the middle of a file looks like.
##
## `middle_mouse_paste_enabled` exists on both text classes, but no `text_editor/...`
## editor setting exposes it in this build, so a plugin is the only way to switch it off
## without building the engine.
##
## Only the *paste* goes: the middle button still pans a 3D view and still closes editor
## tabs. Nothing here runs in a game — `EditorPlugin` is editor-only, so an exported build
## never loads it. The files do travel with the project unless `addons/*` is excluded from
## the export filters.

func _enter_tree() -> void:
	# Every text field the editor has right now...
	_walk(get_editor_interface().get_base_control())
	# ...and every one it creates afterwards, which is what covers script and shader tabs:
	# a tab's editor is born when the tab is opened, long after this plugin started.
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	_switch_off(node)


func _walk(node: Node) -> void:
	_switch_off(node)
	for child in node.get_children():
		_walk(child)


func _switch_off(node: Node) -> void:
	## Both classes carry the property — `TextEdit` for the script and shader editors,
	## `LineEdit` for every one-line field — and setting it when it is already off costs
	## nothing, so this never needs to ask what the node is beyond having the property.
	if node is TextEdit:
		(node as TextEdit).middle_mouse_paste_enabled = false
	elif node is LineEdit:
		(node as LineEdit).middle_mouse_paste_enabled = false
