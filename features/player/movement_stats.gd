class_name MovementStats
extends RefCounted
## What the boots remember: jumps taken, the highest one, the longest drop.
##
## A static service like `WorldClock` and `QuestLog` (no autoload). The player
## calls it on takeoff and landing; `FieldNotes` reads it. It is saved inside the
## `world` block as `world.movement`, so a save keeps Rowan's own record.
##
## Only four numbers are kept. This is a keepsake, not a telemetry system.

static var _jumps := 0
static var _best_jump := 0.0
static var _best_drop := 0.0
static var _highest := 0.0
static var _best_airtime := 0.0


static func reset() -> void:
	_jumps = 0
	_best_jump = 0.0
	_best_drop = 0.0
	_highest = 0.0
	_best_airtime = 0.0


static func record_jump() -> void:
	_jumps += 1


## Called once per landing. `takeoff` is the last floor height, `peak` the
## highest point reached, and `airtime` the seconds spent off the ground.
static func record_landing(
	takeoff: float, peak: float, landing: float, airtime: float
) -> void:
	if airtime < 0.15:
		# A stair step or a kerb is not a jump.
		return
	_best_jump = maxf(_best_jump, peak - takeoff)
	_best_drop = maxf(_best_drop, takeoff - landing)
	_highest = maxf(_highest, peak)
	_best_airtime = maxf(_best_airtime, airtime)


static func get_jumps() -> int:
	return _jumps


static func get_best_jump() -> float:
	return _best_jump


static func get_best_drop() -> float:
	return _best_drop


static func get_highest() -> float:
	return _highest


static func get_best_airtime() -> float:
	return _best_airtime


static func save_data() -> Dictionary:
	return {
		"jumps": _jumps,
		"best_jump": _best_jump,
		"best_drop": _best_drop,
		"highest": _highest,
		"best_airtime": _best_airtime,
	}


static func load_data(data: Dictionary) -> void:
	_jumps = int(data.get("jumps", 0))
	_best_jump = float(data.get("best_jump", 0.0))
	_best_drop = float(data.get("best_drop", 0.0))
	_highest = float(data.get("highest", 0.0))
	_best_airtime = float(data.get("best_airtime", 0.0))
