extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.72   # 4.5 * sqrt(1.1): peak height scales with the
                             # square of the launch velocity, so +10% height
const START_LIFE = 40
## Energy drain per second just for being switched on — the idle cost of
## running around. 0.25/s gives a 160 s tank (the four batteries are 40 s each),
## with sunbulbs adding 15 (1.5 batteries) back. It was 1.0/s, which emptied a
## full tank in 40 s and made the meter read as a countdown rather than a gauge.
const LIFE_DRAIN_PER_SEC = 0.25
const SUNBULB_HEAL = 15.0
const INVULN_TIME = 0.6      ## seconds of grace after a hit lands
const HURT_FLASH_FADE = 2.5  ## alpha per second on the damage flash
const HIT_MARKER_TIME := 0.16  ## how long the "you connected" tick shows
## What a NEW run begins with, handed out in _ready (splash Start → story →
## here). The katana is there so the fight can be met on the first stroll
## instead of after a crafting chain; the Pedia notebook, the pen and the
## magnifying glass are the survey — the notes are the drone's own work, so the
## tools that make them are carried from the first minute. The binoculars are the
## spotting tool: they name what is out there, they write nothing down.
## Add to the list, or empty it once the intro hands out gear of its own.
const STARTING_ITEMS := ["sword", "notebook", "pen", "magnifying_glass", "binoculars"]
## Items the drone never loses, death included: its own record of the island and
## the tools that fill it (the notebook, the pen that writes in it, the glass the
## drawings are made through). Handed back on respawn, because there is no other
## way to get them and a handbook you can drop forever is a handbook with a hole
## in it. The katana and the binoculars are ordinary gear and are lost with the
## rest of the loot.
const KEEPSAKE_ITEMS := ["notebook", "pen", "magnifying_glass"]
const SAVEGAME := preload("res://world/savegame.gd")
const Notes := preload("res://ui/pedia_notes.gd")
const PediaArt := preload("res://ui/pedia_art.gd")
## How close the drone has to be to an island for it to be written into the
## notebook: a mooring off its coast counts, so the boat route fills the Islands
## chapter as you sail it.
const ISLAND_DISCOVERY := 60.0
const DISCOVERY_INTERVAL := 0.5   ## seconds between discovery polls
const MOUSE_SENSITIVITY = 0.002
const ZOOM_SPEED = 5.0
const FOV_MIN = 50.0
const FOV_MAX = 150.0
const FOV_DEFAULT = 75.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var life: float = START_LIFE
var _drain_accum: float = 0.0
var _discovery_timer: float = 0.0   ## counts down to the next notebook poll
## Counts up to the next autosave (SaveGame.AUTOSAVE_SECONDS). Only a living
## run rotates the autosave slot: a dead one has nothing worth keeping.
var _autosave_clock: float = 0.0
var _game_over: bool = false
var sunbulbs_collected: int = 0
var _held_block: MovableBlock = null
var _invuln: float = 0.0     ## counts down; damage() is ignored while > 0
var _hurt_layer: CanvasLayer = null
var _hurt_rect: ColorRect = null
var _snd_hurt: AudioStreamPlayer = null
var _hit_marker: Control = null
var _hit_marker_left := 0.0
const InventoryScene := preload("res://ui/inventory.tscn")
@onready var inventory: Control = get_tree().get_first_node_in_group("inventory")
@onready var equipment: Node3D = $Equipment
@onready var combat: Node3D = $Combat
@onready var study: Node3D = $Study

var _snd_jump: AudioStreamPlayer
var _snd_land: AudioStreamPlayer
var _snd_slash: AudioStreamPlayer
var _snd_step: AudioStreamPlayer
var _snd_grab: AudioStreamPlayer
var _snd_drop: AudioStreamPlayer
var _snd_punch: AudioStreamPlayer
var _was_on_floor := true
var _step_accum := 0.0

const STEP_INTERVAL := 0.35   # seconds between footsteps while walking

func _make_snd(path: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p


func save_state() -> Dictionary:
	## Everything a Load Game needs to restore.
	var state := {
		"pos": [global_position.x, global_position.y, global_position.z],
		"life": life,
		"sunbulbs": sunbulbs_collected,
		"items": inventory.slots.duplicate() if inventory != null else [],
		"counts": inventory.counts.duplicate() if inventory != null else [],
		"equipped": inventory.equipped_slot if inventory != null else -1,
		"armor": combat.armor_id,
		"armor_durability": combat.armor_durability,
		"notes": Notes.drawn(),
	}
	# Time of day lives on the DayCycle node (a sibling), not on the player.
	var cycle := get_node_or_null("../DayCycle")
	if cycle != null:
		state["time_of_day"] = cycle.time_of_day
	return state


func load_state(data: Dictionary) -> void:
	## Restore from a savegame Dictionary (missing/invalid keys ignored).
	life = float(data.get("life", START_LIFE))
	sunbulbs_collected = int(data.get("sunbulbs", data.get("orbs", 0)))
	var pos: Array = data.get("pos", [])
	if pos.size() == 3:
		var restored := Vector3(pos[0], pos[1], pos[2])
		if not Ezo.is_land(restored.x, restored.z):
			# Saved while sailing. Land within 40 units (coastal water) means we can
			# put the player safely ashore near where they were; out in open sea
			# there is nothing to snap to, so fall back to the start point — the
			# saved position is lost, but loading must never drop the player into
			# the water, where the sea floor has no collision.
			var shore: Vector3 = Ezo.nearest_land_point(
					Vector2(restored.x, restored.z), 40.0)
			restored = shore if shore != Vector3.INF else Ezo.spawn_point()
		global_position = restored
		velocity = Vector3.ZERO
	# Put the sun back where it was: loading an evening save at noon broke the
	# day/night illusion (and with it the glow plants and light budget).
	var cycle := get_node_or_null("../DayCycle")
	if cycle != null and data.has("time_of_day"):
		cycle.time_of_day = clampf(float(data["time_of_day"]), 0.0, 1.0)
	if inventory != null:
		var items: Array = data.get("items", [])
		var cnts: Array = data.get("counts", [])
		inventory.restore(items, cnts)
		inventory.equipped_slot = -1
		var eq := int(data.get("equipped", -1))
		if eq >= 0 and eq < inventory.SLOTS and inventory.slots[eq] != "":
			inventory.equip(eq)
		else:
			inventory.refresh()
	# The notebook comes back with the run: what was drawn stays drawn.
	Notes.restore(data.get("notes", []))
	# Armor lives on the combat node, not the inventory, so restore it even
	# if the inventory could not be resolved this early.
	var saved_armor := str(data.get("armor", ""))
	if saved_armor != "":
		combat.load_armor_state(saved_armor,
				float(data.get("armor_durability", 0.0)))
		if inventory != null:
			inventory.set_worn(saved_armor)
			inventory.refresh()
	_update_hud()


## Node and group references. These are assigned before _ready() runs, so they
## belong with the other members — declared after _ready() they read like a bug.
@onready var energy_meter: Control = get_tree().get_first_node_in_group("energy_meter")
@onready var game_over_label: CanvasItem = get_tree().get_first_node_in_group("game_over_label")
@onready var enemy_label: Label = get_tree().get_first_node_in_group("enemy_label")
@onready var camera: Camera3D = $Camera3D
@onready var pickup_sound: AudioStreamPlayer = $AudioStreamPlayer
@onready var game_over_sound: AudioStreamPlayer = $GameOverSound
@onready var fade_in: CanvasLayer = get_node_or_null("../FadeIn")
@onready var pause_menu: Control = get_node_or_null("../HUD/PauseMenu")

var _input_locked := false
## The boat the player is riding, if any (world/boat.gd sets this through
## board_boat()). While set, the boat owns our position and velocity.
var _boat: Node3D = null

signal pause_requested


func _ready() -> void:
	_snd_jump = _make_snd("res://sounds/jump.wav", -8.0)
	_snd_land = _make_snd("res://sounds/land.wav", -6.0)
	_snd_step = _make_snd("res://sounds/step.wav", -18.0)
	_snd_grab = _make_snd("res://sounds/grab.wav", -10.0)
	_snd_slash = _make_snd("res://sounds/slash.wav", -6.0)
	_snd_drop = _make_snd("res://sounds/drop.wav", -10.0)
	# Reuses the flopp thump: it reads as a jab landing and there is no
	# dedicated punch sample in sounds/.
	_snd_punch = _make_snd("res://sounds/flopp.wav", -14.0)
	_snd_hurt = _make_snd("res://sounds/hurt.wav", -5.0)
	_build_hurt_flash()
	_build_hit_marker()
	_update_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = FOV_DEFAULT
	if pause_menu != null:
		pause_requested.connect(pause_menu.open)
	if inventory != null:
		inventory.armor_changed.connect(_on_armor_changed)
		inventory.item_equipped.connect(_on_item_equipped)
	combat.armor_changed.connect(_on_combat_armor_changed)
	# Load Game / Start Game hand-off: Load Game restores a saved game exactly
	# once, when launched from the splash screen's Load Game button; Start Game
	# hands out the starting loadout instead.
	if SAVEGAME.take_pending_load():
		# Which slot the splash asked for (0 = whatever this player played last).
		SaveGame.current_slot = SAVEGAME.take_pending_slot()
		load_state(SAVEGAME.read_slot(SaveGame.current_slot))
	elif SAVEGAME.take_pending_new_run():
		# A fresh run starts with an empty notebook. It refills from what the
		# drone is handed (equipment), where it wakes up (islands) and what it
		# studies (plants, animals) — see _update_notes() and player/study.gd.
		Notes.clear()
		give_starting_items()
	_update_notes()


func give_starting_items() -> void:
	## The loadout a new run begins with (STARTING_ITEMS). add_item() auto-equips
	## the first slot, which is what raises the katana into the drone's hand —
	## the equip signal is already connected above, so the prop and the flourish
	## follow on their own.
	for item_id in STARTING_ITEMS:
		add_item(item_id)


func _build_hurt_flash() -> void:
	## Red vignette-ish flash on taking damage. Built in code rather than in
	## main.tscn: the HUD scene is edited by hand in the editor, and a code-side
	## overlay cannot be clobbered by an editor save.
	_hurt_layer = CanvasLayer.new()
	_hurt_layer.layer = 5   # above the HUD labels, below the fade overlay
	add_child(_hurt_layer)
	_hurt_rect = ColorRect.new()
	_hurt_rect.color = Color(0.75, 0.04, 0.04, 0.0)
	_hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_layer.add_child(_hurt_rect)


func _build_hit_marker() -> void:
	## Four short ticks around the crosshair, shown only when a swing actually
	## connects with something. Before this the only feedback was the swing
	## trail, which plays on every click — so a miss looked like a hit.
	## Code-built for the same reason as the hurt flash: main.tscn stays the
	## editor's to edit.
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hit_marker = Control.new()
	_hit_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hit_marker)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tick := ColorRect.new()
		tick.color = Color(1.0, 1.0, 1.0, 0.0)
		tick.size = Vector2(2, 9)
		tick.set_anchors_preset(Control.PRESET_CENTER)
		tick.position = corner * 8.0 + Vector2(-1, -5)
		tick.rotation = corner.x * corner.y * 0.0 + (0.7853981 if corner.x * corner.y < 0 else -0.7853981)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hit_marker.add_child(tick)


func show_hit_marker() -> void:
	## Called by combat when a swing lands on something.
	_hit_marker_left = HIT_MARKER_TIME


func hit_marker_alpha() -> float:
	## 0..1 opacity of the marker ticks; 0 means nothing is showing.
	if _hit_marker == null or _hit_marker.get_child_count() == 0:
		return 0.0
	return (_hit_marker.get_child(0) as ColorRect).color.a


func _tick_hit_marker(delta: float) -> void:
	if _hit_marker == null:
		return
	_hit_marker_left = maxf(_hit_marker_left - delta, 0.0)
	# Snap on at full strength, then go: a fade-in would read as a soft glow
	# rather than as a click of confirmation.
	var a: float = minf(_hit_marker_left / HIT_MARKER_TIME, 1.0) * 0.9
	for tick in _hit_marker.get_children():
		(tick as ColorRect).color = Color(1.0, 1.0, 1.0, a)


func _tick_hurt(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	if _hurt_rect != null and _hurt_rect.color.a > 0.0:
		var a := maxf(_hurt_rect.color.a - delta * HURT_FLASH_FADE, 0.0)
		_hurt_rect.color = Color(0.75, 0.04, 0.04, a)


func hurt_flash_alpha() -> float:
	## HUD flash level, 0..1. Read by the HUD/tests.
	return _hurt_rect.color.a if _hurt_rect != null else 0.0


func is_invulnerable() -> bool:
	return _invuln > 0.0


func add_item(item_id: String) -> bool:
	## Pickups call this: insert into the first free inventory slot.
	if inventory == null:
		# Fallback: HUD wasn't ready yet — create it under the HUD layer.
		var hud: CanvasLayer = get_node_or_null("../HUD")
		if hud != null:
			inventory = InventoryScene.instantiate()
			hud.add_child(inventory)
	if inventory == null:
		return false
	var ok: bool = inventory.add_item(item_id)
	if ok:
		_snd_grab.play()
		# A piece picked up is a whole one. Wear is remembered per item id, so
		# without this a new piece would inherit the state of a broken one already
		# in the bag.
		combat.reset_wear(item_id)
	return ok


func get_equipped_item() -> String:
	if inventory != null:
		return inventory.get_equipped_item()
	return ""

func _lock_check() -> bool:
	# Live check: the fade overlay clears its own flag when done.
	if fade_in != null:
		_input_locked = fade_in.input_locked
	return _input_locked


func _unhandled_input(event: InputEvent) -> void:
	if _lock_check():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw the player (rotate around Y).
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Pitch the camera (rotate around X), clamp to avoid flipping.
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.2, 1.2)

	# Scroll wheel zoom.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = max(camera.fov - ZOOM_SPEED, FOV_MIN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = min(camera.fov + ZOOM_SPEED, FOV_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if get_equipped_item() == "sword":
				do_slash()
			elif study.instrument() != "":
				# Binoculars or magnifying glass out: a click looks at what the
				# crosshair is on — spot it, or start drawing it. The drone does
				# not punch or grab while a tool is held up.
				do_study()
			elif not _toggle_grab():
				# Nothing to grab under the crosshair and no weapon equipped:
				# the drone jabs instead of clicking at thin air.
				do_punch()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_begin_draw_bow()
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_release_bow()

	# ESC: restart on the death screen, otherwise toggle the pause menu.
	# Deliberately NOT gated on mouse mode: if capture ever fails (window
	# focus loss, Wayland quirks), ESC must still open the menu.
	if event.is_action_pressed("ui_cancel"):
		if _game_over:
			_restart()
		else:
			pause_requested.emit()
			# Stop the SAME event from reaching the pause menu's own ESC
			# handler, which would instantly resume (open+close race).
			get_viewport().set_input_as_handled()


## Crosshair interaction: grab or release the block under the crosshair.
## Returns true when it actually grabbed or dropped a block, so the caller can
## fall back to an unarmed punch when there was nothing to interact with.
func _toggle_grab() -> bool:
	if _held_block != null:
		_held_block.release()
		_held_block = null
		_snd_drop.play()
		return true
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			camera.global_position,
			camera.global_position - camera.global_transform.basis.z * 5.0)
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit["collider"]
	if collider is MovableBlock:
		_held_block = collider
		_held_block.grab(camera)
		_snd_grab.play()
		return true
	return false


func do_punch() -> void:
	## Unarmed left click: the drone throws a jab, and the jab lands — combat
	## runs the katana's cone check with the bare-hand damage from the weapon
	## table (the default branch of Weapon.damage_of, 5.0). It was visual and
	## audible only, which read in game as "this animal cannot be hurt".
	## A jab on cooldown neither swings nor thumps, so a held click cannot
	## out-damage the katana.
	if not combat.try_punch():
		return
	if equipment != null:
		equipment.play_punch()
	_snd_punch.play()

## ----------------------------------------------------------------- katana slash

func do_slash() -> void:
	combat.try_slash()


func do_study() -> void:
	## Binoculars out: a left click starts drawing whatever the crosshair is on.
	## The session itself lives in player/study.gd (aim, hold, and the unlock).
	study.begin()


## -------------------------------------------------------- the notebook's notes

func _update_notes() -> void:
	## What the notebook records without studying: what the drone is carrying
	## (Equipment) and where it is standing (Islands). Species are the other way
	## round — they only go in by being studied (player/study.gd).
	if inventory != null:
		for i in inventory.SLOTS:
			if inventory.slots[i] != "" and inventory.counts[i] > 0:
				Notes.unlock("equipment", inventory.slots[i])
	var here := Vector2(global_position.x, global_position.z)
	for island_id in ["ezo", "honshu", "shikoku", "kyushu"]:
		if PediaArt.island_distance(island_id, here) <= ISLAND_DISCOVERY:
			Notes.unlock("islands", island_id)


func play_slash_sound() -> void:
	_snd_slash.play()


# --------------------------------------------------------------------- bow shooting

func _on_item_equipped(slot: int) -> void:
	if equipment != null and inventory != null:
		equipment.show_for_equipped(inventory.get_equipped_item())
		equipment.play_flourish()


func _on_armor_changed(armor_id: String, _durability: float) -> void:
	## UI path: inventory emits when the player presses E on an armor slot. Only the
	## id is used — the durability it carries is the armour table's pristine value —
	## because combat is the thing that remembers what a piece has left.
	combat.wear_from_inventory(armor_id)


func _on_combat_armor_changed(armor_id: String, durability: float) -> void:
	## Combat node armor state changed (degraded/broken/equipped): sync visuals.
	if equipment != null:
		equipment.show_armor(armor_id != "")
		equipment.play_flourish()
	if inventory != null:
		inventory.worn_armor_id = armor_id
	_update_hud()


func has_bow() -> bool:
	return combat.has_bow()


func has_arrows() -> bool:
	return combat.has_arrows()


func equip_armor(item_id: String) -> bool:
	return combat.equip_armor(item_id)


func armor_status() -> Dictionary:
	return combat.armor_status()


func _begin_draw_bow() -> void:
	combat.begin_draw_bow()


func _release_bow() -> void:
	combat.release_bow()


func play_grab_sound() -> void:
	_snd_grab.play()


func _physics_process(delta: float) -> void:
	_tick_hurt(delta)
	_tick_hit_marker(delta)
	if _game_over:
		# Dead: show game-over screen, wait for ESC to restart at spawn.
		return

	# Rotate the autosave every AUTOSAVE_SECONDS (300, the fifth slot). Same file
	# every time, so a crash can only cost the player the last five minutes.
	_autosave_clock += delta
	if _autosave_clock >= SaveGame.AUTOSAVE_SECONDS:
		_autosave_clock = 0.0
		SaveGame.autosave(self)

	# Drain energy steadily (LIFE_DRAIN_PER_SEC, a quarter point a second).
	_drain_accum += delta
	while _drain_accum >= 1.0:
		life -= LIFE_DRAIN_PER_SEC
		_drain_accum -= 1.0
		if life <= 0.0:
			life = 0.0
			_trigger_game_over()
	_update_hud()

	# Discovery poll: what the drone carries and which island it is on get written
	# into the notebook. Half a second is plenty — this is not a reflex.
	_discovery_timer = maxf(_discovery_timer - delta, 0.0)
	if _discovery_timer <= 0.0:
		_discovery_timer = DISCOVERY_INTERVAL
		_update_notes()

	# Fell off the map (into the sea / off the terrain): die immediately
	# and respawn at the start point. Ground is never below y = -4, and the
	# seafloor sits around -3.5, so anything under -8 is off the map.
	if global_position.y < -8.0:
		_fall_death()

	if _boat != null:
		# Riding a boat: it pins us to its deck every frame (world/boat.gd), so no
		# walking, gravity or jumping here — the boat owns our position.
		return

	# Apply gravity when airborne.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump with Space.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _lock_check():
		velocity.y = JUMP_VELOCITY
		_snd_jump.play()

	# WASD movement relative to player facing direction.
	var input_dir := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()

	var current_speed := SPEED
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed = SPEED * 2.0

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

	# Landing sound: transition from airborne to on-floor.
	if is_on_floor() and not _was_on_floor and velocity.y <= 0.0:
		_snd_land.play()
	_was_on_floor = is_on_floor()

	# Footsteps while moving on the ground.
	if is_on_floor() and direction.length() > 0.1:
		_step_accum += delta * (2.0 if current_speed > SPEED else 1.0)
		if _step_accum >= STEP_INTERVAL:
			_step_accum = 0.0
			_snd_step.play()
	else:
		_step_accum = STEP_INTERVAL   # ready to step immediately on move


func board_boat(boat: Node3D) -> void:
	## Called by world/boat.gd when the player presses E beside a moored boat.
	_boat = boat
	velocity = Vector3.ZERO
	if _held_block != null:
		# Do not carry a grabbed block aboard: it would fight the seat-lock.
		_held_block.release()
		_held_block = null


func leave_boat() -> void:
	_boat = null
	velocity = Vector3.ZERO


func in_boat() -> bool:
	return _boat != null


func damage(amount: float) -> void:
	## Player damage route: armor (combat node) soaks its share first, then the
	## hit is telegraphed back at the player — flash + sound + a short window of
	## invulnerability so one enemy cannot chain-bite through a whole life bar.
	if _game_over or _invuln > 0.0:
		return
	var through: float = combat.absorb(amount)
	_invuln = INVULN_TIME
	if _hurt_rect != null:
		_hurt_rect.color = Color(0.75, 0.04, 0.04, 0.55)
	if _snd_hurt != null:
		_snd_hurt.play()
	_apply_damage(through)


func _apply_damage(amount: float) -> void:
	if _game_over:
		return
	life = maxf(life - amount, 0.0)
	if life <= 0.0:
		_trigger_game_over()
	else:
		_update_hud()


func heal(amount: float) -> void:
	## Restore energy only. Collection counting happens in collect_sunbulb().
	## Capped at a full tank: the meter has exactly four batteries, and energy
	## above the last one would have nowhere to show (a sunbulb picked up at
	## three batteries tops the fourth up and wastes the rest).
	life = minf(life + amount, float(START_LIFE))
	if pickup_sound:
		pickup_sound.play()
	_update_hud()


func collect_sunbulb() -> void:
	## Pickup path: heal + count the collection (sunbulb.tscn calls this).
	heal(SUNBULB_HEAL)
	sunbulbs_collected += 1
	_update_hud()


func _trigger_game_over() -> void:
	_game_over = true
	velocity = Vector3.ZERO
	# Death ends every fight: nobody keeps hunting a corpse, and the Enemy line
	# must not outlive the run.
	for node in get_tree().get_nodes_in_group("aggro_fauna"):
		if is_instance_valid(node) and node.has_method("calm_down"):
			node.calm_down()
	# Death penalty: you lose everything you were carrying — in this run. The
	# save on disk is deliberately left alone, so the last save is still there to
	# load; the wipe applies to the run you are in, not to what you had saved.
	if inventory != null:
		inventory.clear_all()
	if game_over_label:
		game_over_label.visible = true
	if game_over_sound:
		game_over_sound.play()
	# Free the mouse so player can click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_hud()


func _fall_death() -> void:
	## Fell off the map: show the game-over screen; ESC restarts at spawn.
	life = 0.0
	_trigger_game_over()


func _restart() -> void:
	_game_over = false
	life = START_LIFE
	_drain_accum = 0.0
	sunbulbs_collected = 0
	velocity = Vector3.ZERO
	camera.fov = FOV_DEFAULT
	# Respawn at the game's starting point on the SW cape.
	var spawn: Vector3 = Ezo.spawn_point()
	global_position = spawn + Vector3(0.0, 0.5, 0.0)   # small clearance so we land, not clip
	# The keepsakes come back: the death wipe takes loot, not the drone's own
	# record of the island. Carried, not held — a respawn is still back to fists.
	for item_id in KEEPSAKE_ITEMS:
		if inventory != null and not inventory.has_item(item_id):
			add_item(item_id)
	if inventory != null:
		inventory.equipped_slot = -1
		inventory.refresh()
		if equipment != null:
			equipment.show_for_equipped("")
	if game_over_label:
		game_over_label.visible = false
	# Re-capture mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Respawn all pickups (sunbulbs).
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.respawn()
	_update_hud()


var _armor_label: Label
## Last values written to the HUD. _update_hud() runs every physics frame, so
## every write is guarded: a steady frame must cost nothing and allocate
## nothing (armor_status() used to build a Dictionary 60x/s). The energy meter
## keeps its own guard — it repaints on the half-battery count, not on life.
var _hud_enemy := ""
var _hud_armor := ""
var _hud_armor_shown := true   # the Label starts visible; force a first sync


func _update_hud() -> void:
	if energy_meter != null:
		energy_meter.set_energy(life, float(START_LIFE))
	if _armor_label == null:
		var hud: CanvasLayer = get_node_or_null("../HUD")
		if hud != null:
			_armor_label = Label.new()
			# Under the energy meter (HUD/EnergyMeter, 12..190 x 13..42).
			_armor_label.position = Vector2(12, 48)
			_armor_label.add_theme_font_size_override("font_size", 14)
			hud.add_child(_armor_label)
	if _armor_label != null:
		var text := ""
		if combat.armor_id != "" and combat.armor_durability > 0.0:
			var pretty: String = combat.armor_id.replace("_", " ").capitalize()
			text = "Armor: %s (%d%%)" % [pretty, int(combat.armor_durability)]
		if text != _hud_armor:
			_hud_armor = text
			_armor_label.text = text
		var shown := text != ""
		if shown != _hud_armor_shown:
			_hud_armor_shown = shown
			_armor_label.visible = shown
	_update_enemy_hud()


func _update_enemy_hud() -> void:
	## The fight line, in the top-right corner: who is angry with us and how
	## much life it has left. It is driven entirely by the "aggro_fauna" group
	## (fauna/fauna_base.gd), so it appears with the first animal that turns on
	## the player and disappears with the last one — no fight has to end it, and
	## a killed animal takes its own line down by leaving the tree.
	if enemy_label == null:
		return
	var enemy := nearest_aggro_enemy()
	var text := ""
	if enemy != null:
		text = "Enemy: %s  %d/%d" % [
				enemy.species_name(),
				maxi(int(ceil(enemy.life)), 0),
				int(enemy.MAX_LIFE)]
	if text != _hud_enemy:
		_hud_enemy = text
		enemy_label.text = text
		enemy_label.visible = text != ""


func nearest_aggro_enemy() -> Node3D:
	## The nearest animal currently fighting us. Nearest rather than first: with a
	## herd provoked at once the line should name the one in your face.
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("aggro_fauna"):
		if not is_instance_valid(node):
			continue
		var other := node as Node3D
		var d: float = global_position.distance_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best
