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
const THATCH_HIVE := &"quest.thatch_hive"
const SEAMSTRESS_THREAD := &"quest.seamstress_thread"
## Small one-line errands in the two outlying villages. They are deliberately
## simple: a single delivery and a single reward, so the villages have a reason
## to be visited without growing a second quest system.
const ASHFALL_MUSHROOMS := &"quest.ashfall_mushrooms"
const ASHFALL_SNAGS := &"quest.ashfall_snags"
const THORNRIDGE_STONE := &"quest.thornridge_stone"
const THORNRIDGE_ORE := &"quest.thornridge_ore"

const DEFS: Dictionary = {
	SPOREBREAD: {
		"title": "Sporebread for Auntie Bell",
		"summary": "Bring Auntie Bell one Sporebread.",
	},
	ROWAN_LEDGER: {
		"title": "The Ledger's Debt",
		"summary": "Fern found a page torn from your ledger. Read the ledger on your desk.",
	},
	THATCH_HIVE: {
		"title": "Flowers for the Hive",
		"summary": "Bring Thatch one Flower for the Hive Tower's bees.",
	},
	SEAMSTRESS_THREAD: {
		"title": "Thread for the Seamstress",
		"summary": "Bring the Blind Seamstress one Hearth-Silk Thread.",
	},
	ASHFALL_MUSHROOMS: {
		"title": "Mushrooms for the Pot",
		"summary": "Bring Maren Ash two Mushrooms for the village pot.",
	},
	ASHFALL_SNAGS: {
		"title": "Deadfall for the Boardwalk",
		"summary": "Bring Pell three Spruce Logs for the bog boardwalk.",
	},
	THORNRIDGE_STONE: {
		"title": "Stone for the Causeway",
		"summary": "Bring Bryn Thorne three Fieldstone for the bridge repairs.",
	},
	THORNRIDGE_ORE: {
		"title": "Ore for the Quarry",
		"summary": "Bring Sable two Iron Ore from the hills.",
	},
}

## IDs currently in progress, mapped to `true`. A dictionary rather than an
## array so lookups stay O(1) and duplicates are impossible.
static var _active: Dictionary = {}
static var _completed: Dictionary = {}
## Named one-shot world events (gifts given, places visited). Kept here so they
## ride along in the same save block as quest progress without new autoloads.
static var _flags: Dictionary = {}


static func reset() -> void:
	_active.clear()
	_completed.clear()
	_flags.clear()


## Records a one-shot world event by name. Returns true only the first time, so
## callers can gate a reward on it.
static func set_flag(flag: StringName) -> bool:
	if flag == &"" or _flags.has(flag):
		return false
	_flags[flag] = true
	return true


static func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


static func clear_flag(flag: StringName) -> void:
	_flags.erase(flag)


static func start(id: StringName) -> bool:
	if id == &"" or _active.has(id) or _completed.has(id):
		return false
	_active[id] = true
	return true


static func is_active(id: StringName) -> bool:
	return _active.has(id)


static func is_completed(id: StringName) -> bool:
	return _completed.has(id)


## Quest ids currently in progress, in the order they were started.
static func get_active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _active.keys():
		ids.append(StringName(id))
	return ids


## Quest ids already finished, in the order they were completed.
static func get_completed_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _completed.keys():
		ids.append(StringName(id))
	return ids


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
		"flags": _flags.keys(),
	}


## Restores the log, ignoring unknown or malformed entries instead of failing.
static func load_data(data: Dictionary) -> void:
	reset()

	for id: Variant in data.get("active", []):
		_active[StringName(id)] = true
	for id: Variant in data.get("completed", []):
		_completed[StringName(id)] = true
	for flag: Variant in data.get("flags", []):
		_flags[StringName(flag)] = true
