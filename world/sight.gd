extends RefCounted
## Line of sight for blows.
##
## A strike (player/combat.gd) and a bite (fauna/fauna_base.gd, fauna/stalker.gd)
## both measure their reach on the ground plane alone, so without this a katana cut
## through a hill and a stalker bit through a boulder. Both now ask here before they
## land anything.
##
## Two deliberate rules:
##
##  - **Only solid bodies block.** Flat ground cover (embermoss, mirrorlily_small)
##    and specimens are Area3D-based and let a blow through, exactly as they let the
##    player walk through them.
##  - **The first thing the ray meets decides.** If that is the target itself — its
##    own body, or a collider under it — the way is clear; anything else stands in
##    between. Deciding by identity rather than by distance avoids guessing where on
##    a body the ray enters.

const CHEST := Vector3(0.0, 0.9, 0.0)    ## where a blow leaves the attacker
const CENTRE := Vector3(0.0, 0.4, 0.0)   ## and where it is aimed on the target


static func clear(from_node: Node3D, to_node: Node3D) -> bool:
	## True when nothing solid stands between the two. False when there is no world
	## to ask (a headless fixture with no physics space): refusing is the safe answer
	## for a blow, and the callers that matter always have one.
	if from_node == null or to_node == null:
		return false
	if not from_node.is_inside_tree() or not to_node.is_inside_tree():
		return false
	var world := from_node.get_world_3d()
	if world == null:
		return false
	var origin := from_node.global_position + CHEST
	var target := to_node.global_position + CENTRE
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = false   # flat cover does not block a blow
	# Only a physics body has a RID to exclude, and half the fauna are plain Node3D
	# roots with a collider child (the gull, the rippleback): calling get_rid() on
	# one of those is a runtime error, and an error inside this function silently
	# refused every bite those two species tried.
	if from_node is CollisionObject3D:
		query.exclude = [(from_node as CollisionObject3D).get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return _is_part_of(hit["collider"], to_node)


static func _is_part_of(collider: Object, node: Node3D) -> bool:
	## The collider that stopped the ray belongs to the target (the target is that
	## node, sits under it, or is one of its ancestors), so it did not "block".
	if collider == node:
		return true
	var hit_node := collider as Node
	if hit_node == null:
		return false
	return node.is_ancestor_of(hit_node) or hit_node.is_ancestor_of(node)