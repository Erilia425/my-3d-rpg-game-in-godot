extends CharacterBody3D
## Placeholder enemy: idles, chases the player inside its aggro radius, and
## attacks in melee range.
##
## Deliberately simple for Phase 2: straight-line movement with no navigation
## mesh, so it can be blocked by walls. Navigation and schedules arrive in
## Phase 4.

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD,
}

@export var move_speed: float = 3.2
@export var aggro_range: float = 6.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.2
@export var gravity: float = 18.0
@export var save_id: StringName = &""
## Rewards granted only on a real kill, never when a save restores a corpse.
@export var xp_reward: int = 6
@export var coin_reward: int = 2
## Optional item dropped where the enemy fell. Empty disables drops.
@export var drop_item: StringName = &""
@export var drop_amount: int = 1
@export_range(0.0, 1.0) var drop_chance: float = 1.0

const DROP_SCENE := preload("res://features/interaction/world_pickup.tscn")

var state: State = State.IDLE

var _target: Node3D
var _cooldown := 0.0
var _health: HealthComponent

@onready var _visual: Node3D = %Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_health = $HealthComponent as HealthComponent
	if _health != null:
		_health.died.connect(_on_died)
	_target = get_tree().get_first_node_in_group("player") as Node3D
	if not save_id.is_empty():
		add_to_group(&"saveable")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if Game.state != Game.State.PLAYING:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_cooldown = maxf(_cooldown - delta, 0.0)

	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D

	var distance := INF
	if is_instance_valid(_target):
		distance = global_position.distance_to(_target.global_position)

	if distance > aggro_range:
		state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance <= attack_range:
		state = State.ATTACK
		velocity.x = 0.0
		velocity.z = 0.0
		_try_attack()
	else:
		state = State.CHASE
		_move_towards(_target.global_position)

	move_and_slide()


func get_state_name() -> StringName:
	match state:
		State.IDLE:
			return &"IDLE"
		State.CHASE:
			return &"CHASE"
		State.ATTACK:
			return &"ATTACK"
		State.DEAD:
			return &"DEAD"
	return &"UNKNOWN"


func get_health_component() -> HealthComponent:
	return _health


func _move_towards(target_position: Vector3) -> void:
	var offset := target_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return

	var direction := offset.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	look_at(global_position + direction, Vector3.UP)


func _try_attack() -> void:
	if _cooldown > 0.0 or not is_instance_valid(_target):
		return

	_cooldown = attack_cooldown

	var health := _target.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return

	# Armor is a flat reduction here; percentage-based mitigation can come with
	# the full stat system in a later phase.
	var armor := 0.0
	var equipment := _target.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if equipment != null:
		armor = equipment.get_armor_value()

	health.take_damage(maxf(attack_damage - armor, 1.0))


func _on_died() -> void:
	_apply_dead(true, true)


## Puts the enemy in its defeated state. Loading a save passes `animated` and
## `notify` as false: a reloaded corpse should not replay the death animation or
## announce the defeat again.
func _apply_dead(animated: bool, notify: bool) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	set_physics_process(false)

	if _health != null and not _health.is_dead():
		_health.set_health(0.0)

	if notify:
		Events.notification_requested.emit("Enemy defeated")
		_award_rewards()

	if _visual == null:
		return

	if animated:
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.0, 0.1, 1.0), 0.8)
		tween.parallel().tween_property(_visual, "position:y", -0.7, 0.8)
	else:
		_visual.scale = Vector3(1.0, 0.1, 1.0)
		_visual.position.y = -0.7


## Grants XP, coins, and a loot drop exactly once, on a genuine kill.
func _award_rewards() -> void:
	Progression.add_xp(xp_reward)
	if coin_reward > 0:
		Progression.add_coins(coin_reward)

	if drop_item.is_empty():
		return
	if drop_chance < 1.0 and randf() > drop_chance:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var drop := DROP_SCENE.instantiate() as StaticBody3D
	drop.set("item_id", drop_item)
	drop.set("amount", drop_amount)
	if not save_id.is_empty():
		drop.set("save_id", StringName("%s.drop" % save_id))
	scene.add_child(drop)
	drop.global_position = global_position + Vector3(0.35, 0.0, 0.35)


## Reverses `_apply_dead`. Used when a save says the enemy is still alive.
func _apply_alive() -> void:
	state = State.IDLE
	set_physics_process(true)
	_collision.set_deferred("disabled", false)

	if _visual != null:
		_visual.scale = Vector3.ONE
		_visual.position.y = 0.0


# --- persistence -----------------------------------------------------------
#
# An enemy is restored where it was left: position, facing, health, and whether
# it is already defeated. Phase 3 has no respawn timer, so a dead enemy stays
# dead.


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"health": 0.0 if _health == null else _health.get_health(),
		"dead": state == State.DEAD,
	}


func load_data(data: Dictionary) -> void:
	var position: Array = data.get("position", [])
	if position.size() == 3:
		global_position = Vector3(
			float(position[0]), float(position[1]), float(position[2])
		)
		velocity = Vector3.ZERO

	rotation.y = float(data.get("yaw", rotation.y))

	if bool(data.get("dead", false)):
		_apply_dead(false, false)
		return

	if state == State.DEAD:
		_apply_alive()

	var health := float(data.get("health", -1.0))
	if health > 0.0 and _health != null:
		_health.set_health(health)
