class_name QuestLog
extends RefCounted
## Tracks which quests the player has started and finished.
##
## A static service like `WorldClock`: the project keeps its six approved
## autoloads, and there is exactly one quest log per running game. `Game` saves
## it inside the `world` block of the save file, next to the clock, and clears it
## for a new game.
##
## Definitions live in `DEFS`; only progress lives in `_active` / `_completed`.
## A quest is described by an id, a title, and one short summary line. Anything
## larger (objectives, rewards, branching) belongs in a `QuestData` resource in a
## later phase. See AGENTS.md sections 4.5 and 4.6.

const SPOREBREAD := &"quest.sporebread"
const ROWAN_LEDGER := &"quest.rowan_ledger"

const DEFS: Dictionary = {
	SPOREBREAD: {
		"title": "Sporebread for Auntie Bell",
		"summary": "Bring Auntie Bell one Sporebread.",
	},
	ROWAN_LEDGER: {
		"title": "The Ledger's Debt",
		"summary": "Read Rowan's ledger in the keeper's office.",
	},
}

## IDs currently in progress, mapped to `true`. A dictionary rather than an
## array so lookups stay O(1) and duplicates are impossible.
static var _active: Dictionary = {}
static var _completed: Dictionary = {}


static func reset() -> void:
	_active.clear()
	_completed.clear()


static func start(id: StringName) -> bool:
	if id == &"" or _active.has(id) or _completed.has(id):
		return false
	_active[id] = true
	return true


static func is_active(id: StringName) -> bool:
	return _active.has(id)


static func is_completed(id: StringName) -> bool:
	return _completed.has(id)


## Marks a quest finished. Returns true only on the first completion, so callers
## can gate a reward on the return value.
static func complete(id: StringName) -> bool:
	if id == &"" or _completed.has(id):
		return false
	_active.erase(id)
	_completed[id] = true
	return true


static func get_title(id: StringName) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return String(def.get("title", ""))


static func get_summary(id: StringName) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return String(def.get("summary", ""))


## One line per active quest for the HUD tracker. Empty when nothing is active,
## so the caller can hide the label.
static func get_tracker_text() -> String:
	if _active.is_empty():
		return ""

	var lines := PackedStringArray()
	for id in _active.keys():
		var title := get_title(id)
		if title.is_empty():
			continue
		lines.append(title)

	if lines.is_empty():
		return ""
	return "Quests\n" + "\n".join(lines)


static func save_data() -> Dictionary:
	return {
		"active": _active.keys(),
		"completed": _completed.keys(),
	}


## Restores the log, ignoring unknown or malformed entries instead of failing.
static func load_data(data: Dictionary) -> void:
	reset()

	for id: Variant in data.get("active", []):
		_active[StringName(id)] = true
	for id: Variant in data.get("completed", []):
		_completed[StringName(id)] = true
