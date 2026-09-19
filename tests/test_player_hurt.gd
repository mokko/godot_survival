extends SceneTree
## Headless check: taking damage is legible and not chain-able. The player
## flashes red, plays a hurt sound, gets INVULN_TIME of grace so a single enemy
## cannot bite through a whole life bar, armour still absorbs its share first,
## and the flash fades back out.

const INVULN_TIME := 0.6


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _init() -> void:
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var fails: PackedStringArray = []

	if player._hurt_rect == null:
		fails.append("no_hurt_flash_node")
	if player._snd_hurt == null or player._snd_hurt.stream == null:
		fails.append("no_hurt_sound")

	# 1. A hit: life drops by the full amount, flash lights, grace starts.
	var life0: float = player.life
	player.damage(10.0)
	if not is_equal_approx(player.life, life0 - 10.0):
		fails.append("wrong_damage")
	if player.hurt_flash_alpha() < 0.4:
		fails.append("no_flash_on_hit")
	if not player.is_invulnerable():
		fails.append("no_invulnerability_window")

	# 2. Grace: a second hit in the same window does nothing at all.
	var life1: float = player.life
	player.damage(10.0)
	if not is_equal_approx(player.life, life1):
		fails.append("chained_damage")

	# 3. Grace expires: damage lands again.
	await _wait(INVULN_TIME + 0.2)
	var life2: float = player.life
	player.damage(10.0)
	if not is_equal_approx(player.life, life2 - 10.0):
		fails.append("no_damage_after_grace")

	# 4. The flash fades back out (it must not stay lit forever).
	await _wait(0.6)
	if player.hurt_flash_alpha() > 0.0:
		fails.append("flash_never_faded")

	# 5. Armour still absorbs first: 30% of 10 is eaten, durability drops.
	await _wait(INVULN_TIME + 0.2)
	player.add_item("leather_armor")
	if not player.equip_armor("leather_armor"):
		fails.append("armor_not_equipped")
	var life3: float = player.life
	player.damage(10.0)
	if not is_equal_approx(player.life, life3 - 7.0):
		fails.append("armor_did_not_absorb")
	if player.armor_status()["durability"] >= 80.0:
		fails.append("armor_did_not_degrade")

	# 6. Death still works through the grace window: armour off, big hit.
	await _wait(INVULN_TIME + 0.2)
	player.life = 5.0
	player.damage(50.0)
	await _wait(0.2)
	if not player._game_over:
		fails.append("no_death_on_lethal_hit")

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)