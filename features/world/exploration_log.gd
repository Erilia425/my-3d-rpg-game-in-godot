class_name ExplorationLog
extends RefCounted
## The places Rowan has actually walked, for the Field Notes checklist.
##
## A static service (no autoload), saved as `world.exploration`. Areas are
## circles on the ground rather than scene triggers: the HUD asks it once every
## half second where the player stands, so no new Area3D is needed and the
## checklist works in the continuous town without touching 39 interiors.
##
## It only records. The panel decides how to draw a tick.

## `centre` is XZ metres; `radius` is metres. The order is the reading order on
## the panel: the Hollow first, then the two outlying villages.
const AREAS: Array[Dictionary] = [
	{
		"id": &"place.market",
		"title": "Market Square",
		"note": "Stalls, carts, and the unlabelled machine.",
		"centre": Vector2(17, -9),
		"radius": 24.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.chapel_green",
		"title": "Chapel Green",
		"note": "The chapel, the bell tower, and the well between them.",
		"centre": Vector2(-4, 14),
		"radius": 15.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.bakery",
		"title": "Auntie Bell's Bakery",
		"note": "Sporebread, honey, and a back room with a lock.",
		"centre": Vector2(-28, 14.5),
		"radius": 12.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.rowans_house",
		"title": "Rowan's House",
		"note": "The family coin waits where it always waited.",
		"centre": Vector2(25, 9.5),
		"radius": 10.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.keepers",
		"title": "Keepers' Quarter",
		"note": "Ledgers, keys, and the keeper's office.",
		"centre": Vector2(35.5, -3.2),
		"radius": 13.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.bee_district",
		"title": "The Bee District",
		"note": "Honey store, thread cottages, and the Hive Tower.",
		"centre": Vector2(49, -34),
		"radius": 20.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.west_row",
		"title": "The West Row",
		"note": "The row cottages behind the square.",
		"centre": Vector2(-35, -27),
		"radius": 22.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.old_quarter",
		"title": "The Old Quarter",
		"note": "The seamstress's yew cottage and the loom tower.",
		"centre": Vector2(-38, -45),
		"radius": 18.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.ruins",
		"title": "The Old Settlement",
		"note": "Fallen houses north of the town, still counting.",
		"centre": Vector2(11, -74),
		"radius": 18.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.garden",
		"title": "The Communal Garden",
		"note": "A plot, a bench, and someone else's gnome.",
		"centre": Vector2(-25.5, 31),
		"radius": 14.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.south_odd_houses",
		"title": "The Odd Houses",
		"note": "The lanes that leave the Hollow to the south.",
		"centre": Vector2(12, 51),
		"radius": 16.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.old_adit",
		"title": "The Old Adit",
		"note": "Sea glass, pale gemstones, and a stone that remembers.",
		"centre": Vector2(18, -110),
		"radius": 20.0,
		"region": "The Hollow",
	},
	{
		"id": &"place.ashfall",
		"title": "Ashfall",
		"note": "Bog mud, cold lanterns, three doors that open.",
		"centre": Vector2(20, -300),
		"radius": 32.0,
		"region": "Beyond the Hollow",
	},
	{
		"id": &"place.thornridge",
		"title": "Thornridge",
		"note": "Slate, rust, standing stones, and a low stone bridge.",
		"centre": Vector2(330, 30),
		"radius": 32.0,
		"region": "Beyond the Hollow",
	},
]

static var _seen: Dictionary = {}
## Room scene base name -> display title, for rooms whose file name reads badly.
const ROOM_TITLES: Dictionary = {
	"rowans_house": "Rowan's House",
	"auntie_bells_bakery": "Auntie Bell's Bakery",
	"bakery_interior": "Auntie Bell's Bakery",
	"seamstress_cottage": "The Seamstress's Cottage",
	"hollow_house": "The Hollow House",
	"hive_tower": "The Hive Tower",
	"keeper_office": "The Keeper's Office",
	"thornridge_forge": "The Thornridge Forge",
	"thornridge_inn": "The Thornridge Inn",
	"ashfall_shrine": "The Ashfall Shrine",
	"ashfall_bothy": "The Ashfall Bothy",
	"old_loom_tower": "The Old Loom Tower",
}

## One written line per place, written down the first time it is ticked.
## Kept beside the areas rather than inside them so the area table stays a table.
const LINES: Dictionary = {
	&"place.market": "The square smells of wet stone and cut stems. Someone has swept it and someone else has not.",
	&"place.chapel_green": "Between the chapel and the bell tower there is a patch of grass nobody walks on. It is mown anyway.",
	&"place.bakery": "The bakery keeps its own weather. Warm at the door, cold at the back, and always the smell of spores rising.",
	&"place.rowans_house": "The house is exactly as it was left. That is the strange part, and not the coin.",
	&"place.keepers": "Ledgers, keys, and a lamp left burning. The keepers count things so the rest of us do not have to.",
	&"place.bee_district": "The hives hum at a pitch you feel in your teeth before you hear it.",
	&"place.west_row": "The row cottages lean on each other. Their doors face away from the square, on purpose.",
	&"place.old_quarter": "Yew, silk, and a loom that has been repaired more often than replaced.",
	&"place.ruins": "The old settlement stopped mid-sentence. The walls are still holding the shape of the rooms.",
	&"place.garden": "The communal beds are planted in rows that do not match each other. Everyone has their own idea of a garden.",
	&"place.south_odd_houses": "The lanes south of the Hollow were laid out by someone who was in a hurry, or was not.",
	&"place.old_adit": "Cold air, sea glass, and a stone that remembers out loud if you ask it properly.",
	&"place.ashfall": "Ash underfoot and a green so dark it reads as black. The lanterns here are lit for the cold, not for light.",
	&"place.thornridge": "Slate, rust, and stone stacked by people who did not trust the ground to stay put.",
}

static var _rooms: Dictionary = {}
const ROOM_PREFIX := "res://features/world/interiors/"


static func reset() -> void:
	_seen.clear()
	_rooms.clear()


static func has(id: StringName) -> bool:
	return _seen.has(id)


## Marks every area containing `at`. Returns the ids that were new, so the HUD
## can announce a first visit once.
static func check(at: Vector3) -> Array[StringName]:
	var fresh: Array[StringName] = []
	var point := Vector2(at.x, at.z)
	for area in AREAS:
		var id: StringName = area["id"]
		if _seen.has(id):
			continue
		var centre: Vector2 = area["centre"]
		if point.distance_to(centre) > float(area["radius"]):
			continue
		_seen[id] = true
		fresh.append(id)
	return fresh


static func get_title(id: StringName) -> String:
	for area in AREAS:
		if area["id"] == id:
			return String(area["title"])
	return ""


static func get_seen_count() -> int:
	return _seen.size()


static func get_total() -> int:
	return AREAS.size()


## The written line for a place, or "" for an unknown id.
static func get_line(id: StringName) -> String:
	return String(LINES.get(id, ""))


# --- rooms -----------------------------------------------------------------


## Records the interior the player is standing in. `scene_path` is the loaded
## scene's path and `root_name` its root node name (used for the title). Returns
## the room id only the first time it is entered, so callers can announce it.
##
## Interiors are counted by scene, not by position: every interior places the
## player near the origin, which would make a distance test meaningless.
static func note_scene(scene_path: String, root_name: String) -> StringName:
	if not scene_path.begins_with(ROOM_PREFIX):
		return &""
	var base := scene_path.get_file().get_basename()
	if base.is_empty():
		return &""
	var id := StringName("room." + base)
	if _rooms.has(id):
		return &""
	_rooms[id] = String(ROOM_TITLES.get(base, _prettify(root_name, base)))
	return id


## Turns `RowansHouseInterior` into `Rowans House` when there is no table entry.
static func _prettify(root_name: String, base: String) -> String:
	var source := root_name if not root_name.is_empty() else base
	source = source.replace("Interior", "")
	var words := ""
	for i in source.length():
		var c := source[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			words += " "
		words += c
	return words.strip_edges()


static func get_room_count() -> int:
	return _rooms.size()


## The display title of an entered room, or "" for an unknown id.
static func get_room_title(id: StringName) -> String:
	return String(_rooms.get(id, ""))


## Titles of the interiors entered so far, in the order they were entered.
static func get_rooms() -> Array[String]:
	var titles: Array[String] = []
	for title: Variant in _rooms.values():
		titles.append(String(title))
	return titles


static func save_data() -> Dictionary:
	var rooms := {}
	for id: Variant in _rooms:
		rooms[String(id)] = String(_rooms[id])
	return {"seen": _seen.keys(), "rooms": rooms}


static func load_data(data: Dictionary) -> void:
	reset()
	for id: Variant in data.get("seen", []):
		_seen[StringName(id)] = true
	for id: Variant in data.get("rooms", {}):
		_rooms[StringName(id)] = String(data["rooms"][id])
