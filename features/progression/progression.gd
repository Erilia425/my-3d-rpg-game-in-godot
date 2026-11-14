class_name Progression
extends RefCounted
## Tracks long-term character progress: experience, levels, skill points, coins,
## purchased skills and shop upgrades, ledger lore pages, and villager favor.
##
## A static service like `QuestLog` and `DiscoveryLog`: the project keeps its six
## approved autoloads, and there is exactly one progression record per running
## game. `Game` saves it inside the `world` block of the save file and clears it
## for a new game.
##
## Definitions live in `SKILL_DEFS` / `SHOP_DEFS` / `LORE_DEFS`; only progress
## lives in the static vars below. Nothing here reaches into the scene tree, so
## the service stays easy to test and to save.

# --- ids -------------------------------------------------------------------

const SKILL_DOUBLE_JUMP := &"skill.double_jump"
const SKILL_HEAL_STEAL := &"skill.heal_steal"
const SKILL_IRON_SKIN := &"skill.iron_skin"
const SKILL_LONG_STRIDE := &"skill.long_stride"
const SKILL_KEEN_EDGE := &"skill.keen_edge"
const SKILL_DEEP_LUNGS := &"skill.deep_lungs"

const UPGRADE_BACKPACK := &"upgrade.backpack"
const UPGRADE_CHARM := &"upgrade.charm"
const UPGRADE_WHETSTONE := &"upgrade.whetstone"
const UPGRADE_BOOTS := &"upgrade.boots"

# --- definitions -----------------------------------------------------------

## Every skill costs skill points and has a level cap. `cost` is per level, so a
## level-3 upgrade costs `cost * level` points for its next rank.
const SKILL_DEFS: Dictionary = {
	SKILL_DOUBLE_JUMP: {
		"title": "Second Wind",
		"description": "Jump again in mid-air. Tap jump while falling.",
		"max_level": 1,
		"cost": 1,
	},
	SKILL_HEAL_STEAL: {
		"title": "Hearth Draught",
		"description": "Landing a hit restores a little health.",
		"max_level": 1,
		"cost": 1,
	},
	SKILL_IRON_SKIN: {
		"title": "Mossy Hide",
		"description": "+15 maximum health per rank.",
		"max_level": 4,
		"cost": 1,
	},
	SKILL_LONG_STRIDE: {
		"title": "Long Stride",
		"description": "+8% walk and sprint speed per rank.",
		"max_level": 3,
		"cost": 1,
	},
	SKILL_KEEN_EDGE: {
		"title": "Keen Edge",
		"description": "+2 melee damage per rank.",
		"max_level": 4,
		"cost": 1,
	},
	SKILL_DEEP_LUNGS: {
		"title": "Deep Lungs",
		"description": "+12 maximum stamina per rank.",
		"max_level": 3,
		"cost": 1,
	},
}

## Shop upgrades cost coins. Price grows with the rank already owned.
const SHOP_DEFS: Dictionary = {
	UPGRADE_BACKPACK: {
		"title": "Deep Pockets",
		"description": "+6 backpack slots per rank.",
		"max_level": 3,
		"base_cost": 12,
		"step": 10,
	},
	UPGRADE_CHARM: {
		"title": "Hearth Charm",
		"description": "+10 maximum health per rank.",
		"max_level": 3,
		"base_cost": 18,
		"step": 12,
	},
	UPGRADE_WHETSTONE: {
		"title": "Whetstone",
		"description": "+1 melee damage per rank.",
		"max_level": 3,
		"base_cost": 15,
		"step": 10,
	},
	UPGRADE_BOOTS: {
		"title": "Pathfinder Boots",
		"description": "+5% walk and sprint speed per rank.",
		"max_level": 3,
		"base_cost": 14,
		"step": 10,
	},
}

## Lore pages hidden around the Hollow. Collect one and the Ledger remembers it.
const LORE_DEFS: Dictionary = {
	&"page.hollow_root": {
		"title": "Page I — The Hollow Root",
		"body": "The first settlers did not clear the woods. They asked the old roots for a place to stand, and the roots agreed. Every house in Mycelgrove is built between them, never through.",
	},
	&"page.thimble": {
		"title": "Page II — Thimble's Debt",
		"body": "Entry 47. Name: Thimble. Payment: Hearth-Silk. Debt: UNPAID. The name is crossed out. Underneath, in a different hand: they were never supposed to be counted.",
	},
	&"page.bell_oven": {
		"title": "Page III — The First Loaf",
		"body": "Auntie Bell's oven was the first thing lit in the Hollow. The Sporebread that came out of it fed the builders for a week, and the recipe has not changed since.",
	},
	&"page.seamstress_thread": {
		"title": "Page IV — Silk and String",
		"body": "Ghost Spider silk is gathered, never cut. A thread given freely will hold a roof; a thread taken will unravel by morning. The Seamstress knows the difference by touch.",
	},
	&"page.thatch_hive": {
		"title": "Page V — The Hive Tower",
		"body": "Thatch keeps bees the way Rowan keeps names: carefully, and for longer than anyone expects. The honey from the tower is said to taste of whatever the Hollow is worrying about.",
	},
	&"page.forest_edge": {
		"title": "Page VI — At the Forest Edge",
		"body": "The spiders came out of the dark between the trees when the fog first rose. They are not cruel. They are simply very far from home.",
	},
	&"page.last_entry": {
		"title": "Page VII — The Last Entry",
		"body": "If you are reading this, the Ledger has chosen you. Write plainly. Count honestly. And when the fog comes, keep a light close.",
	},
}

## Items sold for coins at the market, beside the randomized upgrades.
const STOCK: Dictionary = {
	&"item.sporebread": 8,
	&"item.health_potion": 15,
	# Stall goods: Bell's baking, Thatch's honey, and the Seamstress's thread.
	&"item.honey": 6,
	&"item.hearth_silk_thread": 18,
}

# --- progress state --------------------------------------------------------

static var _xp := 0
static var _level := 1
static var _skill_points := 0
static var _coins := 0
static var _skills: Dictionary = {}
static var _upgrades: Dictionary = {}
static var _offers: Array[StringName] = []
static var _ledger_pages: Dictionary = {}
static var _ledger_found := false
static var _favor: Dictionary = {}


static func reset() -> void:
	_xp = 0
	_level = 1
	_skill_points = 0
	_coins = 0
	_skills.clear()
	_upgrades.clear()
	_offers.clear()
	_ledger_pages.clear()
	_ledger_found = false
	_favor.clear()


# --- experience and levels -------------------------------------------------


static func get_level() -> int:
	return _level


static func get_xp() -> int:
	return _xp


## XP still needed for the next level.
static func xp_for_next_level() -> int:
	return 25 + (_level - 1) * 20


static func get_skill_points() -> int:
	return _skill_points


## Awards XP and levels up as many times as the total allows. Returns how many
## levels were gained so the caller can announce it.
static func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0

	_xp += amount
	var gained := 0
	while _xp >= xp_for_next_level():
		_xp -= xp_for_next_level()
		_level += 1
		_skill_points += 1
		gained += 1

	if gained > 0:
		Events.notification_requested.emit(
			"Level %d reached — %d skill point%s" % [
				_level, _skill_points, "" if _skill_points == 1 else "s"
			]
		)
	return gained


# --- coins -----------------------------------------------------------------


static func get_coins() -> int:
	return _coins


static func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount


static func spend_coins(amount: int) -> bool:
	if amount < 0 or _coins < amount:
		return false
	_coins -= amount
	return true


# --- skill tree ------------------------------------------------------------


static func get_skill_level(id: StringName) -> int:
	return int(_skills.get(id, 0))


static func has_skill(id: StringName) -> bool:
	return get_skill_level(id) > 0


static func get_skill_def(id: StringName) -> Dictionary:
	return SKILL_DEFS.get(id, {})


static func get_skill_cost(id: StringName) -> int:
	var def := get_skill_def(id)
	if def.is_empty():
		return 0
	return int(def.get("cost", 1)) * (get_skill_level(id) + 1)


static func can_unlock_skill(id: StringName) -> bool:
	var def := get_skill_def(id)
	if def.is_empty():
		return false
	if get_skill_level(id) >= int(def.get("max_level", 1)):
		return false
	return _skill_points >= get_skill_cost(id)


## Spends skill points on the next rank. Returns true when a rank was bought.
static func unlock_skill(id: StringName) -> bool:
	if not can_unlock_skill(id):
		return false
	_skill_points -= get_skill_cost(id)
	_skills[id] = get_skill_level(id) + 1
	return true


static func get_skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in SKILL_DEFS.keys():
		ids.append(StringName(id))
	return ids


# --- shop upgrades ---------------------------------------------------------


static func get_upgrade_level(id: StringName) -> int:
	return int(_upgrades.get(id, 0))


static func get_upgrade_def(id: StringName) -> Dictionary:
	return SHOP_DEFS.get(id, {})


static func get_upgrade_price(id: StringName) -> int:
	var def := get_upgrade_def(id)
	if def.is_empty():
		return 0
	var level := get_upgrade_level(id)
	return int(def.get("base_cost", 10)) + int(def.get("step", 5)) * level


static func can_buy_upgrade(id: StringName) -> bool:
	var def := get_upgrade_def(id)
	if def.is_empty():
		return false
	if get_upgrade_level(id) >= int(def.get("max_level", 1)):
		return false
	return _coins >= get_discounted_price(get_upgrade_price(id))


## Buys the next rank of a shop upgrade. Returns true on success.
static func buy_upgrade(id: StringName) -> bool:
	if not can_buy_upgrade(id):
		return false
	if not spend_coins(get_discounted_price(get_upgrade_price(id))):
		return false
	_upgrades[id] = get_upgrade_level(id) + 1
	return true


## Three upgrades offered this run. Randomized on a new game and after every
## purchase so two playthroughs see different shelves.
static func get_shop_offers() -> Array[StringName]:
	if _offers.is_empty():
		roll_shop_offers()
	return _offers.duplicate()


static func roll_shop_offers() -> void:
	var pool: Array[StringName] = []
	for id: Variant in SHOP_DEFS.keys():
		var key := StringName(id)
		var def := get_upgrade_def(key)
		if get_upgrade_level(key) < int(def.get("max_level", 1)):
			pool.append(key)

	pool.shuffle()
	_offers.clear()
	for i in mini(3, pool.size()):
		_offers.append(pool[i])

	# If everything is maxed out, fall back to the whole list so the panel still
	# has something to show.
	if _offers.is_empty():
		for id: Variant in SHOP_DEFS.keys():
			_offers.append(StringName(id))


# --- favor and discounts ---------------------------------------------------


static func get_favor(npc_id: StringName) -> int:
	return int(_favor.get(npc_id, 0))


## Increases a villager's favor. Returns the new value.
static func add_favor(npc_id: StringName, amount: int = 1) -> int:
	if npc_id == &"" or amount == 0:
		return get_favor(npc_id)
	var value := maxi(get_favor(npc_id) + amount, 0)
	_favor[npc_id] = value
	return value


## Discount offered by one villager: 5% per favor point, capped at 30%.
static func get_discount(npc_id: StringName) -> float:
	return minf(float(get_favor(npc_id)) * 0.05, 0.30)


## The market uses the best relationship the player has with any villager.
static func get_best_discount() -> float:
	var best := 0.0
	for value: Variant in _favor.values():
		best = maxf(best, minf(float(value) * 0.05, 0.30))
	return best


static func get_discounted_price(base_price: int) -> int:
	var price := float(base_price) * (1.0 - get_best_discount())
	return maxi(int(round(price)), 1)


# --- ledger ----------------------------------------------------------------


static func has_ledger() -> bool:
	return _ledger_found


static func set_ledger_found(found: bool = true) -> void:
	_ledger_found = found


static func add_ledger_page(id: StringName) -> bool:
	if id == &"" or _ledger_pages.has(id):
		return false
	_ledger_pages[id] = true
	return true


static func has_ledger_page(id: StringName) -> bool:
	return _ledger_pages.has(id)


static func get_ledger_pages() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _ledger_pages.keys():
		ids.append(StringName(id))
	return ids


static func get_ledger_page_count() -> int:
	return _ledger_pages.size()


static func get_lore_title(id: StringName) -> String:
	var def: Dictionary = LORE_DEFS.get(id, {})
	return String(def.get("title", ""))


static func get_lore_body(id: StringName) -> String:
	var def: Dictionary = LORE_DEFS.get(id, {})
	return String(def.get("body", ""))


static func get_stock() -> Dictionary:
	return STOCK.duplicate()


static func get_stock_price(item_id: StringName) -> int:
	return get_discounted_price(int(STOCK.get(item_id, 0)))


# --- persistence -----------------------------------------------------------


static func save_data() -> Dictionary:
	return {
		"xp": _xp,
		"level": _level,
		"skill_points": _skill_points,
		"coins": _coins,
		"skills": _id_dict_to_strings(_skills),
		"upgrades": _id_dict_to_strings(_upgrades),
		"offers": _offers.duplicate(),
		"ledger_pages": _ledger_pages.keys(),
		"ledger_found": _ledger_found,
		"favor": _id_dict_to_strings(_favor),
	}


static func load_data(data: Dictionary) -> void:
	reset()

	_xp = maxi(int(data.get("xp", 0)), 0)
	_level = maxi(int(data.get("level", 1)), 1)
	_skill_points = maxi(int(data.get("skill_points", 0)), 0)
	_coins = maxi(int(data.get("coins", 0)), 0)
	_ledger_found = bool(data.get("ledger_found", false))

	for id: Variant in data.get("skills", {}).keys():
		_skills[StringName(id)] = int((data["skills"] as Dictionary)[id])
	for id: Variant in data.get("upgrades", {}).keys():
		_upgrades[StringName(id)] = int((data["upgrades"] as Dictionary)[id])
	for id: Variant in data.get("favor", {}).keys():
		_favor[StringName(id)] = int((data["favor"] as Dictionary)[id])
	for id: Variant in data.get("ledger_pages", []):
		_ledger_pages[StringName(id)] = true

	_offers.clear()
	for id: Variant in data.get("offers", []):
		_offers.append(StringName(id))
	if _offers.is_empty():
		roll_shop_offers()


static func _id_dict_to_strings(source: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in source.keys():
		out[String(id)] = int(source[id])
	return out
