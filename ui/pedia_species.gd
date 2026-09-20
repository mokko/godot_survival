extends RefCounted
## Which Pedia subchapter a world node is — one mapping, two callers: the study
## code (what may be drawn into the notebook) and a dying animal (which specimen
## to leave behind).
##
## Two ways to answer it:
##  - a node that describes itself: items/carcass.gd carries the species it was,
##    and is asked duck-typed through study_chapter()/study_id()/study_name();
##  - a species instance, whose own scene file names its page — fauna/grazer.tscn
##    is animals/grazer, flora/sunbulb.tscn is plants/sunbulb. A variant with no
##    page of its own (flora/mirrorlily_small.tscn) reports {} and is therefore
##    neither studyable nor worth a specimen.

const PediaData := preload("res://ui/pedia_data.gd")


static func of_node(node: Node) -> Dictionary:
	## {chapter, id, name} for anything the notebook has a page for, else {}.
	if node == null:
		return {}
	if is_specimen(node):
		var chapter := str(node.study_chapter())
		var id := str(node.study_id())
		var record := PediaData.subchapter(chapter, id)
		if record.is_empty():
			return {}
		return {"chapter": chapter, "id": id, "name": str(record["name"])}
	var node_3d := node as Node3D
	if node_3d == null:
		return {}
	var path := node_3d.scene_file_path
	var species_chapter := ""
	if path.begins_with("res://fauna/"):
		species_chapter = "animals"
	elif path.begins_with("res://flora/"):
		species_chapter = "plants"
	else:
		return {}
	var species_id := path.get_file().get_basename()
	var page: Dictionary = PediaData.subchapter(species_chapter, species_id)
	if page.is_empty():
		return {}
	return {"chapter": species_chapter, "id": species_id, "name": str(page["name"])}


static func is_species(node: Node) -> bool:
	return not of_node(node).is_empty()


static func is_specimen(node: Node) -> bool:
	## A carcass rather than a living thing: the thing an animal has to become
	## before it can be drawn.
	return node != null and node.has_method("study_id") \
			and node.has_method("study_chapter")