class_name DiscoveryLog
extends RefCounted
## Tracks lore discoveries the player has unlocked.
##
## A static service like `QuestLog` and `WorldClock`: the project keeps its six
## approved autoloads, and there is exactly one discovery log per running game.
## `Game` saves it inside the `world` block of the save file, next to the clock
## and the quests, and clears it for a new game.
##
## Definitions live in `DEFS`; only the set of unlocked ids lives in `_unlocked`.
## A discovery is described by an id, a title, and a short description. Larger
## lore entries (images, cross-references) belong in a resource in a later phase.

const FUNGAL_RECORD := &"discovery.fungal_record"
const OLD_ADIT := &"discovery.old_adit"
const WHAT_SHE_KNOWS := &"discovery.what_she_knows"

const DEFS: Dictionary = {
	FUNGAL_RECORD: {
		"title": "The Fungal Record",
		"description": "The fungi used to make Sporebread grow near something old beneath the woods. Auntie Bell's favor revealed the first clue.",
	},
	OLD_ADIT: {
		"title": "The Old Adit",
		"description": "A hand-cut adit under the north meadow, older than the Hollow's oldest house. Iron and pale stone still seam its walls.",
	},
	WHAT_SHE_KNOWS: {
		"title": "What the Seamstress Knows",
		"description": "The Blind Seamstress taught all five lessons: honey moves memory, silk holds it, teeth anchor it, and the Ledger keeps the account. Fern is a false child grown stable, and the First Child may be the deeper origin. She knows what Fern is not. She does not know what they are.",
	},
}

## Unlocked IDs, mapped to `true`. A dictionary rather than an array so lookups
## stay O(1) and duplicates are impossible.
static var _unlocked: Dictionary = {}


static func reset() -> void:
	_unlocked.clear()


## Unlocks a discovery. Returns true only the first time, so callers can gate a
## notification on the return value.
static func unlock(id: StringName) -> bool:
	if id == &"" or _unlocked.has(id):
		return false
	_unlocked[id] = true
	return true


static func has(id: StringName) -> bool:
	return _unlocked.has(id)


static func get_title(id: StringName) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return String(def.get("title", ""))


static func get_description(id: StringName) -> String:
	var def: Dictionary = DEFS.get(id, {})
	return String(def.get("description", ""))


## Unlocked ids in the order they were first discovered.
static func get_unlocked() -> Array:
	return _unlocked.keys()


static func save_data() -> Dictionary:
	return {
		"unlocked": _unlocked.keys(),
	}


## Restores the log, ignoring unknown or malformed entries instead of failing.
static func load_data(data: Dictionary) -> void:
	reset()

	for id: Variant in data.get("unlocked", []):
		_unlocked[StringName(id)] = true
