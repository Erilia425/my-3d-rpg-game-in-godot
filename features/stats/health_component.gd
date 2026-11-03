class_name HealthComponent
extends Node
## Owns the health pool of its parent actor.
##
## Signals go up to the owner and the HUD; nothing here knows who is listening.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died()

@export var max_health: float = 100.0

var _health: float = -1.0


func _ready() -> void:
	if _health < 0.0:
		_health = max_health
		health_changed.emit(_health, max_health)


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return max_health


## 0.0 when empty, 1.0 when full. Safe to feed straight into a progress bar.
func get_fraction() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(_health / max_health, 0.0, 1.0)


func is_dead() -> bool:
	return _health <= 0.0


## Applies damage and returns how much was actually taken.
func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0

	var applied := minf(amount, _health)
	_health -= applied
	damaged.emit(applied)
	health_changed.emit(_health, max_health)
	if _health <= 0.0:
		died.emit()
	return applied


## Restores health and returns how much was actually restored.
func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return 0.0

	var applied := minf(amount, max_health - _health)
	if applied <= 0.0:
		return 0.0

	_health += applied
	healed.emit(applied)
	health_changed.emit(_health, max_health)
	return applied


func revive() -> void:
	_health = max_health
	health_changed.emit(_health, max_health)


## Sets health directly, used when loading a save. Never emits `died`: a save
## describes a living moment, and the HUD only needs the new numbers.
func set_health(value: float) -> void:
	_health = clampf(value, 0.0, max_health)
	health_changed.emit(_health, max_health)
