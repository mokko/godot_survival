class_name Fauna
extends "res://items/destroyable.gd"
## Shared behaviour for the island's animals (fauna/*.gd): a species keeps its
## own ambient movement until the player hurts it, and from that moment it fights
## back — charging without its usual territory or sight leash and landing blows
## of its own — until it dies, loses the player past AGGRO_LEASH, or cannot
## physically reach them at all.
##
## The fight IS group membership: "aggro_fauna" holds exactly the animals that
## are angry right now, and player.gd reads that group to write the HUD's Enemy
## line. Nothing has to remember to end a fight, and nothing has to tell the HUD.
##
## Species override the small hooks below (name, speed, reach, damage, gait)
## instead of re-implementing the fight, so a hit means the same thing to all six.

const GROWL := preload("res://sounds/growl.wav")
const PediaSpecies := preload("res://ui/pedia_species.gd")
const Carcass := preload("res://items/carcass.gd")
const Weapon := preload("res://items/weapon.gd")
const Sight := preload("res://world/sight.gd")

const AGGRO_LEASH := 30.0   ## metres at which the animal starts losing you
const GIVE_UP_TIME := 5.0   ## seconds out of leash before the fight ends
const GROWL_DB := -6.0
const CHARGE_BODY_Y := 0.5  ## what the default gait keeps between body and ground

var _aggro := false
var _last_source := ""      ## item id of the last blow taken (the specimen rule)
var _lost_time := 0.0       ## counts up while the player is out of reach
var _attack_cd := 0.0       ## counts down between blows
var _snd_aggro: AudioStreamPlayer = null


## ---------------------------------------------------------------- species hooks
## What a species says about itself. The defaults describe a generic
## medium-sized land animal, so a new creature only states what is different.

func species_name() -> String:
	return "Animal"

func aggro_speed() -> float:
	return 4.0

func aggro_reach() -> float:
	return 1.7      ## metres inside which the blow lands

func aggro_damage() -> float:
	return 4.0

func aggro_cooldown() -> float:
	return 1.2      ## seconds between blows


## ------------------------------------------------------------------- the fight

func is_aggro() -> bool:
	return _aggro


func aggro_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func provoke() -> void:
	## The player hurt us: arm the fight. One entry point for every animal, so
	## "I hit it and it came at me" is a property of being fauna rather than of
	## each species remembering to implement it.
	if not _aggro:
		_aggro = true
		add_to_group("aggro_fauna")
		_on_aggro()
	_lost_time = 0.0


func calm_down() -> void:
	## The fight is over: back to the ambient behaviour. Dropping the group
	## membership is what takes the HUD line down when we were the last angry
	## animal.
	if not _aggro:
		return
	_aggro = false
	remove_from_group("aggro_fauna")
	_on_calm()


func damage(amount: float, source := "") -> void:
	## Everything that can hurt us arrives here (katana, jab, arrow), so this is
	## where being attacked becomes a fight. The hit that kills is not a fight —
	## a corpse does not aggro. `source` is remembered for _die(): it decides
	## whether there is a specimen left to examine.
	_last_source = source
	super.damage(amount, source)
	if life <= 0.0 or is_queued_for_deletion():
		return
	provoke()


func _die() -> void:
	## A bladed kill leaves something to examine; an arrow or a fist does not. The
	## notebook only records what the drone could actually get a look at, which is
	## why the katana and the tanto are also the surveyor's tools.
	if Weapon.has_blade(_last_source):
		_leave_specimen()
	super._die()


func _leave_specimen() -> void:
	var record := PediaSpecies.of_node(self)
	if record.is_empty():
		return
	Carcass.spawn(get_parent(), global_position, record["chapter"], record["id"],
			record["name"])


func _aggro_tick(delta: float) -> void:
	## Timers, leash and the calm-down. Every species calls this each physics
	## frame; whether the fight then owns the frame is up to the species (the
	## ambient ones return early through aggro_frame(), the stalker runs its own
	## state machine alongside).
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if not _aggro:
		return
	var player := aggro_player()
	if player == null:
		calm_down()
		return
	if _losing_sight(player):
		_lost_time += delta
		if _lost_time >= GIVE_UP_TIME:
			calm_down()
		return
	_lost_time = 0.0


func aggro_frame(delta: float) -> bool:
	## For the ambient species: true when the fight owns this frame, so their
	## idle wandering must not also run.
	_aggro_tick(delta)
	if not _aggro:
		return false
	var player := aggro_player()
	if player == null:
		return false
	_aggro_process(delta, player)
	return true


func _aggro_process(delta: float, player: Node3D) -> void:
	var dist := flat_distance(player)
	_aggro_move(delta, player, dist)
	_try_hit(player, dist)


func _try_hit(player: Node3D, dist: float) -> bool:
	## Contact blow, on a cooldown so a single animal cannot chew through a whole
	## energy bar. Species with a real telegraph step aside from it entirely (the
	## stalker keeps its wind-up); for the rest, closing the distance IS the tell.
	if _attack_cd > 0.0 or dist > aggro_reach():
		return false
	# Reach is measured on the ground plane, so a rock or a trunk between us and
	# the player has to be checked for on its own: a bite does not go through one.
	if not Sight.clear(self, player):
		return false
	_attack_cd = aggro_cooldown()
	player.damage(aggro_damage())
	_on_hit(player)
	return true


func flat_distance(other: Node3D) -> float:
	## Ground distance, height ignored: a gull stooping over you and a rippleback
	## beside you are both "here" as far as reach is concerned.
	return Vector2(global_position.x, global_position.z).distance_to(
			Vector2(other.global_position.x, other.global_position.z))


func _losing_sight(player: Node3D) -> bool:
	return flat_distance(player) > AGGRO_LEASH or _cannot_reach(player)


## ------------------------------------------------------------------- the gait

func _aggro_move(delta: float, player: Node3D, _dist: float) -> void:
	## Default gait: charge on foot, held on dry land (past the shallows the sea
	## floor has no collision and stepping off is a fall-death). Winged, swimming
	## and drifting species override this with their own way of getting about.
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var dir := to.normalized()
	var p := global_position + dir * aggro_speed() * delta
	if _Island.height_at(p.x, p.z) < _Island.WATER_LEVEL + 0.3:
		return
	p.y = _Island.height_at(p.x, p.z) + CHARGE_BODY_Y
	global_position = p
	_face(dir)


func _face(dir: Vector3) -> void:
	var look := global_position + dir
	if global_position.distance_squared_to(look) > 0.0001:
		look_at(look, Vector3.UP)


func _cannot_reach(_player: Node3D) -> bool:
	## Override where an animal's element can be left behind (the rippleback
	## cannot follow anyone ashore). Leash distance covers everything else.
	return false


func _on_aggro() -> void:
	_play_growl()


func _on_calm() -> void:
	pass


func _on_hit(_player: Node3D) -> void:
	pass


func _play_growl() -> void:
	## Built lazily: the builder spawns the six species in bulk and most are
	## never provoked, so an idle animal should not carry an audio player around.
	if _snd_aggro == null:
		_snd_aggro = AudioStreamPlayer.new()
		_snd_aggro.stream = GROWL
		_snd_aggro.volume_db = GROWL_DB
		add_child(_snd_aggro)
	if _snd_aggro.is_inside_tree():
		_snd_aggro.play()