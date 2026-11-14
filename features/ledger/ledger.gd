class_name Ledger
extends RefCounted
## The Hollow's Ledger: a record of unresolved supernatural exchanges.
##
## This is *not* a seventh autoload. Like `WorldClock`, `QuestLog`,
## `DiscoveryLog` and `Progression` it is a static service: one record per
## process, saved inside the save file's `world` block.
##
## Imbalance is the player's accumulated unanswered magic. It is not spent like
## a pool; it rises when magic is used without enough silk to contain it, and it
## is relieved only by an exchange that pays something back. The three words are
## deliberately qualitative: the player should read a mood, not a percentage.
##
## The service owns numbers only. Whoever caused an imbalance decides how the
## world reacts to it: `get_escalation()` is the one number the world reads, and
## the Guests read it when they arrive. Forest intrusion is still a later phase.

## Full imbalance. Above this the Ledger cannot record more, so it tops out.
const MAX_IMBALANCE := 100.0
## Below this the Ledger reads as balanced.
const THRESHOLD_THIN := 20.0
## At or above this the Ledger is actively watching.
const THRESHOLD_WATCHED := 60.0
## Every escalation tier hardens the Guests by this much: health, damage and
## awareness all scale together, so a watched Ledger is felt rather than read.
const ESCALATION_STEP := 0.25

## Recorded but unpaid exchanges, keyed by a stable id such as
## `debt.sporebread_unpaid`. Values are whole numbers for now.
static var _imbalance: float = 0.0
static var _debts: Dictionary = {}


static func reset() -> void:
	_imbalance = 0.0
	_debts.clear()


# --- imbalance -------------------------------------------------------------


static func get_imbalance() -> float:
	return _imbalance


## Adds imbalance and returns how much was actually recorded, so a caller can
## tell when the Ledger was already full.
static func add_imbalance(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, MAX_IMBALANCE - _imbalance)
	if applied <= 0.0:
		return 0.0

	_imbalance += applied
	return applied


## Pays imbalance down. Returns how much was relieved.
static func relieve_imbalance(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var applied := minf(amount, _imbalance)
	if applied <= 0.0:
		return 0.0

	_imbalance -= applied
	return applied


static func set_imbalance(value: float) -> void:
	_imbalance = clampf(value, 0.0, MAX_IMBALANCE)


## The word shown on the HUD, from the player's point of view.
static func get_state_word() -> String:
	if _imbalance >= THRESHOLD_WATCHED:
		return "Watched"
	if _imbalance >= THRESHOLD_THIN:
		return "Thin"
	return "Balanced"


# --- escalation ------------------------------------------------------------
#
# "Escalating" is the Ledger's first mechanical consequence: the fuller the
# record, the harsher the things that answer it. The tiers are whole numbers so
# a save, a test and a Guest all agree on what "how loud" means.


## How loudly the Ledger is speaking: 0 balanced, 1 thin, 2 watched, 3 full.
static func get_escalation() -> int:
	if _imbalance >= MAX_IMBALANCE:
		return 3
	if _imbalance >= THRESHOLD_WATCHED:
		return 2
	if _imbalance >= THRESHOLD_THIN:
		return 1
	return 0


## The multiplier the Ledger's answers apply at the current tier. 1.0 when the
## record is balanced, so nothing changes for an ordinary playthrough.
static func get_escalation_scale() -> float:
	return 1.0 + ESCALATION_STEP * float(get_escalation())


## One line spoken when the tier rises. Empty at a balanced Ledger, so a HUD can
## call it without checking first.
static func get_escalation_line(tier: int = -1) -> String:
	var level := get_escalation() if tier < 0 else tier
	match level:
		1:
			return "The Ledger has noticed. Something in the woods is paying attention."
		2:
			return "The Ledger is watching. The Guests are bolder than they were."
		3:
			return "The Ledger is full. The Hollow answers whether you ask or not."
	return ""


# --- debts -----------------------------------------------------------------


## Records an unpaid exchange. Repeated calls add to the same debt.
static func add_debt(id: StringName, amount: int = 1) -> void:
	if id.is_empty() or amount <= 0:
		return
	_debts[id] = int(_debts.get(id, 0)) + amount


## Pays a debt down. Returns true when the debt is fully settled.
static func pay_debt(id: StringName, amount: int = 1) -> bool:
	if id.is_empty() or amount <= 0 or not _debts.has(id):
		return false

	var left := int(_debts[id]) - amount
	if left <= 0:
		_debts.erase(id)
		return true

	_debts[id] = left
	return false


static func has_debt(id: StringName) -> bool:
	return _debts.has(id)


static func get_debt(id: StringName) -> int:
	return int(_debts.get(id, 0))


static func get_debts() -> Dictionary:
	return _debts.duplicate()


# --- persistence -----------------------------------------------------------


static func save_data() -> Dictionary:
	return {
		"imbalance": _imbalance,
		"debts": _ids_to_strings(_debts),
	}


static func load_data(data: Dictionary) -> void:
	reset()
	_imbalance = clampf(float(data.get("imbalance", 0.0)), 0.0, MAX_IMBALANCE)

	var stored: Variant = data.get("debts", {})
	if not stored is Dictionary:
		return
	for raw_id: Variant in (stored as Dictionary).keys():
		var id := StringName(raw_id)
		var amount := int((stored as Dictionary)[raw_id])
		if not id.is_empty() and amount > 0:
			_debts[id] = amount


## JSON turns `StringName` keys into strings. Restoring the name keeps the live
## record identical to the one that was saved.
static func _ids_to_strings(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in source.keys():
		out[String(id)] = source[id]
	return out
