class_name CaveHunt
extends RefCounted
## The cave's memory of how many of the Spider Mother's children the player has
## killed, and how that ended.
##
## A static service like `QuestLog` and `WorldClock`: the project keeps its six
## approved autoloads, and there is exactly one hunt per running game. `Game`
## saves it inside the `world` block next to the clock, and clears it for a new
## game.
##
## The counter is the boss trigger. `enemy.gd` calls `record_spider_kill()` on a
## genuine kill when the scene marks the enemy as a cave spider, and
## `SpiderMotherBoss` reads `has_reached_threshold()` when the player comes near.
##
## The outcome is written once and never replayed: `set_outcome()` returns true
## only the first time, so a boss can never pay her rewards twice across a load.

## How many of her children must go quiet before she comes down from the silk.
const SPIDER_THRESHOLD := 4

## How the cave remembers the fight.
const OUTCOME_SLAIN := &"slain"
const OUTCOME_SPARED := &"spared"

static var _kills := 0
static var _awakened := false
static var _outcome: StringName = &""


static func reset() -> void:
	_kills = 0
	_awakened = false
	_outcome = &""


## Counts one dead cave spider. Returns the new total.
static func record_spider_kill() -> int:
	_kills += 1
	return _kills


static func get_kill_count() -> int:
	return _kills


static func get_threshold() -> int:
	return SPIDER_THRESHOLD


## True once enough of her children are gone. The fight does not start on the
## count alone: the player also has to come near her.
static func has_reached_threshold() -> bool:
	return _kills >= SPIDER_THRESHOLD


## True once the fight has begun at least once, so a reload walks back into a
## mother who already knows what the player did.
static func is_awakened() -> bool:
	return _awakened


static func set_awakened(value: bool = true) -> void:
	_awakened = value


static func get_outcome() -> StringName:
	return _outcome


static func is_finished() -> bool:
	return _outcome != &""


## Writes the ending. Returns true only on the first write, so rewards can be
## gated on it.
static func set_outcome(outcome: StringName) -> bool:
	if outcome == &"" or _outcome != &"":
		return false
	_outcome = outcome
	return true


static func save_data() -> Dictionary:
	return {
		"kills": _kills,
		"awakened": _awakened,
		"outcome": String(_outcome),
	}


## Restores the hunt, ignoring unknown or malformed entries instead of failing.
static func load_data(data: Dictionary) -> void:
	reset()

	_kills = maxi(int(data.get("kills", 0)), 0)
	_awakened = bool(data.get("awakened", false))

	var outcome := StringName(data.get("outcome", ""))
	if outcome == OUTCOME_SLAIN or outcome == OUTCOME_SPARED:
		_outcome = outcome
