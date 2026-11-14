extends Node
## One-off generator for `scenes/town.tscn` (Mycelgrove Hollow).
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/build_town.tscn
##
## Run as a *scene*, not with `--script`: the player, HUD, pause menu, and gate
## scripts reference autoloads, and autoloads only exist in a normal game start.
## Buildings, props, ribbons and the forest store only their exported settings in
## the scene; they build their geometry at `_ready()`, so the saved file stays a
## readable list of placements. Delete `tools/` once the scene is generated.
##
## NOTE: `scenes/town.tscn` is now hand-extended with a `Villagers` node. Re-running
## this generator rewrites the scene and drops those villagers, so re-add them or
## extend this script before regenerating.
##
## Map -> world conversion used for every location on the reference map:
##   x = (px - 656) * 0.14      z = (py - 600) * 0.14
## so the map's right side is east (+x) and its bottom is south (+z).

const OUT_PATH := "res://scenes/town.tscn"

const BUILDING_SCRIPT := preload("res://features/world/town/town_building.gd")
const PROP_SCRIPT := preload("res://features/world/town/town_prop.gd")
const RIBBON_SCRIPT := preload("res://features/world/town/town_ribbon.gd")
const FOREST_SCRIPT := preload("res://features/world/town/town_forest.gd")
const FALL_GUARD_SCRIPT := preload("res://features/world/fall_guard.gd")
const GATE_SCRIPT := preload("res://features/world/area_gate.gd")
const TOWN_SCRIPT := preload("res://features/world/town/town.gd")
const PLAYER_SCENE := preload("res://features/player/player.tscn")
const HUD_SCENE := preload("res://features/ui/hud.tscn")
const PAUSE_SCENE := preload("res://features/ui/pause_menu.tscn")

const STYLE := {"cottage": 0, "longhouse": 1, "chapel": 2, "tower": 3, "hive": 4, "ruin": 5}

const INTERIOR_DIR := "res://features/world/interiors/rooms"

## The bakery owns a hand-authored scene. Everything else gets a generated
## wrapper around the same `interior_room.gd`.
const BESPOKE_SCENES := {
	"AuntieBellsBakery": "res://features/world/interiors/bakery_interior.tscn",
}

## Building -> layout family. Every non-ruin building except the player's own
## cottage appears here, so the generator can open all of their doors.
const INTERIOR_LAYOUTS := {
	"Chapel": &"chapel",
	"BellTower": &"tower",
	"AuntieBellsBakery": &"bakery",
	"RowansHouse": &"longhouse",
	"ToothkeepersHouse": &"office",
	"ChapelCottage": &"cottage",
	"BellCottage": &"cottage",
	"EastRowCottage": &"cottage",
	"SouthRowCottage": &"cottage",
	"KeeperOffice": &"office",
	"GreenCottage": &"cottage",
	"NorthCottage": &"cottage",
	"FordCottage": &"cottage",
	"RowCottageA": &"cottage",
	"RowCottageB": &"cottage",
	"RowCottageC": &"cottage",
	"RowCottageD": &"cottage",
	"SeamstressCottage": &"seamstress",
	"OldLoomTower": &"loom",
	"OldCottage": &"abandoned",
	"OldCottageB": &"abandoned",
	"ThreadkeepersHouse": &"longhouse",
	"ThreadCottage": &"cottage",
	"BeekeeperCottage": &"cottage",
	"HiveTower": &"hive",
	"HoneyStore": &"store",
	"BeeCottage": &"cottage",
	"AbandonedHouse": &"abandoned",
	"AbandonedHouseB": &"abandoned",
	"EastCottage": &"cottage",
	"EastCottageB": &"cottage",
	"WestCottage": &"cottage",
	"WestCottageB": &"cottage",
	"GardenCottage": &"cottage",
	"ForestEdgeCottage": &"cottage",
	"OddHouse": &"cottage",
	"OddHouseB": &"cottage",
	"GoneHouse": &"abandoned",
	"GoneHouseB": &"abandoned",
}
const KIND := {
	"tree": 0, "pine": 1, "bush": 2, "well": 3, "stall": 4, "bridge": 5,
	"headstone": 6, "signpost": 7, "garden": 8, "bench": 9, "reeds": 10,
	"rock": 11, "haystack": 12, "lantern": 13, "fence": 14, "mushroom": 15,
	"flowers": 16,
}
const KIND_NAMES: Array[String] = [
	"Tree", "Pine", "Bush", "Well", "Stall", "Bridge", "Headstone", "Signpost",
	"GardenBed", "Bench", "Reeds", "Rock", "Haystack", "Lantern", "Fence",
	"Mushroom", "Flowers",
]

# Cottagecore palette. Walls are limewash over daub; roofs are patched thatch.
const WALL_CREAM := Color(0.77, 0.7, 0.55, 1)
const WALL_PALE := Color(0.72, 0.71, 0.64, 1)
const WALL_SAGE := Color(0.67, 0.68, 0.52, 1)
const WALL_HONEY := Color(0.8, 0.69, 0.47, 1)
const WALL_OCHRE := Color(0.75, 0.61, 0.4, 1)
const WALL_MOSSY := Color(0.57, 0.6, 0.47, 1)
const WALL_ASH := Color(0.52, 0.53, 0.47, 1)
const ROOF_THATCH := Color(0.52, 0.4, 0.22, 1)
const ROOF_RUST := Color(0.47, 0.31, 0.19, 1)
const ROOF_DARK := Color(0.39, 0.32, 0.21, 1)
const ROOF_MOSS := Color(0.4, 0.45, 0.27, 1)
const ROOF_SLATE := Color(0.43, 0.42, 0.38, 1)
const STONE := Color(0.47, 0.46, 0.42, 1)
const STONE_PALE := Color(0.6, 0.59, 0.55, 1)
const GROUND_GREEN := Color(0.23, 0.33, 0.17, 1)
const EARTH := Color(0.51, 0.43, 0.3, 1)
const BANK := Color(0.42, 0.36, 0.26, 1)
const WATER := Color(0.16, 0.34, 0.42, 0.62)

var _root: Node3D
var _buildings_root: Node3D
var _props_root: Node3D
var _paths_root: Node3D
var _gates_root: Node3D
var _rng := RandomNumberGenerator.new()
var _prop_counter := 0

## Every lane created by `_paths()`, kept so each door can be connected to the
## nearest street. Entries are `{name: String, points: PackedVector3Array}`.
var _lanes: Array[Dictionary] = []
## Every building placed by `_building()`, kept so `_approaches()` can find its
## door and, if the door faces away from the street, turn the house to face it.
var _placed: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = 987641

	_root = Node3D.new()
	_root.name = "Town"
	_root.set_script(TOWN_SCRIPT)

	_environment()
	_ground()
	_paths()
	_river()
	_buildings()
	_approaches()
	_props()
	_forest()
	_gates()
	_rooms()
	_interior_gates()
	_welcome_sign()
	_cast()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var packed := PackedScene.new()
	var error := packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, OUT_PATH)
	print("build_town: saved=%s error=%d" % [OUT_PATH, error])
	_root.free()
	get_tree().quit()


# --- staging ---------------------------------------------------------------


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.42, 0.66, 1)
	sky_material.sky_horizon_color = Color(0.79, 0.81, 0.75, 1)
	sky_material.ground_bottom_color = Color(0.16, 0.19, 0.14, 1)
	sky_material.ground_horizon_color = Color(0.5, 0.52, 0.43, 1)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.74, 0.78, 0.72, 1)
	environment.fog_density = 0.0022

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_attach(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -34, 0)
	sun.light_color = Color(1, 0.95, 0.84, 1)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_attach(sun)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(0, -0.25, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	_attach(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(212, 0.5, 212)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = TownParts.material(GROUND_GREEN, 0.97)
	_add(mesh_instance, body)

	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(212, 0.5, 212)
	collider.shape = shape
	_add(collider, body)

	# Broad, very subtle tone patches so the meadow is not one flat green.
	var patches := Node3D.new()
	patches.name = "MeadowPatches"
	_attach(patches)
	for i in 30:
		var at := Vector3(_rng.randf_range(-96, 96), 0.006, _rng.randf_range(-94, 94))
		var size := Vector3(_rng.randf_range(10.0, 32.0), 0.006, _rng.randf_range(10.0, 32.0))
		var patch := MeshInstance3D.new()
		patch.name = "Patch%d" % i
		var patch_mesh := BoxMesh.new()
		patch_mesh.size = size
		patch.mesh = patch_mesh
		patch.material_override = TownParts.material(
			GROUND_GREEN.lightened(_rng.randf_range(-0.02, 0.02)), 0.98
		)
		patch.position = at
		_add(patch, patches)


# --- water and roads -------------------------------------------------------


func _paths() -> void:
	var paths := Node3D.new()
	paths.name = "Paths"
	_attach(paths)
	_paths_root = paths

	# Main Village Street: west entrance, the chapel green, then east to the forest.
	_ribbon("MainStreet", paths, [
		Vector3(-98, 0, 13), Vector3(-78, 0, 9), Vector3(-58, 0, 7),
		Vector3(-40, 0, 6), Vector3(-20, 0, 3), Vector3(-4, 0, 1),
		Vector3(12, 0, -1), Vector3(26, 0, 0), Vector3(40, 0, 3),
		Vector3(54, 0, 6), Vector3(68, 0, 10), Vector3(86, 0, 13),
	], 3.4, EARTH, 0.03)

	# Left Residential Row lane, running along the front of the row cottages.
	_ribbon("ResidentialLane", paths, [
		Vector3(-56, 0, -21.0), Vector3(-48, 0, -21.4), Vector3(-40, 0, -21.6),
		Vector3(-32, 0, -21.4), Vector3(-24, 0, -21.0), Vector3(-18, 0, -19.0),
		Vector3(-12, 0, -14.0), Vector3(-7, 0, -8.0), Vector3(-3, 0, -2.0),
	], 2.8, EARTH, 0.031)

	# North road out of the village towards the Old Forest Road.
	_ribbon("NorthRoad", paths, [
		Vector3(4, 0, -2), Vector3(8, 0, -12), Vector3(13, 0, -24),
		Vector3(19, 0, -34), Vector3(26, 0, -42), Vector3(35, 0, -49),
		Vector3(44, 0, -55), Vector3(52, 0, -60), Vector3(56, 0, -70),
	], 2.8, EARTH, 0.03)

	# Honeyed Way: an arc along the east side of the beekeeper district, from the
	# market out towards the Hive Tower and the forest edge.
	_ribbon("HoneyedWay", paths, [
		Vector3(22, 0, -2), Vector3(28, 0, -7), Vector3(34, 0, -12),
		Vector3(41, 0, -17), Vector3(47, 0, -19), Vector3(54, 0, -22),
		Vector3(60, 0, -26), Vector3(65, 0, -31), Vector3(68, 0, -37),
		Vector3(72, 0, -45),
	], 2.4, EARTH, 0.032)

	# Footpath to the cemetery.
	_ribbon("CemeteryPath", paths, [
		Vector3(38, 0, -46), Vector3(31, 0, -51), Vector3(25, 0, -55),
		Vector3(19, 0, -59), Vector3(15, 0, -62),
	], 1.8, EARTH, 0.033)

	# Footpath to the Old Settlement Ruins.
	_ribbon("RuinsPath", paths, [
		Vector3(19, 0, -34), Vector3(15, 0, -44), Vector3(11, 0, -54),
		Vector3(8, 0, -62), Vector3(6, 0, -67),
	], 1.8, EARTH, 0.034)

	# Old Quarter lane: a loop past the old cottages that meets the residential
	# lane in the west and the ruins path in the north.
	_ribbon("OldQuarterLane", paths, [
		Vector3(-58, 0, -30), Vector3(-52, 0, -31.5), Vector3(-46, 0, -33),
		Vector3(-40, 0, -34), Vector3(-34, 0, -33), Vector3(-28, 0, -33),
		Vector3(-22, 0, -35), Vector3(-17, 0, -39), Vector3(-13.5, 0, -45),
		Vector3(-10.5, 0, -51), Vector3(-10.5, 0, -58), Vector3(-10.5, 0, -64),
	], 2.0, EARTH, 0.032)

	# South Road along the river, crossing all three southern bridges.
	_ribbon("SouthRoad", paths, [
		Vector3(-62, 0, 30), Vector3(-52, 0, 30.5), Vector3(-40, 0, 31),
		Vector3(-33, 0, 31.6), Vector3(-26, 0, 32.2), Vector3(-19, 0, 32.8),
		Vector3(-10, 0, 34), Vector3(-2, 0, 37), Vector3(6.2, 0, 40.6),
		Vector3(18, 0, 42), Vector3(30, 0, 43), Vector3(42, 0, 45),
		Vector3(52, 0, 46), Vector3(64, 0, 47.5), Vector3(78, 0, 49),
	], 3.0, EARTH, 0.03)

	# Communal garden loop.
	_ribbon("GardenPath", paths, [
		Vector3(-30, 0, 20), Vector3(-22, 0, 22), Vector3(-16, 0, 24),
		Vector3(-9, 0, 26.6), Vector3(-2, 0, 27), Vector3(4, 0, 25),
		Vector3(10, 0, 22), Vector3(14, 0, 18), Vector3(16, 0, 12),
	], 2.2, EARTH, 0.031)

	# East bank lane to Bramble Span.
	_ribbon("EastBankLane", paths, [
		Vector3(44, 0, 4), Vector3(54, 0, 2), Vector3(64, 0, 0),
		Vector3(72.7, 0, -2.8), Vector3(82, 0, -7),
	], 2.4, EARTH, 0.033)


func _river() -> void:
	var water := Node3D.new()
	water.name = "Water"
	_attach(water)

	var south := _river_points([
		Vector3(-106, 0, 24), Vector3(-74, 0, 27), Vector3(-52, 0, 29),
		Vector3(-40, 0, 30.6), Vector3(-26, 0, 32.2), Vector3(-8, 0, 35.5),
		Vector3(6.2, 0, 40.6), Vector3(24, 0, 43.2), Vector3(38, 0, 44.6),
		Vector3(52, 0, 46), Vector3(66, 0, 47.5), Vector3(86, 0, 49),
		Vector3(106, 0, 50),
	])
	var east := _river_points([
		Vector3(106, 0, -10), Vector3(88, 0, -9), Vector3(74, 0, -4),
		Vector3(68, 0, 6), Vector3(62, 0, 16), Vector3(57, 0, 27),
		Vector3(54, 0, 36), Vector3(54, 0, 43),
	])

	# Muddy bank underneath, then the translucent water sheet on top. Both are
	# flat: the player wades rather than swims.
	_ribbon("SouthBank", water, south, 6.4, BANK, 0.02)
	_ribbon("EastBank", water, east, 6.0, BANK, 0.02)
	_ribbon("SouthRiver", water, south, 3.8, WATER, 0.055, true, true)
	_ribbon("EastRiver", water, east, 3.6, WATER, 0.057, true, true)


func _river_points(points: Variant) -> PackedVector3Array:
	var packed := PackedVector3Array()
	for point in points:
		packed.append(point as Vector3)
	return packed


func _ribbon(
	node_name: String,
	parent: Node3D,
	points: Variant,
	width: float,
	color: Color,
	surface: float,
	transparent: bool = false,
	ripples: bool = false
) -> void:
	var ribbon: Node3D = RIBBON_SCRIPT.new()
	ribbon.name = node_name
	ribbon.set("points", _river_points(points))
	ribbon.set("width", width)
	ribbon.set("color", color)
	ribbon.set("surface_height", surface)
	ribbon.set("transparent", transparent)
	ribbon.set("ripples", ripples)
	ribbon.set("seed_value", abs(hash(node_name)) % 50000 + 3)
	_add(ribbon, parent)

	if parent == _paths_root and not transparent:
		_lanes.append({"name": node_name, "points": _river_points(points), "width": width})


# --- buildings -------------------------------------------------------------


func _buildings() -> void:
	_buildings_root = Node3D.new()
	_buildings_root.name = "Buildings"
	_attach(_buildings_root)

	# Central Hollow, south side of Main Street (doors face the street, north).
	_building("Chapel", "chapel", -7.1, 14.5, 0.0, Vector2(7, 9), {
		"wall_height": 3.8, "roof_height": 2.4, "label": "The Chapel",
		"wall_color": WALL_PALE, "roof_color": ROOF_SLATE, "stone_color": STONE_PALE,
	})
	_building("BellTower", "tower", 6.9, 12.6, 0.0, Vector2(4.6, 4.6), {
		"wall_height": 9.0, "label": "Bell Tower",
		"wall_color": WALL_PALE, "roof_color": ROOF_SLATE, "stone_color": STONE,
	})
	_building("AuntieBellsBakery", "longhouse", -28.0, 14.5, 8.0, Vector2(10, 6.4), {
		"wall_height": 3.0, "roof_height": 2.1, "label": "Auntie Bell's Bakery",
		"wall_color": WALL_OCHRE, "roof_color": ROOF_RUST,
	})
	_building("RowansHouse", "longhouse", 25.0, 9.5, -6.0, Vector2(9, 6.5), {
		"wall_height": 3.2, "roof_height": 2.2, "label": "Rowan's House",
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})
	_building("ToothkeepersHouse", "cottage", 55.0, 14.5, -14.0, Vector2(8, 6.5), {
		"wall_height": 3.1, "label": "Toothkeeper's House",
		"wall_color": WALL_HONEY, "roof_color": ROOF_DARK,
	})
	_building("ChapelCottage", "cottage", -15.0, 17.0, 22.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})
	_building("BellCottage", "cottage", 16.5, 21.5, -18.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})
	_building("EastRowCottage", "cottage", 38.5, 14.0, 180.0, Vector2(7, 6), {
		"wall_color": WALL_SAGE, "roof_color": ROOF_THATCH,
	})
	_building("SouthRowCottage", "cottage", 29.0, 20.5, 0.0, Vector2(7, 6.5), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})

	# Central Hollow, north side of Main Street (doors face south).
	_building("KeeperOffice", "longhouse", 35.5, -3.2, 180.0, Vector2(8, 6), {
		"wall_color": WALL_HONEY, "roof_color": ROOF_DARK,
	})
	_building("GreenCottage", "cottage", -14.0, -8.0, 150.0, Vector2(7, 6), {
		"wall_color": WALL_SAGE, "roof_color": ROOF_THATCH,
	})
	_building("NorthCottage", "cottage", -26.0, -6.0, 200.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_RUST,
	})
	_building("FordCottage", "cottage", 47.0, -11.0, 120.0, Vector2(7, 6), {
		"wall_color": WALL_HONEY, "roof_color": ROOF_RUST,
	})

	# Left Residential Row. "HomeCottage" is the player's own cottage. The row is
	# spaced so no two houses share a wall: neighbours are 1-2 m apart, and the
	# front gardens have room between the walls and the lane.
	_building("HomeCottage", "longhouse", -40.0, -27.5, 180.0, Vector2(8, 6), {
		"wall_height": 3.1, "roof_height": 2.2,
		"wall_color": WALL_HONEY, "roof_color": ROOF_MOSS,
	})
	_building("RowCottageA", "cottage", -52.0, -27.5, 178.0, Vector2(7, 6), {
		"wall_color": WALL_SAGE, "roof_color": ROOF_THATCH,
	})
	_building("RowCottageB", "cottage", -31.5, -27.5, 182.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_RUST,
	})
	_building("RowCottageC", "cottage", -23.5, -27.5, 179.0, Vector2(7, 6), {
		"wall_color": WALL_MOSSY, "roof_color": ROOF_MOSS,
	})
	_building("RowCottageD", "cottage", -15.5, -27.5, 181.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})

	# Old Quarter.
	_building("SeamstressCottage", "cottage", -44.0, -49.0, 135.0, Vector2(8, 6), {
		"label": "Seamstress's Yew Cottage",
		"wall_color": WALL_MOSSY, "roof_color": ROOF_MOSS,
	})
	_building("OldLoomTower", "tower", -15.0, -57.0, 12.0, Vector2(5, 5), {
		"wall_height": 11.0, "ruined": true, "label": "Old Loom Tower",
		"wall_color": WALL_ASH, "roof_color": ROOF_DARK, "stone_color": STONE,
	})
	_building("OldCottage", "cottage", -34.0, -44.0, 120.0, Vector2(7, 6), {
		"wall_color": WALL_ASH, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("OldCottageB", "cottage", -27.0, -38.0, 140.0, Vector2(6, 5.5), {
		"wall_color": WALL_MOSSY, "roof_color": ROOF_MOSS, "has_chimney": false,
	})

	# Keeper's Quarter and Beekeeper District. The quarter sits west of the
	# Honeyed Way; the road arcs around its east side so no lane cuts a wall.
	_building("ThreadkeepersHouse", "longhouse", 36.0, -22.0, 90.0, Vector2(11, 7), {
		"wall_height": 4.0, "roof_height": 2.4, "label": "Threadkeeper's House",
		"wall_color": WALL_HONEY, "roof_color": ROOF_DARK,
	})
	_building("ThreadCottage", "cottage", 46.5, -28.0, 0.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_RUST,
	})
	_building("BeekeeperCottage", "cottage", 49.5, -41.5, 0.0, Vector2(7, 6), {
		"wall_color": WALL_OCHRE, "roof_color": ROOF_DARK,
	})
	_building("HiveTower", "hive", 61.0, -38.0, 0.0, Vector2(5, 5), {
		"wall_height": 10.0, "label": "Hive Tower",
		"wall_color": WALL_OCHRE, "roof_color": ROOF_RUST,
	})
	_building("HoneyStore", "longhouse", 34.0, -34.0, 90.0, Vector2(8, 6), {
		"wall_color": WALL_OCHRE, "roof_color": ROOF_MOSS,
	})
	_building("BeeCottage", "cottage", 54.5, -31.5, 0.0, Vector2(6, 5.5), {
		"wall_color": WALL_OCHRE, "roof_color": ROOF_THATCH,
	})

	# Abandoned houses, cemetery edge, and the Old Settlement Ruins.
	_building("AbandonedHouse", "cottage", 25.0, -27.0, 160.0, Vector2(7, 6), {
		"wall_color": WALL_ASH, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("AbandonedHouseB", "cottage", 23.0, -45.0, 120.0, Vector2(6, 5.5), {
		"wall_color": WALL_ASH, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("AbandonedRuin", "ruin", 6.0, -47.0, 30.0, Vector2(8, 7), {
		"wall_color": WALL_ASH,
	})
	_building("RuinsA", "ruin", 0.0, -70.0, 10.0, Vector2(10, 8), {"wall_color": WALL_ASH})
	_building("RuinsB", "ruin", 11.0, -75.0, 40.0, Vector2(8, 10), {"wall_color": WALL_ASH})
	_building("RuinsC", "ruin", 23.0, -77.0, -15.0, Vector2(9, 9), {"wall_color": WALL_ASH})

	# Forest-edge and riverside houses.
	_building("EastCottage", "cottage", 68.0, 18.0, 180.0, Vector2(7, 6), {
		"wall_color": WALL_SAGE, "roof_color": ROOF_THATCH,
	})
	_building("EastCottageB", "cottage", 58.0, -4.0, 160.0, Vector2(6, 5.5), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_RUST,
	})
	_building("WestCottage", "cottage", -52.0, 2.0, 90.0, Vector2(7, 6), {
		"wall_color": WALL_CREAM, "roof_color": ROOF_THATCH,
	})
	_building("WestCottageB", "cottage", -58.0, 20.0, 75.0, Vector2(7, 6), {
		"wall_color": WALL_MOSSY, "roof_color": ROOF_MOSS,
	})
	_building("GardenCottage", "cottage", -19.0, 29.0, 90.0, Vector2(7, 6), {
		"wall_color": WALL_OCHRE, "roof_color": ROOF_RUST,
	})
	_building("ForestEdgeCottage", "cottage", 70.0, -16.0, 180.0, Vector2(7, 6), {
		"wall_color": WALL_MOSSY, "roof_color": ROOF_MOSS,
	})

	# South of the river: the odd pair, and the ones that went missing.
	_building("OddHouse", "cottage", 8.0, 49.0, -25.0, Vector2(6, 5.5), {
		"wall_color": WALL_PALE, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("OddHouseB", "cottage", 16.5, 54.0, 15.0, Vector2(6, 5.5), {
		"wall_color": WALL_PALE, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("GoneHouse", "cottage", -50.0, 43.5, 30.0, Vector2(6, 5.5), {
		"wall_color": WALL_ASH, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("GoneHouseB", "cottage", -43.5, 51.0, 80.0, Vector2(5, 5), {
		"wall_color": WALL_ASH, "roof_color": ROOF_MOSS, "has_chimney": false,
	})
	_building("GoneRuin", "ruin", -39.0, 44.5, 0.0, Vector2(6, 6), {"wall_color": WALL_ASH})


func _building(
	node_name: String,
	style: String,
	x: float,
	z: float,
	facing: float,
	footprint: Vector2,
	extra: Dictionary = {}
) -> void:
	var node: Node3D = BUILDING_SCRIPT.new()
	node.name = node_name
	node.position = Vector3(x, 0.0, z)
	node.set("style", int(STYLE[style]))
	node.set("footprint", footprint)
	node.set("facing_degrees", facing)
	node.set("seed_value", abs(hash(node_name)) % 100000 + 11)
	for key in extra:
		node.set(key, extra[key])
	_add(node, _buildings_root)
	_placed.append({
		"name": node_name,
		"at": Vector2(x, z),
		"facing": facing,
		"footprint": footprint,
		"style": int(STYLE[style]),
		"node": node,
	})


# --- door approaches -------------------------------------------------------


## Every door gets a short footpath to the nearest street. If the door faces
## away from that street, the house is turned to face it first: a front door
## opening onto bare meadow is the loudest way to make a village feel fake.
##
## Runs after `_buildings()` and before `_props()`, so the place I turn a house
## is the place the hand-placed garden props have to respect.
func _approaches() -> void:
	var base_lanes: Array[Dictionary] = _lanes.duplicate()
	for entry in _placed:
		if int(entry["style"]) == int(STYLE["ruin"]):
			continue
		_approach(entry, base_lanes)


func _approach(entry: Dictionary, base_lanes: Array[Dictionary]) -> void:
	var at: Vector2 = entry["at"]
	var facing := float(entry["facing"])
	var local := _door_local(entry)
	# Godot's Y rotation and Vector2.rotated turn in opposite directions, so the
	# local door offset uses the negative angle. Getting this wrong mirrors every
	# spur through its own house.
	var door := at + local.rotated(-deg_to_rad(facing))
	var direction := Vector2(-sin(deg_to_rad(facing)), -cos(deg_to_rad(facing)))

	var target := _nearest_lane(base_lanes, door, direction, true)
	if target == Vector2.INF:
		target = _nearest_lane(base_lanes, door, direction, false)
	if target == Vector2.INF:
		return

	var to_lane := (target - door).normalized()
	if to_lane.dot(direction) < 0.25:
		facing = rad_to_deg(atan2(-to_lane.x, -to_lane.y))
		entry["facing"] = facing
		# The export is what the saved scene reloads, so it has to change too;
		# setting only rotation.y would be undone by the building's `_ready()`.
		(entry["node"] as Node3D).set("facing_degrees", facing)
		(entry["node"] as Node3D).rotation.y = deg_to_rad(facing)
		door = at + local.rotated(-deg_to_rad(facing))
		direction = (target - door).normalized()

	if door.distance_to(target) < 1.2:
		return

	var from := door + direction * 0.6
	_ribbon("%sPath" % entry["name"], _paths_root, [
		Vector3(from.x, 0.0, from.y),
		Vector3(target.x, 0.0, target.y),
	], 1.25, EARTH, 0.032)


## Where the door stands, in the building's own space.
func _door_local(entry: Dictionary) -> Vector2:
	var footprint: Vector2 = entry["footprint"]
	var style := int(entry["style"])
	if style == int(STYLE["chapel"]):
		return Vector2(0.0, -footprint.y * 0.5 - 2.0)
	if style == int(STYLE["tower"]):
		return Vector2(0.0, -footprint.x * 0.5 * 1.02)
	if style == int(STYLE["hive"]):
		return Vector2(0.0, -footprint.x * 0.5 * 0.98)
	return Vector2(0.0, -footprint.y * 0.5 - 0.06)


## Closest point on any lane. `front_only` restricts the search to the half
## plane the door faces, so a house between two streets prefers its own side.
func _nearest_lane(
	lanes: Array[Dictionary],
	from: Vector2,
	direction: Vector2,
	front_only: bool
) -> Vector2:
	var best := Vector2.INF
	var best_score := INF
	for lane in lanes:
		var points: PackedVector3Array = lane["points"]
		for i in points.size() - 1:
			var a := Vector2(points[i].x, points[i].z)
			var b := Vector2(points[i + 1].x, points[i + 1].z)
			var hit := Geometry2D.get_closest_point_to_segment(from, a, b)
			var offset := hit - from
			var distance := offset.length()
			if distance < 0.6:
				return hit
			if distance > 24.0:
				continue
			var dot := offset.normalized().dot(direction)
			if front_only and dot < -0.1:
				continue
			var score := distance - dot * 2.0
			if score < best_score:
				best_score = score
				best = hit
	return best


## True when a point is within `reach` of any lane, spur paths included.
func _near_lane(x: float, z: float, reach: float) -> bool:
	var at := Vector2(x, z)
	for lane in _lanes:
		var points: PackedVector3Array = lane["points"]
		for i in points.size() - 1:
			var a := Vector2(points[i].x, points[i].z)
			var b := Vector2(points[i + 1].x, points[i + 1].z)
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) < reach:
				return true
	return false


# --- props -----------------------------------------------------------------


func _props() -> void:
	_props_root = Node3D.new()
	_props_root.name = "Props"
	_attach(_props_root)

	# Bridges over the river (deck length runs along local z).
	_bridge(-26.0, 32.2, 2.0, 3.2, 11.0)
	_bridge(6.2, 40.6, 2.0, 3.2, 11.0)
	_bridge(52.0, 46.0, 4.0, 3.2, 11.0)
	_bridge(72.7, -2.8, 14.0, 3.4, 12.0)

	# Wells and market square.
	_well(-45.6, 7.7)
	_well(45.4, 26.6)
	var accents: Array[Color] = [
		Color(0.62, 0.24, 0.22, 1), Color(0.72, 0.55, 0.22, 1),
		Color(0.32, 0.44, 0.28, 1), Color(0.45, 0.3, 0.45, 1),
		Color(0.3, 0.4, 0.5, 1),
	]
	_stall(12.0, -7.0, 200.0, accents[0])
	_stall(23.5, -6.5, 160.0, accents[1])
	_stall(25.0, -14.0, 20.0, accents[2])
	_stall(13.5, -15.5, 20.0, accents[3])
	_stall(18.5, -4.0, 180.0, accents[4])

	# The Hollow Oak, with benches in its shade.
	_tree(-2.0, -8.0, 11.0, 4.2)
	_bench(-4.5, -11.5, 100.0)
	_bench(2.5, -4.5, 250.0)

	# The player's cottage: a lantern beside the door, herbs, mushrooms, and a
	# bench, all on the narrow verge between the front wall and the lane. Keep
	# the 2.6 m door band (x -41.3 to -38.7) clear so the doorway stays obvious.
	_lantern(-41.7, -23.15)
	_mushrooms(-43.4, -23.4, 1.2)
	_mushrooms(-34.9, -23.5, 0.9)
	_flowers(-43.6, -23.6, 1.1, Color(0.78, 0.62, 0.86, 1))
	_garden_bed(-43.0, -23.4, 2.4, 1.0, 0.0)
	_bench(-36.5, -23.5, 180.0)
	_fence(-45.6, -23.4, 3.0, 0.0)
	_signpost(-38.3, -23.1, "Home", 0.0)

	# Residential row dressing.
	_bush(-47.2, -23.9, 0.8)
	_bush(-34.6, -23.9, 0.7)
	_mushrooms(-28.9, -23.2, 1.0)
	_lantern(-31.2, -23.6)
	_flowers(-46.5, -23.6, 1.0, Color(0.86, 0.72, 0.42, 1))

	# Chapel green and the bell tower.
	_flowers(-12.4, 12.0, 1.2, Color(0.82, 0.68, 0.88, 1))
	_bush(-2.4, 12.6, 0.9)
	_bench(1.0, 15.5, 180.0)
	_lantern(-9.4, 7.2)
	_tree(12.5, 16.5, 5.0, 2.0)
	_signpost(-13.5, 9.5, "Chapel Hill", 180.0)

	# Bakery frontage.
	_haystack(-32.5, 24.5)
	_haystack(-23.5, 25.0)
	_bush(-17.6, 12.6, 0.8)
	_lantern(-23.0, 11.8)
	_flowers(-30.5, 10.7, 1.0, Color(0.92, 0.68, 0.52, 1))

	# Market square greenery.
	_mushrooms(5.5, -13.0, 1.1)
	_bench(16.0, -18.0, 0.0)
	_lantern(11.0, -5.0)
	_bush(27.0, -10.0, 0.9)
	_mushrooms(26.5, -11.0, 0.8)

	# Rowans / Toothkeeper / east lane.
	_lantern(29.0, 5.5)
	_lantern(46.0, 8.5)
	_bush(50.0, 9.5, 0.8)
	_flowers(44.0, 12.0, 1.0, Color(0.86, 0.74, 0.5, 1))
	_lantern(63.5, 8.5)
	_signpost(67.5, 0.5, "To the Forest Edge", 140.0)
	_bush(73.5, 14.5, 0.9)
	# Children's Green.
	_bench(-33.0, -11.0, 0.0)
	_bench(-30.5, -2.0, 180.0)
	_tree(-35.0, -14.0, 5.5, 2.2)
	_flowers(-30.0, -13.5, 1.3, Color(0.8, 0.66, 0.84, 1))

	# Communal garden. Beds sit in two rows between the loop path and the river
	# road, clear of the GardenCottage on their west.
	for i in 6:
		var bed_row := i / 3
		var bed_column := i % 3
		_garden_bed(-13.0 + bed_column * 5.0, 29.0 + bed_row * 2.0, 2.6, 1.4, 0.0)
	_fence(-15.2, 30.3, 4.0, 90.0)
	_well(4.0, 31.5)
	_haystack(-24.0, 28.0)
	_flowers(-6.0, 22.0, 1.4, Color(0.9, 0.72, 0.4, 1))

	# Beekeeper district: hives, flowers, honey-scented clutter.
	_bush(52.0, -26.5, 0.9)
	_flowers(55.0, -27.0, 1.4, Color(0.92, 0.78, 0.3, 1))
	_flowers(59.5, -28.0, 1.2, Color(0.94, 0.84, 0.44, 1))
	_mushrooms(57.0, -42.0, 1.0)
	_lantern(46.0, -22.0)
	_flowers(38.0, -38.0, 1.1, Color(0.9, 0.76, 0.36, 1))
	_lantern(41.5, -21.0)

	# Old Quarter.
	_mushrooms(-36.5, -52.5, 1.3)
	_mushrooms(-18.0, -59.5, 1.1)
	_tree(-24.0, -52.0, 6.5, 2.4)
	_bush(-40.0, -47.0, 0.8)
	_lantern(-19.0, -51.0)

	# Cemetery. Stones are scattered across the plot but never on the two paths
	# that cross the graves, and never so close together that they merge.
	var stones: Array[Vector2] = []
	for attempt in 800:
		if stones.size() >= 22:
			break
		var x := _rng.randf_range(4.5, 20.0)
		var z := _rng.randf_range(-64.5, -55.0)
		if _near_lane(x, z, 2.1):
			continue
		var crowded := false
		for stone in stones:
			if Vector2(x, z).distance_to(stone) < 1.8:
				crowded = true
				break
		if crowded:
			continue
		stones.append(Vector2(x, z))
	for stone in stones:
		_headstone(stone.x, stone.y, _rng.randf_range(0.7, 1.15))
	_pine(-7.0, -63.0, 7.0)
	_pine(21.0, -64.0, 6.0)
	_lantern(18.5, -54.0)

	# Old Settlement Ruins approaches.
	_rock(-3.0, -64.0, 1.4)
	_rock(18.0, -68.0, 1.8)
	_pine(-8.0, -76.0, 8.0)
	_pine(28.0, -72.0, 7.5)

	# North gate and east bridge approaches.
	_signpost(49.0, -57.8, "Old Forest Road", 200.0)
	_lantern(55.0, -56.5)
	_lantern(70.0, -7.0)
	_reeds(78.0, -8.0)
	_reeds(66.0, -6.0)
	_reeds(60.0, -6.5)
	# South road and river banks.
	_signpost(-51.0, 33.6, "South Road", 200.0)
	_reeds(-34.0, 34.5)
	_reeds(-20.0, 35.6)
	_reeds(-4.0, 38.6)
	_reeds(14.0, 42.2)
	_reeds(30.0, 44.2)
	_reeds(44.0, 47.2)
	_reeds(60.0, 49.0)
	_reeds(57.0, 33.0)
	_reeds(62.0, 18.0)
	_lantern(-33.0, 28.0)
	_lantern(28.0, 40.5)

	# Scattered field stones and bushes at the town edge.
	_rock(-57.5, -34.0, 1.6)
	_rock(-60.0, -1.0, 2.0)
	_rock(64.0, 22.0, 1.7)
	_rock(39.0, -56.0, 1.5)
	_rock(-32.0, 50.0, 1.9)
	_rock(30.0, 58.0, 1.6)
	_rock(64.0, -33.5, 1.4)
	_bush(-50.0, -12.0, 0.9)
	_bush(-55.0, 16.0, 0.8)
	_bush(34.0, 18.0, 0.9)
	_bush(-22.0, 8.5, 0.8)
	_bush(58.0, 4.0, 0.9)
	_tree(-48.0, 22.0, 5.5, 2.2)
	_tree(8.0, 30.0, 5.0, 2.0)
	_tree(46.0, 12.0, 5.5, 2.1)
	_tree(61.0, 28.0, 6.0, 2.4)
	_pine(-58.0, -38.0, 8.0)
	_pine(66.0, -22.0, 7.5)
	_pine(40.0, 54.0, 8.0)
	_pine(-55.0, 54.0, 8.5)


func _prop(kind: int, x: float, z: float, extra: Dictionary = {}) -> void:
	_prop_counter += 1
	var node: Node3D = PROP_SCRIPT.new()
	node.name = "%s%03d" % [KIND_NAMES[kind], _prop_counter]
	node.position = Vector3(x, 0.0, z)
	node.set("kind", kind)
	node.set("seed_value", abs(hash(node.name)) % 90000 + 7)
	for key in extra:
		node.set(key, extra[key])
	_add(node, _props_root)


func _tree(x: float, z: float, height: float = 4.0, radius: float = 1.9) -> void:
	_prop(KIND["tree"], x, z, {
		"size": Vector3(radius, height, 1.0),
		"facing_degrees": _rng.randf() * 360.0,
	})


func _pine(x: float, z: float, height: float = 6.0) -> void:
	_prop(KIND["pine"], x, z, {
		"size": Vector3(1.0, height, 1.0),
		"facing_degrees": _rng.randf() * 360.0,
	})


func _bush(x: float, z: float, radius: float = 0.7) -> void:
	_prop(KIND["bush"], x, z, {"size": Vector3(radius, radius, 1.0)})


func _mushrooms(x: float, z: float, scale: float = 1.0) -> void:
	_prop(KIND["mushroom"], x, z, {"size": Vector3(scale, scale, scale)})


func _flowers(x: float, z: float, scale: float = 1.0, colour: Color = Color(0.85, 0.7, 0.5, 1)) -> void:
	_prop(KIND["flowers"], x, z, {"size": Vector3(scale, scale, scale), "accent": colour})


func _lantern(x: float, z: float) -> void:
	_prop(KIND["lantern"], x, z, {"facing_degrees": _rng.randf() * 360.0})


func _bench(x: float, z: float, facing: float = 0.0) -> void:
	_prop(KIND["bench"], x, z, {"facing_degrees": facing})


func _signpost(x: float, z: float, text: String, facing: float = 0.0) -> void:
	_prop(KIND["signpost"], x, z, {"text": text, "facing_degrees": facing})


func _stall(x: float, z: float, facing: float, accent: Color) -> void:
	_prop(KIND["stall"], x, z, {
		"facing_degrees": facing,
		"accent": accent,
		"size": Vector3(2.8, 1.0, 1.8),
	})


func _garden_bed(x: float, z: float, width: float, depth: float, facing: float = 0.0) -> void:
	_prop(KIND["garden"], x, z, {
		"size": Vector3(width, 1.0, depth),
		"facing_degrees": facing,
	})


func _fence(x: float, z: float, length: float, facing: float = 0.0) -> void:
	_prop(KIND["fence"], x, z, {"size": Vector3(length, 1.0, 1.0), "facing_degrees": facing})


func _headstone(x: float, z: float, height: float) -> void:
	_prop(KIND["headstone"], x, z, {"size": Vector3(1.0, height, 1.0)})


func _reeds(x: float, z: float) -> void:
	_prop(KIND["reeds"], x, z, {"facing_degrees": _rng.randf() * 360.0})


func _rock(x: float, z: float, scale: float = 1.0) -> void:
	_prop(KIND["rock"], x, z, {"size": Vector3(scale, scale, scale)})


func _haystack(x: float, z: float) -> void:
	_prop(KIND["haystack"], x, z)


func _well(x: float, z: float) -> void:
	_prop(KIND["well"], x, z)


func _bridge(x: float, z: float, facing: float, width: float, length: float) -> void:
	_prop(KIND["bridge"], x, z, {
		"facing_degrees": facing,
		"size": Vector3(width, 1.0, length),
	})


# --- forest ----------------------------------------------------------------


func _forest() -> void:
	var forest: Node3D = FOREST_SCRIPT.new()
	forest.name = "Forest"
	forest.set("count", 168)
	forest.set("inner_radius", 60.0)
	forest.set("outer_radius", 96.0)
	forest.set("seed_value", 20261103)
	forest.set("clumps", PackedVector3Array([
		Vector3(-58, 8, -46), Vector3(-52, 7, -58), Vector3(-30, 8, -64),
		Vector3(34, 8, -64), Vector3(58, 9, -52), Vector3(68, 8, -34),
		Vector3(76, 7, -16), Vector3(78, 7, 6), Vector3(66, 8, 26),
		Vector3(44, 8, 60), Vector3(16, 8, 62), Vector3(-10, 8, 64),
		Vector3(-40, 8, 58), Vector3(-62, 8, 40), Vector3(-72, 8, 16),
		Vector3(-70, 8, -16),
	]))
	# Keep road gates and bridges clear of trunks, plus every building and every
	# lane (spurs included). Circles are cheap to test and are only evaluated
	# while the scene is generated.
	var avoid: Array[Vector3] = [
		Vector3(52, 11, -60), Vector3(72.7, 10, -2.8), Vector3(-26, 8, 32.2),
		Vector3(6.2, 8, 40.6), Vector3(52, 8, 46), Vector3(80, 12, 14),
	]
	for entry in _placed:
		var at: Vector2 = entry["at"]
		var footprint: Vector2 = entry["footprint"]
		avoid.append(Vector3(at.x, footprint.length() * 0.5 + 2.0, at.y))
	for lane in _lanes:
		var points: PackedVector3Array = lane["points"]
		var radius := float(lane["width"]) * 0.5 + 2.6
		for i in points.size() - 1:
			var from := Vector2(points[i].x, points[i].z)
			var to := Vector2(points[i + 1].x, points[i + 1].z)
			var steps := maxi(1, int(from.distance_to(to) / 2.0))
			for step in steps + 1:
				var at := from.lerp(to, float(step) / float(steps))
				avoid.append(Vector3(at.x, radius, at.y))
	forest.set("avoid", PackedVector3Array(avoid))
	_attach(forest)


# --- gates and cast --------------------------------------------------------


func _gates() -> void:
	var gates := Node3D.new()
	gates.name = "Gates"
	_attach(gates)
	_gates_root = gates

	# The player's cottage door, at the front of the residential-row home.
	_gate("HomeGate", gates, Vector3(-40, 1.2, -23.9), Vector3(2.6, 2.4, 0.8),
		"res://scenes/test_room.tscn", Vector3(0, 0.2, -8))


func _gate(
	node_name: String,
	parent: Node3D,
	position: Vector3,
	size: Vector3,
	target: String,
	target_position: Vector3,
	interior: bool = false
) -> void:
	var gate := Area3D.new()
	gate.name = node_name
	gate.position = position
	gate.collision_layer = 0
	gate.collision_mask = 2
	gate.set_script(GATE_SCRIPT)
	gate.set("target_scene", target)
	gate.set("target_position", target_position)
	gate.set("interior", interior)
	_add(gate, parent)

	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	_add(collider, gate)


## One load door in front of every authored interior. The gate sits just outside
## the wall so the player can touch it without walking through the building's
## solid collider, and `AreaGate.interior` makes it record a doorstep instead of
## using a fixed target position.
func _interior_gates() -> void:
	for entry in _placed:
		var building := String(entry["name"])
		if int(entry["style"]) == int(STYLE["ruin"]) or building == "HomeCottage":
			continue
		if not INTERIOR_LAYOUTS.has(building):
			continue

		var facing := float(entry["facing"])
		var at: Vector2 = entry["at"]
		var door := at + (_door_local(entry) as Vector2).rotated(-deg_to_rad(facing))
		var out := Vector2(-sin(deg_to_rad(facing)), -cos(deg_to_rad(facing)))
		at = door + out * 0.35

		_gate(
			"%sDoor" % building, _gates_root, Vector3(at.x, 1.2, at.y),
			Vector3(2.2, 2.4, 0.9), _interior_scene(building), Vector3.ZERO, true
		)


## One small room scene per enterable building. The scene is only a wrapper:
## `interior_room.gd` builds the geometry from `layout` and `room_size`, so two
## buildings in the same family still differ in proportion and dressing.
func _rooms() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INTERIOR_DIR))
	for entry in _placed:
		var building := String(entry["name"])
		if int(entry["style"]) == int(STYLE["ruin"]) or building == "HomeCottage":
			continue
		if not INTERIOR_LAYOUTS.has(building) or BESPOKE_SCENES.has(building):
			continue
		_write_room(building, INTERIOR_LAYOUTS[building], _room_size(entry), abs(hash(building)) % 3)


func _interior_scene(building: String) -> String:
	if BESPOKE_SCENES.has(building):
		return String(BESPOKE_SCENES[building])
	return "%s/%s.tscn" % [INTERIOR_DIR, _snake(building)]


## Exterior footprint minus the wall, capped so no room outgrows its shell.
func _room_size(entry: Dictionary) -> Vector2:
	var footprint: Vector2 = entry["footprint"]
	return Vector2(
		clampf(footprint.x - 0.6, 4.2, 10.4),
		clampf(footprint.y - 0.6, 4.0, 8.5)
	)


func _snake(value: String) -> String:
	var out := ""
	for i in value.length():
		var letter := value.substr(i, 1)
		var lower := letter.to_lower()
		if lower != letter and i > 0:
			out += "_"
		out += lower
	return out


func _write_room(building: String, layout: StringName, size: Vector2, accent: int) -> void:
	var path := _interior_scene(building)
	var spawn_z := maxf(size.y * 0.5 - 1.6, 0.5)
	var text := "[gd_scene load_steps=5 format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://features/world/interiors/interior_room.gd\" id=\"1_room\"]\n"
	text += "[ext_resource type=\"PackedScene\" path=\"res://features/player/player.tscn\" id=\"2_player\"]\n"
	text += "[ext_resource type=\"PackedScene\" path=\"res://features/ui/hud.tscn\" id=\"3_hud\"]\n"
	text += "[ext_resource type=\"PackedScene\" path=\"res://features/ui/pause_menu.tscn\" id=\"4_pause\"]\n\n"
	text += "[node name=\"%sInterior\" type=\"Node3D\"]\n" % building
	text += "script = ExtResource(\"1_room\")\n"
	text += "layout = &\"%s\"\n" % layout
	text += "room_size = Vector2(%.2f, %.2f)\n" % [size.x, size.y]
	text += "accent = %d\n\n" % accent
	text += "[node name=\"Player\" parent=\".\" instance=ExtResource(\"2_player\")]\n"
	text += "position = Vector3(0, 0.2, %.2f)\n\n" % spawn_z
	text += "[node name=\"HUD\" parent=\".\" instance=ExtResource(\"3_hud\")]\n\n"
	text += "[node name=\"PauseMenu\" parent=\".\" instance=ExtResource(\"4_pause\")]\n"

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("build_town: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()


func _arch(node_name: String, x: float, z: float, facing: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(x, 0.0, z)
	body.rotation.y = deg_to_rad(facing)
	body.collision_layer = 1
	body.collision_mask = 0
	_attach(body)

	var pieces: Array = [
		[Vector3(-2.3, 1.6, 0), Vector3(0.7, 3.2, 0.7)],
		[Vector3(2.3, 1.6, 0), Vector3(0.7, 3.2, 0.7)],
		[Vector3(0, 3.45, 0), Vector3(5.6, 0.7, 0.7)],
	]
	for index in pieces.size():
		var piece: Array = pieces[index]
		var at: Vector3 = piece[0]
		var size: Vector3 = piece[1]

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Stone%d" % (index + 1)
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.position = at
		mesh_instance.material_override = TownParts.material(STONE, 0.92)
		_add(mesh_instance, body)

		var collider := CollisionShape3D.new()
		collider.name = "StoneShape%d" % (index + 1)
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		collider.position = at
		_add(collider, body)

	# Moss on the lintel, because nothing in the Hollow stays clean.
	var moss := MeshInstance3D.new()
	moss.name = "Moss"
	var moss_mesh := BoxMesh.new()
	moss_mesh.size = Vector3(5.2, 0.12, 0.8)
	moss.mesh = moss_mesh
	moss.position = Vector3(0, 3.86, 0)
	moss.material_override = TownParts.material(Color(0.25, 0.35, 0.18, 1), 0.98)
	_add(moss, body)


func _welcome_sign() -> void:
	var sign_node := Node3D.new()
	sign_node.name = "WelcomeSign"
	sign_node.position = Vector3(-82, 0, 12)
	sign_node.rotation.y = deg_to_rad(90)
	_attach(sign_node)

	var wood := TownParts.material(Color(0.32, 0.21, 0.12, 1), 0.95)
	TownParts.box(sign_node, "PostL", Vector3(-2.0, 1.6, 0), Vector3(0.24, 3.2, 0.24), wood)
	TownParts.box(sign_node, "PostR", Vector3(2.0, 1.6, 0), Vector3(0.24, 3.2, 0.24), wood)
	TownParts.box(sign_node, "Board", Vector3(0, 2.75, 0), Vector3(4.6, 1.05, 0.18), wood)

	var label := Label3D.new()
	label.name = "Text"
	label.text = "Mycelgrove Hollow"
	label.position = Vector3(0, 2.76, -0.12)
	label.font_size = 56
	label.pixel_size = 0.0042
	label.outline_size = 18
	label.modulate = Color(0.98, 0.94, 0.83, 1)
	label.outline_modulate = Color(0.13, 0.09, 0.06, 1)
	_add(label, sign_node)

	TownParts.collision(sign_node, Vector3(4.8, 3.2, 0.4), Vector3(0, 1.6, 0))
	for child in sign_node.get_children():
		_own_tree(child)


func _cast() -> void:
	var player: Node3D = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = Vector3(-40, 0.2, -19)
	_attach(player)

	var guard: Node3D = FALL_GUARD_SCRIPT.new()
	guard.name = "FallGuard"
	guard.set("spawn_position", Vector3(-40, 0.2, -19))
	guard.set("fall_limit", -20.0)
	_attach(guard)

	var hud: CanvasLayer = HUD_SCENE.instantiate()
	hud.name = "HUD"
	_attach(hud)

	var pause: CanvasLayer = PAUSE_SCENE.instantiate()
	pause.name = "PauseMenu"
	_attach(pause)

	_hint_panel()


func _hint_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.42, 0.35, 0.23, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	var panel := PanelContainer.new()
	panel.name = "HintPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -520.0
	panel.offset_top = -96.0
	panel.offset_right = 520.0
	panel.offset_bottom = -14.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	_attach(panel)

	var label := Label.new()
	label.name = "Hint"
	label.text = (
		"WASD move   |   double-tap W run   |   Shift crouch   |   Space jump (hold to hop)   |   LMB attack   |   E interact   |   I inventory   |   M map   |   V camera   |   F3 debug\n"
		+ "Esc pause   |   F5 quicksave   |   F9 quickload   |   Your cottage door leads back inside\n"
		+ "Mycelgrove Hollow: market square, chapel hill, keepers' quarter, beekeeper district, old quarter, forest edge"
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.88, 1))
	_add(label, panel)


# --- packing helpers -------------------------------------------------------


func _attach(node: Node) -> void:
	_add(node, _root)


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = _root


func _own_tree(node: Node) -> void:
	node.owner = _root
	for child in node.get_children():
		_own_tree(child)
