extends "res://items/item_pickup.gd"
## A katana lying on the ground: the look of the sword pickup.
##
## `items/item_pickup.gd` is the *behaviour* — walk into it, it goes to the bag, it
## hides itself — and it is shared by every pickable thing in the world. Its own look
## is a tinted cube, which is right for a flint shard and wrong for the blade the first
## fight depends on: a cube could be anything, and the one sword on the spawn beach
## should say *sword* from across the grass. So the base class keeps the rules and this
## file replaces `_apply_look()` with a real prop.
##
## It lies unsheathed beside its saya (scabbard), on its edge, handle toward whoever is
## walking up — the whole silhouette is the point, so it is built long and low and the
## blade's edge is a brighter strip of its own. One merged, vertex-coloured surface
## (`world/prop_mesh.gd`), the boat's/bench's/crate's rule, plus the same faint glow a
## pickup needs to be found in grass at all.
##
## Where a katana lies is `world/main.tscn`: the one on Ezo's SW cape (`Pickup15`, a
## short walk from the spawn) and the one up on the massif (`Pickup6`). Both positions
## are on the terrain — see `world/kit.md`.
##
## Picking it up is also one of the run's **screens**: `ui/story_text.gd`'s `katana`
## milestone, played through the HUD's story screen. Any katana plays it, on purpose — the
## page is about recognising a sword for what it is, not about that particular blade.

const PropMesh := preload("res://world/prop_mesh.gd")

## Blade steel and its edge, then the dark fittings, the handle wrap and the black
## lacquer of the saya.
const STEEL := Color(0.7, 0.74, 0.8)
const EDGE := Color(0.93, 0.95, 0.98)
const FITTING := Color(0.22, 0.23, 0.26)
const WRAP := Color(0.17, 0.15, 0.14)
const SAYA := Color(0.11, 0.12, 0.15)

## The blade lies along **+X** with the handle toward -X, so the scene's own yaw
## decides which way it points. Everything sits just above the node's origin: the node
## is placed at the terrain's height, and the sword lies on it.
const BLADE_LENGTH := 0.6


func _on_body_entered(body: Node) -> void:
	## The base class collects it (`items/item_pickup.gd`); this adds the one thing a
	## *sword* does that a flint shard does not — picking it up is one of the run's
	## screens. Watched through the base class's own flag rather than re-testing the body,
	## so "what counts as collected" keeps exactly one definition.
	var was_collected: bool = _collected
	super._on_body_entered(body)
	if was_collected or not _collected:
		return
	var scene := get_tree().current_scene
	var story: Node = null
	if scene != null:
		story = scene.get_node_or_null("HUD/StoryScreen")
	if story != null and story.has_method("play_milestone"):
		story.play_milestone("katana")


func _apply_look() -> void:
	## Replaces the base class's tinted cube (its `_apply_look()` looks for a child
	## named "Mesh"; this build does not use one).
	var blade := BoxMesh.new()
	blade.size = Vector3(BLADE_LENGTH, 0.042, 0.016)
	var edge := BoxMesh.new()
	edge.size = Vector3(BLADE_LENGTH, 0.01, 0.02)
	var tip := BoxMesh.new()
	tip.size = Vector3(0.1, 0.03, 0.014)
	var habaki := BoxMesh.new()
	habaki.size = Vector3(0.05, 0.055, 0.03)
	var guard := CylinderMesh.new()
	guard.top_radius = 0.055
	guard.bottom_radius = 0.055
	guard.height = 0.014
	guard.radial_segments = 12
	var handle := BoxMesh.new()
	handle.size = Vector3(0.24, 0.04, 0.032)
	var pommel := BoxMesh.new()
	pommel.size = Vector3(0.035, 0.048, 0.04)
	var saya := BoxMesh.new()
	saya.size = Vector3(0.78, 0.05, 0.05)
	var kojiri := BoxMesh.new()
	kojiri.size = Vector3(0.05, 0.04, 0.042)
	# The guard lies across the blade's base; its own radius is what touches the
	# ground, so its centre rides higher than the blade's.
	var guard_axis := Basis(Vector3.BACK, PI * 0.5)
	var parts := [
		[blade, Transform3D(Basis(), Vector3(0.33, 0.028, 0)), STEEL],
		[edge, Transform3D(Basis(), Vector3(0.33, 0.011, 0)), EDGE],
		[tip, Transform3D(Basis(), Vector3(0.675, 0.026, 0)), STEEL],
		[habaki, Transform3D(Basis(), Vector3(0.045, 0.03, 0)), FITTING],
		[guard, Transform3D(guard_axis, Vector3(0.0, 0.058, 0)), FITTING],
		[handle, Transform3D(Basis(), Vector3(-0.15, 0.03, 0)), WRAP],
		[pommel, Transform3D(Basis(), Vector3(-0.29, 0.03, 0)), FITTING],
		# The scabbard, dropped beside it: the pair is what says "a sword was left
		# here" rather than "a blade was left here".
		[saya, Transform3D(Basis(), Vector3(-0.16, 0.026, 0.078)), SAYA],
		[kojiri, Transform3D(Basis(), Vector3(0.19, 0.026, 0.078)), SAYA],
	]
	var look := MeshInstance3D.new()
	look.name = "Katana"
	look.mesh = PropMesh.merge(parts)
	# The faint glow every pickup has (items/item_pickup.gd puts its cube at 0.35):
	# a sword this low in the grass is otherwise invisible from the distance the
	# player finds it at.
	var mat := PropMesh.paint()
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.64, 0.7)
	mat.emission_energy_multiplier = 0.3
	look.material_override = mat
	add_child(look)