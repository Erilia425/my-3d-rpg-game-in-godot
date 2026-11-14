class_name SpiderMotherBoss
extends Node3D
## The fight that a mother starts when too many of her children go quiet.
##
## This node is a child of the Spider Mother herself (`spider_lair.tscn`). It
## owns the whole encounter: the trigger, the descent, three phases, the amber
## memory-sac weakness, the silk attacks, the summons, and the three ways the
## fight can end.
##
## Everything down here is **not** saved. The lair is rebuilt from a fixed seed
## and a boss's health is a moment, not a fact. What *is* saved lives in
## `CaveHunt`: how many children are gone, whether she has woken, and how the
## fight ended.
##
## Only her memory-sac is a valid target. `spider_mother.gd` puts one collider
## in the `enemy` group and nothing else, so a swing at her body finds nothing
## solid while the silk plates are shut. When the sac is open, a blow interrupts
## whatever she was doing and staggers her.

enum State {
	DORMANT,
	WAKING,
	PHASE1,
	PHASE2,
	PHASE3,
	BEATEN,
	SLAIN,
	SPARED,
}

const SPIDER_SCENE := preload("res://features/combat/ghost_spider.tscn")
## A silk trap is a slow patch of ground, which is exactly what `RiverWade`
## already is: an area that asks the player to walk slower. Reusing it means one
## behaviour for water and web, and no second slow system.
const SILK_TRAP_SCRIPT := preload("res://features/world/river_wade.gd")

## How far above the floor she waits in the silk before she drops.
const CEILING_Y := 3.6
## Damage stops at this fraction so she is always beaten before she is killed.
## The player gets to choose the ending; a lucky heavy hit cannot skip it.
const BEATEN_FLOOR := 0.06
## Seconds she kneels waiting for the player to decide, before she leaves.
const MERCY_SECONDS := 25.0

const AWAKEN_LINES := [
	"Stop. Please. You are standing in a nursery.",
	"I felt each one go quiet. Four small lights, and then nothing.",
	"I am not cruel, keeper. But I am a mother, and you are still holding the blade.",
]

const COMBAT_LINES := [
	"I am sorry. I truly am.",
	"Put it down and I will let you walk out.",
	"There is a door behind you. I will not follow you through it.",
]

const MAX_TRAPS := 4

@export_group("Trigger")
## She wakes when the player is this close and enough children are gone.
@export var awaken_range: float = 15.0
## Set false to test the fight without a kill count.
@export var requires_threshold: bool = true

@export_group("Fight")
@export var max_health: float = 420.0
## The sac is the weak point: blows there hurt this much more.
@export var weak_multiplier: float = 2.0
@export var move_speed: float = 1.7
@export var swipe_range: float = 3.4
@export var swipe_damage: float = 14.0
@export var swipe_cooldown: float = 2.6
@export var silk_cooldown: float = 9.0
@export var summon_interval: float = 11.0
## Fraction of normal speed the player walks while webbed.
@export var silk_slow: float = 0.5
@export var silk_slow_seconds: float = 5.0

@export_group("Rewards")
@export var reward_xp: int = 120
@export var reward_coins: int = 60

var _mother: CharacterBody3D
var _health: HealthComponent
var _sac: StaticBody3D
var _cave: WildCaves
var _player: PlayerController
var _arena: Dictionary = {}

var _state: State = State.DORMANT
var _action: StringName = &"idle"
var _action_time := 0.0
var _cooldown := 0.0
var _silk_wait := 0.0
var _summon_wait := 0.0
var _eat_wait := 0.0
var _exposed_time := 0.0
var _mercy_time := 0.0
var _dazzle := 0.0
var _dazzle_line_wait := 0.0
var _quiet_wait := 0.0
var _taught_sac := false
var _rng := RandomNumberGenerator.new()

var _think := 0.0
var _summons: Array[Node] = []
var _traps: Array[Node] = []
var _cave_lights: Array[OmniLight3D] = []
var _silhouette: Node3D


func _ready() -> void:
	_mother = get_parent() as CharacterBody3D
	_rng.seed = 20261114
	# Children are ready before their parents, so the Mother's model (and the
	# memory-sac inside it) does not exist yet. One frame of patience.
	call_deferred(&"_begin")


func _begin() -> void:
	if _mother == null or not is_inside_tree():
		return

	_cave = _find_cave()
	_health = _ensure_health()
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)
	_sac = _mother.get_node_or_null("WeakPoint") as StaticBody3D
	if _mother.has_signal(&"memory_sac_struck"):
		_mother.connect(&"memory_sac_struck", _on_sac_struck)
	if _cave != null:
		_arena = _cave.get_lair_arena()
		_cave_lights = _collect_lights()

	if CaveHunt.is_finished():
		_become_absent()


# --- read-only view, for the HUD, the Mother and tests ---------------------


func get_state_name() -> StringName:
	match _state:
		State.DORMANT:
			return &"DORMANT"
		State.WAKING:
			return &"WAKING"
		State.PHASE1:
			return &"PHASE1"
		State.PHASE2:
			return &"PHASE2"
		State.PHASE3:
			return &"PHASE3"
		State.BEATEN:
			return &"BEATEN"
		State.SLAIN:
			return &"SLAIN"
		State.SPARED:
			return &"SPARED"
	return &"UNKNOWN"


## 0 while she is passive, 1-3 while she fights, 3 while she kneels.
func get_phase() -> int:
	match _state:
		State.PHASE2:
			return 2
		State.PHASE3, State.BEATEN:
			return 3
		State.PHASE1:
			return 1
	return 0


func is_hostile() -> bool:
	return _state == State.PHASE1 or _state == State.PHASE2 or _state == State.PHASE3


func is_beaten() -> bool:
	return _state == State.BEATEN


func is_finished() -> bool:
	return _state == State.SLAIN or _state == State.SPARED


func get_health() -> float:
	return 0.0 if _health == null else _health.get_health()


func get_summon_count() -> int:
	_prune_summons()
	return _summons.size()


func get_trap_count() -> int:
	return _traps.size()


## Skips the cutscene and starts the fight. Tests and tools use this; the game
## never calls it.
func force_awaken() -> void:
	if _state != State.DORMANT:
		return
	CaveHunt.set_awakened(true)
	_engage()


## Opens the memory-sac for a few seconds, as her heavy attack does.
func force_expose() -> void:
	_open_sac(5.0)


# --- the trigger -----------------------------------------------------------


func _physics_process(delta: float) -> void:
	match _state:
		State.DORMANT:
			_think -= delta
			if _think <= 0.0:
				_think = 0.3
				_maybe_awaken()
		State.PHASE1, State.PHASE2, State.PHASE3:
			if Game.state != Game.State.PLAYING:
				_stop()
				return
			_fight(delta)
		State.BEATEN:
			if Game.state != Game.State.PLAYING:
				_stop()
				return
			_tick_beaten(delta)


func _maybe_awaken() -> void:
	if requires_threshold and not CaveHunt.has_reached_threshold():
		return
	var player := _current_player()
	if player == null:
		return
	if _mother.global_position.distance_to(player.global_position) > awaken_range:
		return
	_awaken()


## The warning before the fight: the spiders stop, the rock shakes, the webs
## tighten, a silhouette crosses behind the silk, and then she comes down.
func _awaken() -> void:
	if _state != State.DORMANT:
		return

	_state = State.WAKING
	var first_time := not CaveHunt.is_awakened()
	CaveHunt.set_awakened(true)

	_freeze_spiders(true)
	if _cave != null:
		_cave.tighten_webs()
	_shake_lights(1.8)
	_show_silhouette()

	if first_time:
		Events.dialogue_requested.emit(
			"Lirael Marrow", "The Spider Mother", PackedStringArray(AWAKEN_LINES)
		)
		await _dialogue_closed()
	else:
		_say("Lirael: You came back. I hoped you would not.")
		await get_tree().create_timer(0.9, false).timeout

	if not is_inside_tree() or _state != State.WAKING:
		return

	_descend()
	await get_tree().create_timer(1.8, false).timeout

	if not is_inside_tree() or _state != State.WAKING:
		return

	_freeze_spiders(false)
	_engage()


## Waits for the reader to close the conversation, with a timer as a fallback so
## a missing HUD can never hang the boss for the rest of the session.
func _dialogue_closed() -> void:
	if not Events.has_signal(&"dialogue_closed"):
		await get_tree().create_timer(2.5, false).timeout
		return

	var tree := get_tree()
	var done := [false]
	var on_closed := func() -> void:
		done[0] = true

	Events.dialogue_closed.connect(on_closed, CONNECT_ONE_SHOT)
	var waited := 0.0
	while not done[0] and waited < 30.0 and is_inside_tree():
		await tree.create_timer(0.2, false).timeout
		waited += 0.2
	if Events.dialogue_closed.is_connected(on_closed):
		Events.dialogue_closed.disconnect(on_closed)


func _engage() -> void:
	if _health == null:
		_health = _ensure_health()
	if _health == null:
		return

	_state = State.PHASE1
	_action = &"idle"
	_cooldown = 1.2
	_silk_wait = 3.0
	_summon_wait = summon_interval
	_mother.set_physics_process(false)
	_mother.visible = true
	_health.set_health(max_health)

	Events.boss_engaged.emit("The Spider Mother", max_health)
	Events.boss_health_changed.emit(max_health, max_health)
	Events.boss_phase_changed.emit("The Matriarch")
	_say("Lirael: I am sorry. I truly am.")


# --- the fight -------------------------------------------------------------


func _fight(delta: float) -> void:
	var player := _current_player()
	if player == null:
		_stop()
		return

	var offset := player.global_position - _mother.global_position
	var distance := offset.length()

	_face(offset, delta)
	_tick_clocks(delta, player)

	if _action != &"idle":
		_action_time -= delta
		if _action_time <= 0.0:
			_resolve_action(distance, player)
	else:
		if _cooldown <= 0.0 and distance <= swipe_range:
			_start_swipe()
		elif _silk_wait <= 0.0:
			_start_silk()

	_drive(delta, offset, distance)


func _tick_clocks(delta: float, player: PlayerController) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_silk_wait = maxf(_silk_wait - delta, 0.0)
	_summon_wait = maxf(_summon_wait - delta, 0.0)
	_dazzle_line_wait = maxf(_dazzle_line_wait - delta, 0.0)
	_quiet_wait = maxf(_quiet_wait - delta, 0.0)
	_dazzle = maxf(_dazzle - delta, 0.0)

	if _exposed_time > 0.0:
		_exposed_time -= delta
		if _exposed_time <= 0.0:
			_mother.call(&"set_weak_point_open", false)

	if _summon_wait <= 0.0:
		_summon_wait = summon_interval
		_try_summon()

	if get_phase() == 3:
		_eat_wait -= delta
		if _eat_wait <= 0.0:
			_eat_wait = 12.0
			_try_eat()

	_check_flashlight(player)


## The player's own light is a real tool down here: she will not look into it.
func _check_flashlight(player: PlayerController) -> void:
	if not player.is_flashlight_on():
		return
	if _mother.global_position.distance_to(player.global_position) > 9.0:
		return

	_dazzle = 0.4
	if _dazzle_line_wait <= 0.0:
		_dazzle_line_wait = 16.0
		_say("She turns her face away from the light.")


func _start_swipe() -> void:
	_action = &"swipe"
	_action_time = 0.55
	_cooldown = _swipe_delay()
	_open_sac(1.0)

	if not _taught_sac:
		_taught_sac = true
		_say("Something amber opens under her belly. Hit it.")


func _start_silk() -> void:
	_action = &"silk"
	_action_time = 1.5
	_silk_wait = silk_cooldown
	# The heavy attack stretches her body, which is the longest window there is.
	_open_sac(2.6)
	_say("Lirael: Hold still. This will only take a moment.")


func _resolve_action(distance: float, player: PlayerController) -> void:
	if _action == &"swipe":
		_land_swipe(distance, player)
	elif _action == &"silk":
		_land_silk(player)
	elif _action == &"stagger":
		_say("She straightens, slowly.")
	_action = &"idle"
	_action_time = 0.0


func _land_swipe(distance: float, player: PlayerController) -> void:
	if distance > swipe_range + 0.8:
		return

	var health := player.get_health_component()
	if health == null or health.is_dead():
		return

	var armor := 0.0
	var equipment := player.get_equipment_component()
	if equipment != null:
		armor = equipment.get_armor_value()

	health.take_damage(maxf(swipe_damage - armor, 1.0))


func _land_silk(player: PlayerController) -> void:
	player.set_environment_speed(silk_slow)
	_place_trap()
	_say("The silk pulls tight around your boots.")
	await get_tree().create_timer(silk_slow_seconds, false).timeout

	if not is_instance_valid(self) or not is_instance_valid(player):
		return
	if not _standing_in_silk():
		player.set_environment_speed(1.0)


func _standing_in_silk() -> bool:
	for trap in _traps:
		if is_instance_valid(trap) and bool(trap.call(&"is_occupied")):
			return true
	return false


## Movement. The Mother's own `_physics_process` is switched off while she is
## hostile, so this node drives her body instead of `Npc`'s wandering code.
func _drive(delta: float, offset: Vector3, distance: float) -> void:
	var velocity := _mother.velocity
	if not _mother.is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0

	var speed := 0.0
	if _action == &"idle" and distance > 2.6:
		speed = _move_speed_now()

	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.0001:
		var direction := flat.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	_mother.velocity = velocity
	_mother.move_and_slide()


func _move_speed_now() -> float:
	var speed := move_speed
	if get_phase() == 2:
		speed *= 1.25
	elif get_phase() == 3:
		speed *= 1.55
	if _dazzle > 0.0:
		speed *= 0.55
	return speed


func _swipe_delay() -> float:
	var delay := swipe_cooldown
	if get_phase() == 2:
		delay *= 0.8
	elif get_phase() == 3:
		delay *= 0.6
	if _dazzle > 0.0:
		delay += 0.5
	return delay


func _face(offset: Vector3, delta: float) -> void:
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() < 0.0025:
		return
	var wanted := atan2(-flat.x, -flat.z)
	_mother.rotation.y = lerp_angle(_mother.rotation.y, wanted, clampf(7.0 * delta, 0.0, 1.0))


func _stop() -> void:
	_mother.velocity = Vector3.ZERO


# --- the amber memory-sac --------------------------------------------------


func _open_sac(seconds: float) -> void:
	if _state == State.BEATEN:
		return
	_exposed_time = maxf(_exposed_time, seconds)
	_mother.call(&"set_weak_point_open", true)


## One blow against the sac. `spider_mother.gd` forwards every hit on the sac's
## collider here; tests drive the same method.
func apply_sac_hit(amount: float) -> float:
	if _health == null or amount <= 0.0:
		return 0.0

	if _state == State.BEATEN:
		_finish(CaveHunt.OUTCOME_SLAIN)
		return amount

	if not is_hostile():
		return 0.0

	if _exposed_time <= 0.0:
		_say_shared("The silk drinks the blow. Only the amber place is soft.")
		return 0.0

	_exposed_time = 0.0
	_mother.call(&"set_weak_point_open", false)

	# Never kill her outright: the fight always ends with her beaten and the
	# player holding the decision.
	var floor_health := max_health * BEATEN_FLOOR
	var allowed := maxf(_health.get_health() - floor_health, 0.0)
	if allowed <= 0.0:
		_finish(CaveHunt.OUTCOME_SLAIN)
		return amount

	var dealt := _health.take_damage(minf(amount * weak_multiplier, allowed))
	_check_phase()
	if is_hostile():
		_stagger(1.1)
		_say("She folds around the hurt place, and the whole web shivers.")
	return dealt


func _on_sac_struck(amount: float) -> void:
	apply_sac_hit(amount)


func _stagger(seconds: float) -> void:
	_action = &"stagger"
	_action_time = seconds
	_exposed_time = 0.0
	_mother.call(&"set_weak_point_open", false)
	_stop()


# --- phases ----------------------------------------------------------------


func _check_phase() -> void:
	if _health == null:
		return

	var fraction := _health.get_fraction()
	if fraction <= 0.12:
		_enter_beaten()
		return

	var wanted := 1
	if fraction <= 0.34:
		wanted = 3
	elif fraction <= 0.66:
		wanted = 2

	if wanted > get_phase():
		_enter_phase(wanted)


func _enter_phase(phase: int) -> void:
	if phase == 2:
		_state = State.PHASE2
		Events.boss_phase_changed.emit("The Mother")
		_say("Lirael: I will not ask again.")
	elif phase == 3:
		_state = State.PHASE3
		_eat_wait = 8.0
		Events.boss_phase_changed.emit("Lirael")
		_say("Lirael: I am so tired of counting.")


func _enter_beaten() -> void:
	if _state == State.BEATEN:
		return

	_state = State.BEATEN
	_action = &"idle"
	_exposed_time = 0.0
	_action_time = 0.0
	_mercy_time = MERCY_SECONDS
	_mother.call(&"set_weak_point_open", true)
	_stop()

	Events.boss_phase_changed.emit("Lirael, kneeling")
	_say(
		"She does not raise her arms. \"Please. I will take what is left of them "
		+ "deeper, and you will not see us again.\"   (E to spare her)"
	)


func _tick_beaten(delta: float) -> void:
	var player := _current_player()
	if player != null:
		var offset := player.global_position - _mother.global_position
		_face(offset, delta)
	_stop()

	_mercy_time -= delta
	if _mercy_time <= 0.0:
		spare()


## Ends the fight without a killing blow. The Mother keeps her word and goes
## deeper, and `CaveHunt` remembers it.
func spare() -> void:
	if _state != State.BEATEN:
		return
	_finish(CaveHunt.OUTCOME_SPARED)


# --- allies ----------------------------------------------------------------


func _try_summon() -> void:
	var ceiling := 2
	if get_phase() == 2:
		ceiling = 4
	elif get_phase() == 3:
		ceiling = 5

	_prune_summons()
	if _summons.size() >= ceiling:
		return

	_summon()


func _summon() -> void:
	var host: Node = _cave if _cave != null else _mother.get_parent()
	if host == null:
		return

	var spider := SPIDER_SCENE.instantiate() as Node3D
	spider.set(&"save_id", &"")
	host.add_child(spider)

	var angle := _rng.randf() * TAU
	var distance := _rng.randf_range(3.0, 5.5)
	spider.global_position = (
		_mother.global_position
		+ Vector3(cos(angle) * distance, 0.05, sin(angle) * distance)
	)
	_summons.append(spider)
	_say("Lirael: Come here, little lights. Not you. Stay back.")


func _prune_summons() -> void:
	var alive: Array[Node] = []
	for spider in _summons:
		if is_instance_valid(spider) and not spider.is_queued_for_deletion():
			alive.append(spider)
	_summons = alive


## Phase three is starving: she takes one of her own back to keep going.
func _try_eat() -> void:
	_prune_summons()
	for spider in _summons:
		var body := spider as Node3D
		if body == null:
			continue
		if _mother.global_position.distance_to(body.global_position) > 7.0:
			continue

		_health.heal(max_health * 0.04)
		_summons.erase(spider)
		spider.queue_free()
		_say("Lirael takes one of her own back into herself.")
		return


func _place_trap() -> void:
	if _traps.size() >= MAX_TRAPS:
		return

	var host: Node = _cave if _cave != null else _mother.get_parent()
	if host == null:
		return

	var trap := Area3D.new()
	trap.name = "SilkTrap%d" % _traps.size()
	trap.set_script(SILK_TRAP_SCRIPT)
	trap.set(&"speed_scale", silk_slow)
	trap.set(&"entry_message", "Silk clings to your boots.")

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 1.8, 3.4)
	shape.shape = box
	trap.add_child(shape)

	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.7
	mesh.bottom_radius = 1.7
	mesh.height = 0.03
	disc.mesh = mesh
	disc.material_override = _web_material()
	trap.add_child(disc)

	host.add_child(trap)
	trap.global_position = (
		_mother.global_position
		+ Vector3(_rng.randf_range(-3.5, 3.5), 0.06, _rng.randf_range(-3.5, 3.5))
	)
	_traps.append(trap)


# --- endings ---------------------------------------------------------------


func _on_died() -> void:
	_finish(CaveHunt.OUTCOME_SLAIN)


func _finish(outcome: StringName) -> void:
	if is_finished() or _state == State.DORMANT or _state == State.WAKING:
		return

	var first_time := CaveHunt.set_outcome(outcome)
	_state = State.SLAIN if outcome == CaveHunt.OUTCOME_SLAIN else State.SPARED
	_action = &"idle"
	_exposed_time = 0.0

	_mother.call(&"set_weak_point_open", false)
	if _sac != null:
		_sac.collision_layer = 0
	_stop()
	_mother.set_physics_process(false)

	Events.boss_disengaged.emit()
	_release_traps()
	_scatter_summons()
	if _cave != null:
		_cave.loosen_webs()

	if outcome == CaveHunt.OUTCOME_SLAIN:
		if first_time:
			_award(outcome)
			_say("The web goes slack all at once, and the dark is very quiet.")
		_collapse()
		return

	if first_time:
		_award(outcome)
		_say(
			"She gathers the last of her children's silk and goes down where the "
			+ "light does not reach."
		)
	_sink()


## Already ended in an earlier visit: there is nothing here but silk.
func _become_absent() -> void:
	_state = State.SLAIN if CaveHunt.get_outcome() == CaveHunt.OUTCOME_SLAIN else State.SPARED
	_mother.visible = false
	_mother.set_physics_process(false)
	_mother.collision_layer = 0
	if _sac != null:
		_sac.collision_layer = 0

	if _state == State.SLAIN:
		_say("Only torn silk remains where she stood.")
	else:
		_say("The lair is empty. She kept her word and went deeper.")


func _collapse() -> void:
	var tween := create_tween()
	tween.tween_property(_mother, "scale", Vector3(1.25, 0.08, 1.25), 1.6)
	tween.parallel().tween_property(_mother, "rotation:z", 0.35, 1.6)
	if is_instance_valid(_silhouette):
		_silhouette.visible = false


func _sink() -> void:
	var tween := create_tween()
	tween.tween_property(_mother, "global_position:y", _mother.global_position.y - 2.8, 2.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_mother):
			_mother.visible = false
	)


func _award(outcome: StringName) -> void:
	Progression.add_xp(reward_xp)
	Progression.add_coins(reward_coins)
	_say("%d coins received" % reward_coins)

	if outcome == CaveHunt.OUTCOME_SLAIN:
		_give(&"item.hearth_silk_thread", 2)
		_give(&"item.memory_honey", 1)
	else:
		_give(&"item.mirror_thread", 1)


func _give(id: StringName, amount: int) -> void:
	var player := _current_player()
	if player == null:
		return
	var inventory := player.get_inventory_component()
	if inventory == null:
		return
	var data := ItemDatabase.get_item(id)
	if data == null:
		return
	if inventory.add_item(data, amount) > 0:
		_say("%s acquired" % data.display_name)


func _release_traps() -> void:
	var player := _current_player()
	var trapped := _standing_in_silk()
	for trap in _traps:
		if is_instance_valid(trap):
			trap.queue_free()
	_traps.clear()
	if trapped and player != null:
		player.set_environment_speed(1.0)


func _scatter_summons() -> void:
	for spider in _summons:
		if is_instance_valid(spider):
			spider.queue_free()
	_summons.clear()


# --- the cave answers ------------------------------------------------------


func _find_cave() -> WildCaves:
	var node: Node = get_parent()
	while node != null:
		if node is WildCaves:
			return node as WildCaves
		node = node.get_parent()
	return null


func _collect_lights() -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	if _cave == null:
		return lights
	for child in _cave.get_children():
		var light := child as OmniLight3D
		if light != null and String(light.name).begins_with("CaveLight"):
			lights.append(light)
	return lights


## The rock itself shakes: the chamber lamps jump, then settle.
func _shake_lights(seconds: float) -> void:
	if _cave_lights.is_empty():
		return

	var base: Dictionary = {}
	for light in _cave_lights:
		base[light] = light.light_energy

	var elapsed := 0.0
	while elapsed < seconds and is_inside_tree():
		for light in _cave_lights:
			if is_instance_valid(light):
				light.light_energy = float(base[light]) + _rng.randf_range(-0.7, 1.0)
		await get_tree().create_timer(0.07, false).timeout
		elapsed += 0.07

	if not is_inside_tree():
		return

	for light in _cave_lights:
		if is_instance_valid(light):
			light.light_energy = float(base[light])


## A shape crosses behind the silk, too big to be one of her children.
func _show_silhouette() -> void:
	var host: Node = _cave if _cave != null else _mother.get_parent()
	if host == null or _arena.is_empty():
		return

	var centre: Vector3 = _arena["centre"]
	var radius: float = float(_arena["radius"])

	_silhouette = Node3D.new()
	_silhouette.name = "MotherSilhouette"
	host.add_child(_silhouette)
	_silhouette.position = centre + Vector3(radius * 0.75, 0.0, -radius * 0.55)

	var dark := _silhouette_material()
	_part(_silhouette, "Abdomen", Vector3(0, 1.5, 1.1), Vector3(2.2, 1.6, 2.8), dark)
	_part(_silhouette, "Torso", Vector3(0, 2.4, -0.5), Vector3(1.0, 1.6, 0.7), dark)
	_part(_silhouette, "Head", Vector3(0, 3.4, -0.5), Vector3(0.7, 0.7, 0.7), dark)
	_part(_silhouette, "ArmL", Vector3(-1.2, 2.5, -0.7), Vector3(0.3, 1.8, 0.3), dark)
	_part(_silhouette, "ArmR", Vector3(1.2, 2.5, -0.7), Vector3(0.3, 1.8, 0.3), dark)

	var tween := create_tween()
	tween.tween_property(
		_silhouette, "position:x", _silhouette.position.x - radius * 1.4, 2.4
	)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_silhouette):
			_silhouette.visible = false
	)


## She lets the silk take her, then comes down out of it.
func _descend() -> void:
	_mother.set_physics_process(false)
	var floor_y := _mother.global_position.y

	_mother.visible = false
	_mother.global_position.y = floor_y + CEILING_Y
	_mother.visible = true

	var tween := create_tween()
	tween.tween_property(_mother, "global_position:y", floor_y, 1.7).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_IN)


func _freeze_spiders(freeze: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == _mother or node == _sac:
			continue
		if not node.has_method(&"get_state_name"):
			continue
		(node as Node).set_physics_process(not freeze)
		if freeze:
			node.set(&"velocity", Vector3.ZERO)


# --- small helpers ---------------------------------------------------------


func _current_player() -> PlayerController:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController
	return _player


func _ensure_health() -> HealthComponent:
	if _mother == null:
		return null
	var existing := _mother.get_node_or_null("HealthComponent") as HealthComponent
	if existing != null:
		return existing

	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_health
	_mother.add_child(health)
	health.set_health(max_health)
	return health


func _on_health_changed(current: float, maximum: float) -> void:
	Events.boss_health_changed.emit(current, maximum)


## The Mother's spoken lines while the fight is live. The conversation window is
## closed on purpose: a panel would stop the player's feet mid-swing.
func speak_combat_line() -> void:
	_say(COMBAT_LINES[_rng.randi_range(0, COMBAT_LINES.size() - 1)])


func _say(text: String) -> void:
	Events.notification_requested.emit(text)


## Throttled so the same line cannot fill the toast every half second.
func _say_shared(text: String) -> void:
	if _quiet_wait > 0.0:
		return
	_quiet_wait = 3.0
	_say(text)


func _web_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.84, 0.92, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _silhouette_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.012, 0.02, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _part(parent: Node3D, node_name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance
