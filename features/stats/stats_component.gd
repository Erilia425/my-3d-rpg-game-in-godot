class_name StatsComponent
extends Node
## Secondary resource pools. Phase 2 implements stamina; magicka arrives with
## spells, so it is deliberately left out rather than added as dead weight.

signal stamina_changed(current: float, maximum: float)

@export var max_stamina: float = 100.0
@export var stamina_regen_per_second: float = 16.0

var _stamina: float = -1.0


func _ready() -> void:
	if _stamina < 0.0:
		_stamina = max_stamina
		stamina_changed.emit(_stamina, max_stamina)


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if _stamina >= max_stamina:
		return

	_stamina = minf(_stamina + stamina_regen_per_second * delta, max_stamina)
	stamina_changed.emit(_stamina, max_stamina)


func get_stamina() -> float:
	return _stamina


func get_max_stamina() -> float:
	return max_stamina


func get_fraction() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return clampf(_stamina / max_stamina, 0.0, 1.0)


## Spends stamina if there is enough. Returns false when the cost is too high.
func spend_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _stamina < amount:
		return false

	_stamina -= amount
	stamina_changed.emit(_stamina, max_stamina)
	return true


func restore_stamina(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, max_stamina - _stamina)
	if applied <= 0.0:
		return 0.0

	_stamina += applied
	stamina_changed.emit(_stamina, max_stamina)
	return applied


## Sets stamina directly, used when loading a save.
func set_stamina(value: float) -> void:
	_stamina = clampf(value, 0.0, max_stamina)
	stamina_changed.emit(_stamina, max_stamina)
