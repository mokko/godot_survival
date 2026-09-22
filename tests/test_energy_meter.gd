extends SceneTree
## Headless check: the HUD energy meter — four batteries drawn full, half or
## empty from the player's life, and the idle drain that feeds them.
## - the half/full rule (charge_of / filled_halves) is a static, tested directly
## - main.tscn shows the meter and no longer the "Life: %d" label
## - the player pushes its life into the meter every frame
## - the drain is the slow one: ~0.25/s, so a full tank lasts 160 s, not 40
## - a sunbulb restores 15 but never past a full tank

const Meter := preload("res://ui/energy_meter.gd")
const PlayerScript := preload("res://player/player.gd")
const MAX := 40.0   # player.START_LIFE — the meter's full tank (asserted below)


func _charge(value: float, index: int) -> float:
	return Meter.charge_of(value, MAX, index)


func _all_full(value: float) -> bool:
	for i in Meter.BATTERIES:
		if _charge(value, i) != 1.0:
			return false
	return true


func _init() -> void:
	var fails: PackedStringArray = []

	# 1. The rule. Four batteries, eight half-charges, rounding UP to the next
	#    half (one point left still shows half a battery).
	if Meter.BATTERIES != 4:
		fails.append("battery_count=%d" % Meter.BATTERIES)
	if int(MAX) % Meter.BATTERIES != 0:
		fails.append("uneven_quarters")   # the tank must divide into 4
	# The tank the meter is fed and the one the player starts with must agree,
	# or the batteries would show a full tank as less than full.
	if absf(float(PlayerScript.START_LIFE) - MAX) > 0.01:
		fails.append("tank_mismatch=%d" % PlayerScript.START_LIFE)
	if not _all_full(MAX) or not _all_full(37.0):
		fails.append("full_tank")
	var expect := {
		35.0: [1.0, 1.0, 1.0, 0.5],
		30.0: [1.0, 1.0, 1.0, 0.0],
		10.0: [1.0, 0.0, 0.0, 0.0],
		5.0: [0.5, 0.0, 0.0, 0.0],
		0.4: [0.5, 0.0, 0.0, 0.0],
		0.0: [0.0, 0.0, 0.0, 0.0],
	}
	for value in expect:
		for i in Meter.BATTERIES:
			if _charge(value, i) != expect[value][i]:
				fails.append("charge %.1f[%d]=%.1f" % [value, i, _charge(value, i)])
	if not _all_full(1000.0):
		fails.append("over_full")   # clamped, never overflowing

	# 2. The HUD: the meter is there, the two labels it replaced are not (the old
	#    `Life:` text, and the Sunbulbs counter that sat in the top-right corner),
	#    and the player pushes its life in.
	var main = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30:
		await physics_frame
	var player = main.get_node("Player")
	var meter: Control = main.get_node_or_null("HUD/EnergyMeter")
	if meter == null or not meter.is_in_group("energy_meter"):
		fails.append("meter_missing")
	if get_first_node_in_group("life_label") != null:
		fails.append("life_label_still_there")
	if get_first_node_in_group("sunbulb_label") != null:
		fails.append("sunbulb_counter_still_there")
	player.life = 35.0
	for i in 3:
		await physics_frame
	if meter != null and (absf(meter.energy - 35.0) > 0.01 or absf(meter.max_energy - MAX) > 0.01):
		fails.append("meter_not_fed=%.1f/%.1f" % [meter.energy, meter.max_energy])
	if meter != null and meter.filled_halves(35.0, MAX) != 7:
		fails.append("meter_rule_drift")

	# 3. The idle drain is the slow one. 2 s of wall clock at 0.25/s costs 0.5;
	#    the old 1.0/s would cost ~2.0 and fail the ceiling below.
	player.life = MAX
	var before: float = player.life
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		await physics_frame
	var spent: float = before - player.life
	if spent < 0.2 or spent > 0.8:
		fails.append("drain_2s=%.2f" % spent)

	# 4. Sunbulbs keep feeding the tank, but never overfill it.
	player.life = 10.0
	player.heal(PlayerScript.SUNBULB_HEAL)
	if absf(player.life - 25.0) > 0.01:
		fails.append("heal_10=%.1f" % player.life)
	player.life = 35.0
	player.heal(PlayerScript.SUNBULB_HEAL)
	if absf(player.life - MAX) > 0.01:
		fails.append("heal_35=%.1f" % player.life)

	if fails.is_empty():
		print("RESULT ALL PASS")
		quit(0)
	else:
		print("RESULT FAIL: ", ", ".join(fails))
		quit(1)
