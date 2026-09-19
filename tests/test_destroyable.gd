extends SceneTree
## Headless check: every animal/plant type has 50 life via damage();
## at 0 it vanishes leaving a DeathPuff; puff auto-frees.

const SPECIMENS := [
	["res://fauna/scuttler.tscn", "Scuttler"],
	["res://fauna/grazer.tscn", "Grazer"],
	["res://fauna/gull.tscn", "Gull"],
	["res://fauna/rippleback.tscn", "Rippleback"],
	["res://fauna/drifter.tscn", "Drifter"],
	["res://fauna/stalker.tscn", "Stalker"],
	["res://flora/sunbulb.tscn", "Sunbulb"],
	["res://flora/thornlash.tscn", "Thornlash"],
]


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var holder := Node3D.new()
	root.add_child(holder)
	var fails: PackedStringArray = []

	for spec in SPECIMENS:
		var node: Node3D = (load(spec[0]) as PackedScene).instantiate()
		holder.add_child(node)
		for i in 3:
			await physics_frame
		# 50 life: 1 damage leaves it alive, 49 more kills it.
		node.damage(1.0)
		if not is_instance_valid(node):
			fails.append(spec[1] + "_died_too_easy")
			continue
		# Read the death spot *after* that first hit: animals are now shoved away
		# from the attacker when hit, so the pre-hit position is stale.
		var pos: Vector3 = node.global_position
		node.damage(49.0)
		for i in 5:
			await process_frame
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			fails.append(spec[1] + "_survived")
		# A DeathPuff should now exist near the death spot.
		var puff_found := false
		for n in holder.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).contains("death_puff"):
				if n.global_position.distance_to(pos) < 1.0:
					puff_found = true
		if not puff_found:
			fails.append(spec[1] + "_no_puff")
	holder.queue_free()
	for i in 60:
		await process_frame

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
