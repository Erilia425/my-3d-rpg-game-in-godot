class_name StatsComponent
extends Node
## Secondary resource pools: stamina for physical effort, memory for magic,
## silk for containment, and anchoring for identity.
##
## Memory regenerates slowly while the game is playing and is also refilled by
## prepared honey. Silk does not regenerate: it is repaired with silk items, and
## it is the safe cap on how much memory a spell may shape. Anchoring is a small
## count of teeth; a tooth is never an ordinary spell cost.
##
## `mana_changed` keeps its old name so existing saves and the bed keep working,
## but the pool it announces is the Hollow's memory charge. See AGENTS.md 15.

signal stamina_changed(current: float, maximum: float)
## The memory-charge pool. Named `mana_changed` for save/HUD compatibility.
signal mana_changed(current: float, maximum: float)
signal silk_changed(current: float, maximum: float)
signal anchoring_changed(current: int, maximum: int)
## Emitted when the Anchor guard starts (`true`) or lapses (`false`).
signal anchor_guard_changed(active: bool)

@export var max_stamina: float = 100.0
@export var stamina_regen_per_second: float = 16.0
@export var max_mana: float = 80.0
## Slow on purpose: memory should be the resource you ration, not spam.
@export var mana_regen_per_second: float = 4.0
## How much magic the player can safely contain. Raised by silk repairs and
## future skill ranks; spells above this leak into the Ledger.
@export var max_silk: float = 100.0
## Anchoring slots for teeth. Teeth themselves are items, not a regenerating bar.
@export var max_anchoring: int = 3
## How long one Anchor holds. Deliberately transient: a guard is a moment, not a
## permanent stat, so it is never written to a save.
@export var anchor_guard_seconds: float = 60.0

var _stamina: float = -1.0
var _mana: float = -1.0
var _silk: float = -1.0
var _anchoring: int = -1
var _anchor_guard: float = 0.0


func _ready() -> void:
	if _stamina < 0.0:
		_stamina = max_stamina
		stamina_changed.emit(_stamina, max_stamina)
	if _mana < 0.0:
		_mana = max_mana
		mana_changed.emit(_mana, max_mana)
	if _silk < 0.0:
		_silk = max_silk
		silk_changed.emit(_silk, max_silk)
	if _anchoring < 0:
		_anchoring = 0
		anchoring_changed.emit(_anchoring, max_anchoring)


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return

	if _anchor_guard > 0.0:
		_anchor_guard = maxf(_anchor_guard - delta, 0.0)
		if _anchor_guard <= 0.0:
			anchor_guard_changed.emit(false)

	if _stamina < max_stamina:
		_stamina = minf(_stamina + stamina_regen_per_second * delta, max_stamina)
		stamina_changed.emit(_stamina, max_stamina)

	if _mana < max_mana:
		_mana = minf(_mana + mana_regen_per_second * delta, max_mana)
		mana_changed.emit(_mana, max_mana)


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


func get_mana() -> float:
	return _mana


func get_max_mana() -> float:
	return max_mana


func get_mana_fraction() -> float:
	if max_mana <= 0.0:
		return 0.0
	return clampf(_mana / max_mana, 0.0, 1.0)


## Spends magicka if there is enough. Returns false when the spell costs more
## than the caster has, so a spell never half-casts.
func spend_mana(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if _mana < amount:
		return false

	_mana -= amount
	mana_changed.emit(_mana, max_mana)
	return true


func restore_mana(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, max_mana - _mana)
	if applied <= 0.0:
		return 0.0

	_mana += applied
	mana_changed.emit(_mana, max_mana)
	return applied


## Sets magicka directly, used when loading a save or when a bed restores it.
func set_mana(value: float) -> void:
	_mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(_mana, max_mana)


# --- memory aliases --------------------------------------------------------
#
# Hollow magic calls the same pool "memory charge". These aliases keep spell
# code readable without renaming the exported fields or the save key.


func get_memory() -> float:
	return get_mana()


func get_max_memory() -> float:
	return get_max_mana()


func get_memory_fraction() -> float:
	return get_mana_fraction()


func spend_memory(amount: float) -> bool:
	return spend_mana(amount)


func restore_memory(amount: float) -> float:
	return restore_mana(amount)


func set_memory(value: float) -> void:
	set_mana(value)


# --- silk ------------------------------------------------------------------


func get_silk() -> float:
	return _silk


func get_max_silk() -> float:
	return max_silk


func get_silk_fraction() -> float:
	if max_silk <= 0.0:
		return 0.0
	return clampf(_silk / max_silk, 0.0, 1.0)


## True when the current silk can contain a spell of this size without leaking.
## A held Anchor makes any spell safe for its duration, which is what makes a
## tooth worth spending on a cast the silk is too thin to hold.
func can_contain(amount: float) -> bool:
	return is_anchored() or _silk >= amount


## Damages the silk that holds magic together. Silk never protects the player
## from damage; it only protects a spell from spreading.
func damage_silk(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, _silk)
	if applied <= 0.0:
		return 0.0

	_silk -= applied
	silk_changed.emit(_silk, max_silk)
	return applied


func repair_silk(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, max_silk - _silk)
	if applied <= 0.0:
		return 0.0

	_silk += applied
	silk_changed.emit(_silk, max_silk)
	return applied


## Sets silk directly, used when loading a save.
func set_silk(value: float) -> void:
	_silk = clampf(value, 0.0, max_silk)
	silk_changed.emit(_silk, max_silk)


# --- anchoring -------------------------------------------------------------


func get_anchoring() -> int:
	return _anchoring


func get_max_anchoring() -> int:
	return max_anchoring


## Uses one anchoring tooth. Returns false when the player holds none, so a
## caller can refuse an anchored effect instead of casting it unanchored.
func spend_anchoring(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if _anchoring < amount:
		return false

	_anchoring -= amount
	anchoring_changed.emit(_anchoring, max_anchoring)
	return true


func grant_anchoring(amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var applied := mini(amount, max_anchoring - _anchoring)
	if applied <= 0:
		return 0

	_anchoring += applied
	anchoring_changed.emit(_anchoring, max_anchoring)
	return applied


## Sets anchoring directly, used when loading a save.
func set_anchoring(value: int) -> void:
	_anchoring = clampi(value, 0, max_anchoring)
	anchoring_changed.emit(_anchoring, max_anchoring)


# --- anchor guard ----------------------------------------------------------
#
# One tooth can be spent to hold the player's identity steady for a short while.
# While it holds, `can_contain()` is true whatever the silk says, so a Recall
# cannot leak. The guard is transient by design: it is a moment, not a stat, and
# a save never carries it.


## True while an Anchor is holding.
func is_anchored() -> bool:
	return _anchor_guard > 0.0


## Seconds left on the current Anchor. Zero when none holds.
func get_anchor_guard_time() -> float:
	return _anchor_guard


## Starts (or extends) the Anchor guard. A shorter request never cuts a longer
## guard short, so two teeth cannot accidentally waste one another.
func hold_anchor(seconds: float = -1.0) -> void:
	var duration := seconds if seconds > 0.0 else anchor_guard_seconds
	if duration <= _anchor_guard:
		return
	_anchor_guard = duration
	anchor_guard_changed.emit(true)


## Ends the guard early. Used by tests and by a future dispel effect.
func clear_anchor_guard() -> void:
	if _anchor_guard <= 0.0:
		return
	_anchor_guard = 0.0
	anchor_guard_changed.emit(false)

