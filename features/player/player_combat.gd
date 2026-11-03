extends Node
## Player combat: attack input, stamina cost, swing animation, and a placeholder
## death rule.
##
## Lives beside `player_controller.gd` instead of inside it so the controller
## stays about movement and cameras. See AGENTS.md section 4.1.

## Stamina spent per swing.
@export var stamina_cost: float = 12.0

@onready var _player: PlayerController = get_parent() as PlayerController
@onready var _attack: AttackComponent = get_parent().get_node("%AttackComponent")
@onready var _health: HealthComponent = get_parent().get_node("%HealthComponent")
@onready var _stats: StatsComponent = get_parent().get_node("%StatsComponent")
@onready var _equipment: EquipmentComponent = get_parent().get_node("%EquipmentComponent")

var _spawn_position := Vector3.ZERO


func _ready() -> void:
	_spawn_position = _player.global_position
	_health.died.connect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING or _health.is_dead():
		return
	if not event.is_action_pressed("attack"):
		return
	if _player.is_ui_blocked():
		return
	if try_attack():
		get_viewport().set_input_as_handled()


## Swings if stamina allows. Returns true when a swing happened.
func try_attack() -> bool:
	if _health.is_dead():
		return false
	if not _stats.spend_stamina(stamina_cost):
		Events.notification_requested.emit("Too tired to swing")
		return false

	_attack.damage = _equipment.get_attack_damage()
	_player.play_attack_animation()
	_attack.try_hit()
	return true


func _on_died() -> void:
	# Placeholder death: there is no save system or death screen in Phase 2, so
	# the player is frozen, then returned to where they started at full health.
	Events.notification_requested.emit("You died")
	_player.set_ui_blocked(true)
	await get_tree().create_timer(1.5).timeout

	if not is_instance_valid(_player):
		return

	_health.revive()
	_player.global_position = _spawn_position
	_player.velocity = Vector3.ZERO
	_player.set_ui_blocked(false)
