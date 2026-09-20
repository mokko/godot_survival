extends SceneTree
## Headless check: the fight can be met armed and the jab lands.
## - a fresh run begins with the katana (splash Start sets pending_new_run, the
##   player hands out STARTING_ITEMS in _ready); a plain test run — the flag
##   never set — still starts empty, which tests/test_inventory.gd pins down
## - the unarmed left click deals the weapon table's bare-hand damage (5) to a
##   target in front of the drone, and misses behind / out of reach
## - a jab on cooldown neither swings nor hits, so a held click cannot
##   out-damage the katana
## - the red animal (the Dusk Stalker) actually loses life to a jab and to a
##   katana swing, and flashes when hit

const SaveGame := preload("res://world/savegame.gd")


class FakeTarget extends Node3D:
	var hits := 0

	func _enter_tree() -> void:
		add_to_group("damageable")

	func damage(_amount: float, _source := "") -> void:
		hits += 1


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _init() -> void:
	var fails: PackedStringArray = []

	# 1. The fresh-run flag is a hand-off, not a switch that stays on: the
	#    second take must report false or every later scene would be armed.
	SaveGame.pending_new_run = true
	if not SaveGame.take_pending_new_run() or SaveGame.take_pending_new_run():
		fails.append("pending_new_run_once")

	# 2. A fresh run starts armed: the katana is in slot 0 and equipped, so a
	#    left click swings rather than jabs.
	SaveGame.pending_new_run = true
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var inv = main.get_node("HUD/Inventory")
	if inv.slots[0] != "sword" or player.get_equipped_item() != "sword":
		fails.append("starting_loadout slot=%d held=%s"
				% [inv.equipped_slot, player.get_equipped_item()])

	# 3. The jab lands on what is in front of the drone. Unarmed, as a left
	#    click with no sword equipped finds the player.
	inv.clear_all()
	var fwd: Vector3 = (-player.global_transform.basis.z).normalized()
	var front := FakeTarget.new()
	front.position = player.global_position + fwd * 1.2
	var behind := FakeTarget.new()
	behind.position = player.global_position - fwd * 1.2
	var far := FakeTarget.new()
	far.position = player.global_position + fwd * 3.0
	for t in [front, behind, far]:
		root.add_child(t)
	await _wait(0.1)
	player.do_punch()
	if front.hits != 1:
		fails.append("punch_hit=%d" % front.hits)
	if behind.hits != 0 or far.hits != 0:
		fails.append("punch_reach behind=%d far=%d" % [behind.hits, far.hits])

	# 4. Cooldown: a jab asked for in the same breath is refused, so holding
	#    the button cannot turn the fist into a machine gun.
	if player.combat.try_punch():
		fails.append("punch_cooldown_swing")
	if front.hits != 1:
		fails.append("punch_cooldown_hit=%d" % front.hits)
	await _wait(0.5)
	if not player.combat.try_punch():
		fails.append("punch_ready_again")
	if front.hits != 2:
		fails.append("punch_second=%d" % front.hits)

	# 5. The red animal takes the jab: a Dusk Stalker loses the bare-hand 5 and
	#    flashes. This is the case the user reported — the jab used to be
	#    animation and sound only, so the animal could not be hurt at all.
	#    Order matters: clear the jab cooldown FIRST, then place the animal and
	#    strike within a couple of frames. A stalker that chases closes 7.5 m a
	#    second, and one adopted by world origin instead (placed after it
	#    entered the tree) simply patrols out of a 1.8 m reach.
	await _wait(0.5)
	var stalker: Node3D = (load("res://fauna/stalker.tscn") as PackedScene).instantiate()
	stalker.position = player.position + fwd * 1.5
	main.add_child(stalker)
	for i in 3:
		await physics_frame
	var before: float = stalker.life
	player.do_punch()
	if absf(stalker.life - (before - 5.0)) > 0.01:
		fails.append("stalker_punch=%.1f" % (before - stalker.life))
	if stalker._flash <= 0.0:
		fails.append("stalker_no_flash")

	# 6. The katana goes through the same cone: 25 a swing.
	player.add_item("sword")
	inv.equip(0)
	await _wait(0.1)
	stalker.position = player.position + fwd * 1.5
	for i in 3:
		await physics_frame
	before = stalker.life
	player.do_slash()
	await _wait(0.6)          # damage lands at mid-swing (player/slash.gd)
	if absf(stalker.life - (before - 25.0)) > 0.01:
		fails.append("stalker_slash=%.1f" % (before - stalker.life))

	for t in [front, behind, far]:
		t.queue_free()
	stalker.queue_free()

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
