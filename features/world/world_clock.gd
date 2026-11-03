class_name WorldClock
extends RefCounted
## Global game time for the whole session.
##
## A static service rather than an autoload: the project keeps its six approved
## autoloads, and there is exactly one world per running game. `Game` advances
## it while playing and `SaveManager` persists it.
##
## Time is stored as a day number plus an hour in [0, 24). Keeping the hour as
## a float avoids drift from repeated integer rounding.

const HOURS_PER_DAY := 24.0
const MINUTES_PER_HOUR := 60.0
const START_DAY := 1
const START_HOUR := 8.0

## In-game minutes that pass per real second: 1.0 makes one game day 24 real
## minutes, which is long enough to feel slow in a test room.
static var minutes_per_real_second: float = 1.0

static var day: int = START_DAY
static var hour: float = START_HOUR


static func reset() -> void:
	day = START_DAY
	hour = START_HOUR


## Moves the clock forward by `delta` real seconds. Callers decide whether time
## should be running (the player is unpaused and in gameplay).
static func advance(delta: float) -> void:
	if delta <= 0.0 or minutes_per_real_second <= 0.0:
		return

	hour += delta * minutes_per_real_second / MINUTES_PER_HOUR
	while hour >= HOURS_PER_DAY:
		hour -= HOURS_PER_DAY
		day += 1


static func get_day() -> int:
	return day


static func get_hour() -> float:
	return hour


## "08:15" style clock for the HUD and the debug overlay.
static func get_clock_string() -> String:
	var total_minutes := int(hour * MINUTES_PER_HOUR)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


## "Day 1 · 08:15" style stamp.
static func get_time_string() -> String:
	return "Day %d · %s" % [day, get_clock_string()]


static func save_data() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"minutes_per_real_second": minutes_per_real_second,
	}


## Restores a saved clock, ignoring nonsense values instead of failing.
static func load_data(data: Dictionary) -> void:
	day = maxi(int(data.get("day", START_DAY)), 1)
	hour = clampf(float(data.get("hour", START_HOUR)), 0.0, HOURS_PER_DAY - 0.001)
	minutes_per_real_second = maxf(
		float(data.get("minutes_per_real_second", 1.0)), 0.0
	)
