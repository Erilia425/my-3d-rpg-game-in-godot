class_name WorldMap
extends RefCounted
## The player's own map knowledge, one square at a time.
##
## A static service like `QuestLog` and `DiscoveryLog`: the project keeps its six
## approved autoloads, and there is exactly one map per running game. `Game`
## saves it inside the `world` block and clears it for a new game.
##
## The map is a coarse grid of `CELL_SIZE`-metre squares. Walking reveals the
## squares around you; the minimap draws only those. Nothing here is terrain
## data, so the fog costs one dictionary and no new scene.

## Metres per map square. 16 m keeps the saved dictionary small while still
## making a town look like a town on a 180 px minimap.
const CELL_SIZE := 16.0
## How far the player reveals the map as they walk.
const REVEAL_RADIUS := 26.0

## "x:z" -> true. String keys keep the save JSON simple and readable.
static var _seen: Dictionary = {}


static func reset() -> void:
	_seen.clear()


## Marks every square within `radius` of `at`. Returns true when at least one
## square was new, so callers can gate a "map updated" moment on it.
static func reveal(at: Vector3, radius: float = REVEAL_RADIUS) -> bool:
	var cell := Vector2i(floori(at.x / CELL_SIZE), floori(at.z / CELL_SIZE))
	var reach := int(ceil(radius / CELL_SIZE))
	var found := false
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var centre := Vector2(
				(cell.x + dx + 0.5) * CELL_SIZE, (cell.y + dz + 0.5) * CELL_SIZE
			)
			if centre.distance_to(Vector2(at.x, at.z)) > radius:
				continue
			var key := _key(cell.x + dx, cell.y + dz)
			if not _seen.has(key):
				_seen[key] = true
				found = true
	return found


static func is_seen(cell_x: int, cell_z: int) -> bool:
	return _seen.has(_key(cell_x, cell_z))


static func cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL_SIZE), floori(at.z / CELL_SIZE))


static func get_seen_count() -> int:
	return _seen.size()


static func save_data() -> Dictionary:
	return {"seen": _seen.keys()}


static func load_data(data: Dictionary) -> void:
	reset()
	for key: Variant in data.get("seen", []):
		_seen[String(key)] = true


static func _key(cell_x: int, cell_z: int) -> String:
	return "%d:%d" % [cell_x, cell_z]
