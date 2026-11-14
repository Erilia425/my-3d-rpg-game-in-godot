class_name TownRealm
extends Node3D
## The wider world around Mycelgrove Hollow.
##
## The town scene keeps the authored village; this node grows the land beyond it
## at `_ready()` so the player can walk out of the village in any direction
## instead of through a gate into another scene. It paints the surrounding
## regions (plains, arctic, desert, marsh, forest, ocean) and cross-fades their
## borders, adds lakes and rivers, connects the two outlying villages (Ashfall in
## the northern bog, Thornridge in the eastern hills) with roads, fills the
## forest with varied trees, and scatters the 2D tileset's ground art.
##
## The existing town ground is 212 m square. This node builds a ring of ground
## *outside* that square, so nothing overlaps the authored village and its meadow
## patches. Everything here is content assembled from primitives and shared
## materials; the saved scene only holds this one node. See AGENTS.md 4.5 and 10.2.

const WORLD_HALF := 520.0
## Half-extent of the town's own ground. The ring starts just inside it so the
## two surfaces meet without a visible seam.
const TOWN_HALF := 104.0

const TEX_GRASS := preload("res://assets/from_2d/materials/grass.png")
const TEX_DIRT := preload("res://assets/from_2d/materials/dirt.png")
const TEX_STONE := preload("res://assets/from_2d/materials/stone.png")
const TEX_TREE := preload("res://assets/from_2d/sprites/tree.png")
const TEX_ROCK := preload("res://assets/from_2d/sprites/rock.png")
const TEX_MUSHROOM := preload("res://assets/from_2d/sprites/mushroom.png")
const TEX_FLOWER := preload("res://assets/from_2d/sprites/flower.png")
const TEX_STUMP := preload("res://assets/from_2d/sprites/stump.png")
const TEX_TILESET := preload("res://assets/from_2d/source/Fantasy Village Path Tileset Atlas.png")
const TEX_WATER := preload("res://assets/from_2d/sprites/river_water.png")
## Cut from `Fantasy Village Path Tileset Atlas.png`: a packed-earth path and a
## cobbled lane. Dirt paths run house to market to the road; cobbles mark the
## square itself.
const TEX_PATH_DIRT := preload("res://assets/from_2d/materials/path_dirt.png")
const TEX_PATH_COBBLE := preload("res://assets/from_2d/materials/path_cobble.png")
## Three flower clusters cut from the atlas's path-edge art. Mixed with the
## older single flower, they stop every verge looking like the same plant.
const TEX_FLOWER_CLUSTERS: Array[Texture2D] = [
	preload("res://assets/from_2d/sprites/flower_cluster_a.png"),
	preload("res://assets/from_2d/sprites/flower_cluster_b.png"),
	preload("res://assets/from_2d/sprites/flower_cluster_c.png"),
]
## The three round "special path" plots in the tileset's bottom band: a cobbled
## circle, a bare-earth circle, and a grassy circle dotted with flowers. They are
## painted on the ground as irregular patches so the floor is not one flat green.
## The atlas is opaque RGB, so `_keyed_patch()` turns its near-black plate into
## transparency before the crop is used as a flat decal.
const PATCH_REGIONS: Array[Rect2] = [
	Rect2(27, 900, 139, 127),
	Rect2(191, 901, 121, 118),
	Rect2(331, 899, 124, 129),
]
## How many ground patches the realm scatters (inside the town square first,
## then the meadow ring around it). Each variant is one draw call.
const PATCH_COUNT := 130

const RIBBON_SCRIPT := preload("res://features/world/town/town_ribbon.gd")
const RIVER_WADE_SCRIPT := preload("res://features/world/river_wade.gd")
const BUILDING_SCRIPT := preload("res://features/world/town/town_building.gd")
const PROP_SCRIPT := preload("res://features/world/town/town_prop.gd")
const ICON_SPRUCE_LOG := preload("res://assets/icons/items/spruce_log.svg")
const ICON_BIRCH_LOG := preload("res://assets/icons/items/birch_log.svg")
const ICON_STONE := preload("res://assets/icons/items/stone.svg")

## Leaf tints for the single painted tree texture. A colour below white shifts
## the art towards another season or species without a second asset.
const TINTS: Array[Color] = [
	Color(1, 1, 1, 1),
	Color(0.82, 0.94, 0.78, 1),
	Color(1, 0.9, 0.62, 1),
	Color(0.74, 0.86, 1, 1),
	Color(0.88, 1, 0.8, 1),
]
const SNOW_TINT := Color(0.82, 0.9, 1, 1)
const DEAD_TINT := Color(0.82, 0.78, 0.72, 1)

## Base floor colours for the seven regions. `_seams()` cross-fades the same
## constants, so a region and its border can never drift apart.
const C_ARCTIC := Color(0.86, 0.91, 0.96, 1)
const C_FOREST := Color(0.26, 0.34, 0.22, 1)
const C_DESERT := Color(0.8, 0.68, 0.46, 1)
const C_SAND := Color(0.78, 0.71, 0.52, 1)
const C_MARSH := Color(0.25, 0.31, 0.21, 1)
const C_PLAINS := Color(0.42, 0.56, 0.3, 1)
const C_MEADOW := Color(0.4, 0.5, 0.29, 1)

const NPC_SCENE := preload("res://features/npc/quest_npc.tscn")
const GATE_SCRIPT := preload("res://features/world/area_gate.gd")
const GATHER_SCENE := preload("res://features/gathering/gather_node.tscn")
const PICKUP_SCENE := preload("res://features/interaction/world_pickup.tscn")

## Where the cave mouth sits beside the north road, and the scene it opens into.
const CAVE_SCENE := "res://features/world/cave/mine_cave.tscn"
const CAVE_MOUTH := Vector2(18, -110)
## The stair down to the Spider Mother's lair. It stands where she used to wait
## in the open, a few metres south of the old cottages: the same spot, now with
## a way down under it.
const LAIR_SCENE := "res://features/world/cave/spider_lair.tscn"
const LAIR_STAIR := Vector2(-12, -46)
## A second cave mouth, out past the old cottages, that opens into the wild
## caves: a different cave on every entry. The Old Adit keeps its own gate.
const WILD_CAVE_SCENE := "res://features/world/cave/wild_caves.tscn"
const WILD_CAVE_MOUTH := Vector2(-56, -62)
const MEMORY_STONE_SCENE := preload("res://features/magic/memory_stone.tscn")
const LORE_WELL_SCENE := preload("res://features/interaction/lore_well.tscn")

## Safe arrival points for map fast travel, keyed by village kind. Filled while
## the village is built, because the generator already knows where its paths and
## doorsteps are. Static so the map screen can read it without walking the tree.
static var _arrivals: Dictionary = {}

## The two smaller settlements reached by road.
##
## Each entry is content, not a system: name, ground tints, flag colours, the
## houses that can be entered, and the villagers who live there. `edge` places
## the settlement's card on the storybook map, and `swatches` is its flag palette.
const VILLAGES: Array[Dictionary] = [
	{
		"name": "Ashfall",
		"kind": &"ashfall",
		"centre": Vector2(20, -300),
		"count": 7,
		"wall": Color(0.7, 0.7, 0.68, 1),
		"roof": Color(0.33, 0.4, 0.33, 1),
		"green": Color(0.42, 0.44, 0.38, 1),
		"flag_at": Vector2(-30, 20),
		"emblem": &"ash",
		"flag": [
			Color(0.6, 0.61, 0.61, 1),
			Color(0.88, 0.87, 0.82, 1),
			Color(0.28, 0.36, 0.27, 1),
		],
		"swatches": [
			Color(0.6, 0.61, 0.61, 1),
			Color(0.88, 0.87, 0.82, 1),
			Color(0.3, 0.4, 0.3, 1),
			Color(0.45, 0.38, 0.52, 1),
		],
		"mood": "north · ash and bog",
		"symbol": "Three ash flakes over a reed-filled marsh",
		"edge": "north",
		"interiors": [
			"res://features/world/interiors/rooms/ashfall_house.tscn",
			"res://features/world/interiors/rooms/ashfall_bothy.tscn",
			"res://features/world/interiors/rooms/ashfall_shrine.tscn",
		],
		"people": [
			{
				"name": "Maren Ash",
				"role": "Fenwalker",
				"coat": Color(0.45, 0.46, 0.47, 1),
				"trim": Color(0.82, 0.81, 0.76, 1),
				"skin": Color(0.78, 0.72, 0.66, 1),
				"hair": Color(0.66, 0.64, 0.61, 1),
				"hat": 1,
				"skirt": true,
				"lines": [
					"The ash falls thin here, but it never stops.",
					"Keep to the boardwalks. The bog takes what it likes.",
				],
				"quest": {
					"id": &"quest.ashfall_mushrooms",
					"deliver": &"item.mushroom",
					"deliver_amount": 2,
					"reward": &"item.health_potion",
					"reward_amount": 1,
					"coins": 12,
					"favor": 2,
					"offer": [
						"The pot is thin tonight. Two mushrooms would thicken it.",
						"Mind the pale ones. They bite back.",
					],
					"waiting": [
						"Two mushrooms. The pot can wait a little longer.",
					],
					"turn_in": [
						"Good and earthy. Here, take this for the road.",
					],
				},
			},
			{
				"name": "Pell",
				"role": "Reed-cutter",
				"coat": Color(0.3, 0.38, 0.28, 1),
				"trim": Color(0.45, 0.38, 0.52, 1),
				"skin": Color(0.8, 0.68, 0.55, 1),
				"hair": Color(0.24, 0.2, 0.18, 1),
				"hat": 0,
				"skirt": false,
				"lines": [
					"Mind the pale flakes. Some of them are moths.",
					"Nothing here stays buried long.",
				],
				"quest": {
					"id": &"quest.ashfall_snags",
					"deliver": &"item.spruce_log",
					"deliver_amount": 3,
					"reward": &"item.honey",
					"reward_amount": 2,
					"coins": 10,
					"favor": 1,
					"offer": [
						"Boardwalk's sagging again. Three spruce logs would set it right.",
						"Any deadfall will do. It all floats the same.",
					],
					"waiting": [
						"Three logs. The bog is patient. I am not.",
					],
					"turn_in": [
						"Straight and dry. That'll hold another winter.",
					],
				},
			},
		],
	},
	{
		"name": "Thornridge",
		"kind": &"thornridge",
		"centre": Vector2(330, 30),
		"count": 7,
		"wall": Color(0.56, 0.56, 0.56, 1),
		"roof": Color(0.5, 0.3, 0.17, 1),
		"green": Color(0.5, 0.49, 0.46, 1),
		"flag_at": Vector2(-36, -8),
		"emblem": &"thorn",
		"flag": [
			Color(0.42, 0.44, 0.47, 1),
			Color(0.55, 0.56, 0.57, 1),
			Color(0.62, 0.32, 0.16, 1),
		],
		"swatches": [
			Color(0.42, 0.44, 0.47, 1),
			Color(0.62, 0.32, 0.16, 1),
			Color(0.23, 0.3, 0.24, 1),
			Color(0.88, 0.86, 0.8, 1),
		],
		"mood": "east · rocky hills",
		"symbol": "A stone bridge between two thorn-covered peaks",
		"edge": "east",
		"interiors": [
			"res://features/world/interiors/rooms/thornridge_house.tscn",
			"res://features/world/interiors/rooms/thornridge_forge.tscn",
			"res://features/world/interiors/rooms/thornridge_inn.tscn",
		],
		"people": [
			{
				"name": "Bryn Thorne",
				"role": "Bridgekeeper",
				"coat": Color(0.34, 0.36, 0.4, 1),
				"trim": Color(0.62, 0.34, 0.18, 1),
				"skin": Color(0.8, 0.65, 0.5, 1),
				"hair": Color(0.2, 0.17, 0.15, 1),
				"hat": 1,
				"skirt": false,
				"lines": [
					"Cross carefully. The bridge is older than the town.",
					"Rust on the peaks means rain. Rust on the bridge means run.",
				],
				"quest": {
					"id": &"quest.thornridge_stone",
					"deliver": &"item.stone",
					"deliver_amount": 3,
					"coins": 15,
					"xp": 20,
					"favor": 2,
					"offer": [
						"The causeway wants stone. Three fieldstones and we can patch the east span.",
						"Pick them off the scree, not the standing stones.",
					],
					"waiting": [
						"Three stones. The bridge isn't mending itself.",
					],
					"turn_in": [
						"Aye, that's the weight. The bridge thanks you, even if it can't say so.",
					],
				},
			},
			{
				"name": "Sable",
				"role": "Quarry hand",
				"coat": Color(0.22, 0.3, 0.24, 1),
				"trim": Color(0.85, 0.83, 0.77, 1),
				"skin": Color(0.76, 0.62, 0.5, 1),
				"hair": Color(0.3, 0.22, 0.17, 1),
				"hat": 0,
				"skirt": false,
				"lines": [
					"Every stone here was carried up by somebody.",
					"The hills chew boots. Bring two pairs.",
				],
				"quest": {
					"id": &"quest.thornridge_ore",
					"deliver": &"item.iron_ore",
					"deliver_amount": 2,
					"reward": &"item.gemstone",
					"reward_amount": 1,
					"coins": 10,
					"favor": 1,
					"offer": [
						"Two iron ore and I can finish a proper blade blank.",
						"The old adit by the north road is full of it.",
					],
					"waiting": [
						"Two ore. The forge is hot enough.",
					],
					"turn_in": [
						"Rust on the outside, good iron inside. Here—found this in the seam.",
					],
				},
			},
		],
	},
]

@export var seed_value: int = 20261109

var _rng := RandomNumberGenerator.new()
## Polylines that trees and dressing must stay off: {"points", "radius"}.
var _roads: Array[Dictionary] = []
## Keep-clear circles: x and z are the centre, y is the radius.
var _clear: Array[Vector3] = []
var _unit_box: BoxMesh
var _prop_counter := 0

var _tree_entries: Array[Dictionary] = []
var _pine_entries: Array[Dictionary] = []
var _dead_entries: Array[Dictionary] = []
var _reed_points: Array[Vector2] = []
var _tuft_points: Array[Dictionary] = []
## Upright billboards for ground dressing (rocks, mushrooms, flowers, ferns,
## stumps). They are batched into one MultiMesh per texture, so a meadow of
## flowers costs one draw call instead of hundreds. See AGENTS.md 10.2.
var _ground_art: Array[Dictionary] = []
## Keyed copies of PATCH_REGIONS, built once on first use (see _keyed_patch).
var _patch_textures: Array[Texture2D] = []

## The far forest is one MultiMesh with no colliders, because 1,650 static bodies
## would cost more than the whole town. A small ring of colliders follows the
## player instead so a trunk that looks solid is solid where you actually stand.
const FOREST_WALL_RADIUS := 34.0
const FOREST_WALL_REBUILD := 0.6
## Trees further apart than this do not trigger a rebuild, so walking a long
## straight line does not rebuild every frame.
const FOREST_WALL_STEP := 4.0
var _forest_walls: StaticBody3D
var _forest_wall_shapes: Array[CollisionShape3D] = []
var _forest_wall_origin := Vector3(INF, INF, INF)


func _ready() -> void:
	add_to_group(&"town_realm")
	_rng.seed = seed_value
	_ground_ring()
	_biomes()
	_roads_and_rivers()
	_paths()
	# After `_paths()`: the ground patches hug the finished lane web.
	_ground_patches()
	# Before `_forest()`: both register keep-clear circles so no tree grows
	# through the cave mouth or a road sign.
	_cave_mouth()
	_spider_stair()
	_wild_cave_mouth()
	_memory_stone()
	_hidden_memories()
	_road_signs()
	_lakes()
	_forest()
	_villages()
	_village_lore()
	_dressing()
	_ground_forage()
	TownParts.merge_children(self)


# --- ground ----------------------------------------------------------------


func _ground_ring() -> void:
	# A frame of four slabs around the town's own 212 m square.
	var band := WORLD_HALF - TOWN_HALF
	var mid := (WORLD_HALF + TOWN_HALF) * 0.5
	var mat := _tiled(C_MEADOW, TEX_GRASS, 0.4)

	_slab("OuterNorth", Vector3(0, -0.25, -mid), Vector3(WORLD_HALF * 2.0, 0.5, band), mat)
	_slab("OuterSouth", Vector3(0, -0.25, mid), Vector3(WORLD_HALF * 2.0, 0.5, band), mat)
	_slab("OuterWest", Vector3(-mid, -0.25, 0), Vector3(band, 0.5, TOWN_HALF * 2.0), mat)
	_slab("OuterEast", Vector3(mid, -0.25, 0), Vector3(band, 0.5, TOWN_HALF * 2.0), mat)


func _slab(node_name: String, centre: Vector3, size: Vector3, mat: Material) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = centre
	add_child(holder)
	TownParts.box(holder, "Mesh", Vector3.ZERO, size, mat)
	TownParts.collision(holder, size, Vector3.ZERO)


## Paints one regional floor: a thin, slightly raised box so it reads as a change
## of ground rather than a second collider.
func _floor(node_name: String, rect: Rect2, y: float, mat: Material) -> void:
	_flat(node_name, Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x, 0.02, rect.size.y), mat)


func _flat(node_name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _unit_box
	instance.material_override = mat
	instance.position = at
	instance.scale = size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _tiled(color: Color, texture: Texture2D, repeat: float = 0.4) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 0.98
	if texture != null:
		made.albedo_texture = texture
		made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# World-space projection keeps the pixel art the same size on a 20 m
		# patch and a 340 m region, without hand-made UVs.
		made.uv1_triplanar = true
		made.uv1_world_triplanar = true
		made.uv1_scale = Vector3(repeat, repeat, repeat)
	return made


## A soft translucent wash used to break up a region's flat colour.
func _overlay(color: Color) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 1.0
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return made


func _water(color: Color) -> StandardMaterial3D:
	var made := _tiled(color, TEX_WATER, 0.22)
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.roughness = 0.18
	made.emission_enabled = true
	made.emission = Color(color.r, color.g, color.b, 1)
	made.emission_energy_multiplier = 0.1
	return made


# --- regions ---------------------------------------------------------------


func _biomes() -> void:
	# The ring around the town is split into seven regions. The town square
	# itself is left to `scenes/town.tscn`.
	var arctic := _tiled(C_ARCTIC, TEX_STONE, 0.32)
	var forest := _tiled(C_FOREST, TEX_GRASS, 0.45)
	var desert := _tiled(C_DESERT, TEX_DIRT, 0.38)
	var sand := _tiled(C_SAND, TEX_DIRT, 0.4)
	var marsh := _tiled(C_MARSH, TEX_GRASS, 0.5)
	var plains := _tiled(C_PLAINS, TEX_GRASS, 0.42)
	var meadow := _tiled(C_MEADOW, TEX_GRASS, 0.44)

	_floor("Arctic", Rect2(-520, -520, 700, 340), 0.012, arctic)
	_floor("DeepForest", Rect2(180, -520, 340, 340), 0.012, forest)
	_floor("Desert", Rect2(180, -180, 340, 360), 0.010, desert)
	_floor("OceanShelf", Rect2(180, 180, 340, 340), 0.010, sand)
	_floor("Marsh", Rect2(-180, 180, 360, 340), 0.012, marsh)
	_floor("PlainsSouthWest", Rect2(-520, 180, 340, 340), 0.012, plains)
	_floor("PlainsWest", Rect2(-520, -180, 340, 360), 0.012, plains)

	# The 74 m band between the town's ground and those regions stays meadow.
	_band_patches(meadow)

	# Broad tonal washes keep each region from reading as one flat colour. Three
	# shared materials keep the whole set to three draw calls after merging.
	var washes: Array[StandardMaterial3D] = [
		_overlay(Color(1, 1, 1, 0.10)),
		_overlay(Color(0.15, 0.2, 0.12, 0.12)),
		_overlay(Color(1, 0.94, 0.78, 0.09)),
	]
	_region_patches(Rect2(-520, -520, 700, 340), washes)
	_region_patches(Rect2(180, -520, 340, 340), washes)
	_region_patches(Rect2(180, -180, 340, 360), washes)
	_region_patches(Rect2(-180, 180, 360, 340), washes)
	_region_patches(Rect2(-520, 180, 340, 340), washes)
	_region_patches(Rect2(-520, -180, 340, 360), washes)

	_seams()


## Cross-fades every border between two regions, so walking from the meadow into
## the desert passes through a band of blended colour instead of a hard line.
##
## Each band is one quad painted with a gradient that is opaque on the first
## region's side and clear twelve metres into the second. A single quad per
## border keeps the whole set to one draw call each; a shader would do the same
## job with more moving parts. See AGENTS.md 4.5 and 10.2.
func _seams() -> void:
	const BAND := 26.0

	# Vertical borders, fading along x. The colour is the region on the -X side.
	_seam("SeamArcticForest", Vector3(180, 0.02, -350), 340.0, BAND, false, C_ARCTIC)
	_seam("SeamPlainsMeadow", Vector3(-180, 0.02, 0), 360.0, BAND, false, C_PLAINS)
	_seam("SeamMeadowDesert", Vector3(180, 0.02, 0), 360.0, BAND, false, C_MEADOW)
	_seam("SeamOceanMarsh", Vector3(180, 0.02, 350), 340.0, BAND, false, C_MARSH)
	_seam("SeamMarshPlains", Vector3(-180, 0.02, 350), 340.0, BAND, false, C_PLAINS)

	# Horizontal borders, fading along z. The colour is the region on the -Z side.
	_seam("SeamArcticPlains", Vector3(-350, 0.02, -180), 340.0, BAND, true, C_ARCTIC)
	_seam("SeamArcticMeadow", Vector3(0, 0.02, -180), 360.0, BAND, true, C_ARCTIC)
	_seam("SeamForestDesert", Vector3(350, 0.02, -180), 340.0, BAND, true, C_FOREST)
	_seam("SeamDesertOcean", Vector3(350, 0.02, 180), 340.0, BAND, true, C_DESERT)
	_seam("SeamMeadowMarsh", Vector3(0, 0.02, 180), 360.0, BAND, true, C_MEADOW)


## One transition band. `length` runs along the border, `band` across it, and
## `along_x` says whether the border itself runs east-west (fading along z).
func _seam(node_name: String, at: Vector3, length: float, band: float, along_x: bool, color: Color) -> void:
	var gradient := Gradient.new()
	# Fade from the source side of the border to nothing thirteen metres into the
	# neighbouring region, so the two textured floors meet under a blend instead
	# of at a hard line.
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.92),
		Color(color.r, color.g, color.b, 0.56),
		Color(color.r, color.g, color.b, 0.0),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 8
	if along_x:
		# The border runs east-west, so the band fades along z (UV v).
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
	else:
		# The border runs north-south, so the band fades along x (UV u).
		texture.fill_from = Vector2(0.0, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var span := Vector2(length, band) if along_x else Vector2(band, length)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _seam_mesh(span)
	instance.material_override = mat
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## A flat quad with a known UV layout: (0, 0) at -X / -Z and (1, 1) at +X / +Z.
## Building the four vertices by hand avoids depending on how a built-in plane
## mesh happens to lay out its UVs, which the gradient direction depends on.
func _seam_mesh(span: Vector2) -> Mesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-span.x * 0.5, 0.0, -span.y * 0.5),
		Vector3(span.x * 0.5, 0.0, -span.y * 0.5),
		Vector3(span.x * 0.5, 0.0, span.y * 0.5),
		Vector3(-span.x * 0.5, 0.0, span.y * 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _band_patches(meadow: StandardMaterial3D) -> void:
	for i in 26:
		var side := _rng.randi_range(0, 3)
		var along := _rng.randf_range(-WORLD_HALF, WORLD_HALF)
		var out := _rng.randf_range(TOWN_HALF + 4.0, 174.0)
		var at := Vector3.ZERO
		match side:
			0:
				at = Vector3(along, 0.008, -out)
			1:
				at = Vector3(along, 0.008, out)
			2:
				at = Vector3(-out, 0.008, along)
			_:
				at = Vector3(out, 0.008, along)
		_flat("MeadowPatch%d" % i, at,
			Vector3(_rng.randf_range(14.0, 40.0), 0.02, _rng.randf_range(14.0, 40.0)), meadow)


func _region_patches(rect: Rect2, washes: Array[StandardMaterial3D]) -> void:
	for i in 10:
		var size := Vector2(_rng.randf_range(16.0, 52.0), _rng.randf_range(16.0, 52.0))
		var at := Vector2(
			_rng.randf_range(rect.position.x + size.x * 0.5, rect.end.x - size.x * 0.5),
			_rng.randf_range(rect.position.y + size.y * 0.5, rect.end.y - size.y * 0.5)
		)
		var mat := washes[_rng.randi_range(0, washes.size() - 1)]
		_flat("TonePatch", Vector3(at.x, 0.016, at.y), Vector3(size.x, 0.02, size.y), mat)


# --- roads, rivers, lakes --------------------------------------------------


func _roads_and_rivers() -> void:
	# The old north road now runs on into the bog country to Ashfall.
	_road("NorthRoad", [
		Vector3(10, 0, -96), Vector3(14, 0, -140), Vector3(12, 0, -190),
		Vector3(4, 0, -235), Vector3(-6, 0, -265), Vector3(-12, 0, -286),
	], 3.2)
	# The east road climbs into the rocky hills to Thornridge.
	_road("EastRoad", [
		Vector3(98, 0, 13), Vector3(140, 0, 18), Vector3(186, 0, 24),
		Vector3(232, 0, 32), Vector3(272, 0, 40), Vector3(298, 0, 44),
	], 3.2)
	# A marsh track off the south road, into the bog.
	_road("MarshTrack", [
		Vector3(42, 0, 45), Vector3(50, 0, 90), Vector3(54, 0, 140),
		Vector3(50, 0, 195), Vector3(40, 0, 240),
	], 2.4)

	# The town's two rivers continue to the edges of the world.
	_river("SouthRiverWest", [
		Vector3(-106, 0, 24), Vector3(-146, 0, 22), Vector3(-186, 0, 18),
		Vector3(-226, 0, 12), Vector3(-262, 0, -14), Vector3(-290, 0, -60),
		Vector3(-306, 0, -120), Vector3(-316, 0, -190), Vector3(-324, 0, -300),
		Vector3(-330, 0, -430), Vector3(-332, 0, -520),
	], 3.8)
	_river("SouthRiverEast", [
		Vector3(106, 0, 50), Vector3(150, 0, 62), Vector3(200, 0, 90),
		Vector3(250, 0, 130), Vector3(300, 0, 170), Vector3(360, 0, 210),
		Vector3(420, 0, 250), Vector3(480, 0, 300), Vector3(520, 0, 330),
	], 3.8)
	# A river through the plains that feeds the west lake.
	_river("WestRiver", [
		Vector3(-330, 0, 250), Vector3(-328, 0, 190), Vector3(-320, 0, 120),
		Vector3(-300, 0, 70), Vector3(-270, 0, 36), Vector3(-230, 0, 14),
		Vector3(-186, 0, 18),
	], 3.2)
	# North through the forest and the arctic shelf, past Ashfall's east side.
	_river("NorthRiver", [
		Vector3(106, 0, -10), Vector3(120, 0, -70), Vector3(118, 0, -140),
		Vector3(100, 0, -220), Vector3(80, 0, -300), Vector3(60, 0, -380),
		Vector3(40, 0, -460), Vector3(35, 0, -520),
	], 3.6)

	# Keep the settlement greens clear of trees from the start: `_forest()` runs
	# before `_villages()`, so the circles have to be registered here. The flag
	# and bridge get their own small circles so no pine grows through them.
	for definition in VILLAGES:
		var centre: Vector2 = definition["centre"]
		_clear.append(Vector3(centre.x, 40.0, centre.y))
		var flag: Vector2 = centre + Vector2(definition["flag_at"])
		_clear.append(Vector3(flag.x, 10.0, flag.y))
	# The Thornridge gully and its bridge sit west of the village.
	_clear.append(Vector3(299, 12.0, 43))


## Dirt lanes through the town: house to house, house to market, and market out
## to the two roads that leave the Hollow. The authored streets stay; these are
## the trodden short cuts between them, cut from the atlas tileset. Widths stay
## narrow so a lane reads as a path and never as a second road.
func _paths() -> void:
	var hub := Vector2(17.0, -9.0)

	# Market to the front doors of the buildings around it.
	_path("PathToBakery", [hub, Vector2(8, -2), Vector2(-10, 3), Vector2(-22, 9)], 2.0)
	_path("PathToRowans", [hub, Vector2(18, -1), Vector2(23, 4)], 1.8)
	_path("PathToChapel", [hub, Vector2(9, -5), Vector2(1, 1), Vector2(-5, 9)], 1.8)
	_path("PathToKeepers", [hub, Vector2(26, -2), Vector2(33, -1)], 1.8, TEX_PATH_COBBLE)

	# Out of town: the square to the north and east roads.
	_path(
		"PathNorthGate",
		[hub, Vector2(16, -22), Vector2(14, -48), Vector2(12, -78), Vector2(10, -96)],
		2.6
	)
	_path(
		"PathEastGate",
		[hub, Vector2(30, 2), Vector2(52, 6), Vector2(76, 9), Vector2(98, 13)],
		2.6
	)

	# South past the bell tower to the odd houses; west behind the square to the
	# row cottages.
	_path("PathSouthLane", [hub, Vector2(17, 8), Vector2(15, 24), Vector2(13, 42)], 2.0)
	_path("PathRowLane", [Vector2(-6, -8), Vector2(-16, -18), Vector2(-30, -23)], 1.8)
	_path("PathWestRow", [Vector2(-30, -23), Vector2(-40, -25)], 1.6)

	# --- house-to-house lanes ------------------------------------------------
	# These are additive: the authored door spurs in `town.tscn` still run from
	# every front door to the nearest street. The lanes below stitch those spurs
	# into a walkable web, the way the storybook map reads: a row of cottages
	# joined front-to-back, an orchard path behind the square, a bee yard, and a
	# track out past the odd houses and the old ruins.

	# North row: the two cottages behind the bakery rejoin the square.
	_path(
		"LaneNorthRow",
		[Vector2(-26, -6), Vector2(-14, -8), Vector2(-2, -9), Vector2(8, -10), hub],
		1.7
	)

	# East row: Rowan's house, the east cottages, and down to the bell tower.
	_path(
		"LaneEastRow",
		[Vector2(25, 9.5), Vector2(38.5, 14), Vector2(29, 20.5), Vector2(16.5, 21.5), Vector2(13, 24)],
		1.7
	)
	_path("LaneBellRow", [Vector2(6.9, 12.6), Vector2(11, 17), Vector2(13, 24)], 1.5)

	# Bee district: keeper's office, thread cottages, honey store, hive tower.
	_path(
		"LaneBeeRow",
		[Vector2(36, -22), Vector2(46.5, -28), Vector2(54.5, -31.5), Vector2(61, -38), Vector2(49.5, -41.5)],
		1.6
	)
	_path("LaneHoneyRow", [Vector2(34, -34), Vector2(40, -31), Vector2(46.5, -28)], 1.5)

	# Row cottages: link the four semis behind the west row.
	_path(
		"LaneRowCottages",
		[
			Vector2(-40, -25), Vector2(-52, -27.5), Vector2(-31.5, -27.5),
			Vector2(-23.5, -27.5), Vector2(-15.5, -27.5), Vector2(-6, -24),
		],
		1.5
	)

	# Old quarter: seamstress, old cottages, and the loom tower.
	_path(
		"LaneOldQuarter",
		[
			Vector2(-30, -23), Vector2(-27, -38), Vector2(-34, -44),
			Vector2(-44, -49), Vector2(-30, -52), Vector2(-15, -57),
		],
		1.6
	)

	# Odd houses, then a track out of the Hollow to the south.
	_path("LaneOddHouses", [Vector2(13, 42), Vector2(8, 49), Vector2(16.5, 54)], 1.6)
	_path("LaneSouthOut", [Vector2(16.5, 54), Vector2(20, 70), Vector2(24, 90)], 1.8)

	# Garden cottage and the gone houses on the south-west edge.
	_path(
		"LaneGardenRow",
		[
			Vector2(13, 42), Vector2(-2, 38), Vector2(-19, 29),
			Vector2(-31, 37), Vector2(-39, 44.5), Vector2(-43.5, 51), Vector2(-50, 43.5),
		],
		1.5
	)

	# Ruins track: north gate to the fallen houses.
	_path(
		"LaneRuins",
		[Vector2(14, -48), Vector2(7, -60), Vector2(0, -70), Vector2(11, -75), Vector2(23, -77)],
		1.5
	)

	# East houses: ford, keeper's office, forest edge, and the east cottage.
	_path(
		"LaneEastHouses",
		[Vector2(33, -1), Vector2(47, -11), Vector2(58, -4), Vector2(70, -16)],
		1.6
	)
	_path("LaneEastCottage", [Vector2(52, 6), Vector2(60, 12), Vector2(68, 18)], 1.5)

	# West gate: out past the west cottages to the boundary.
	_path(
		"LaneWestHouses",
		[Vector2(-22, 9), Vector2(-35, 3), Vector2(-52, 2), Vector2(-58, 20), Vector2(-68, 24)],
		1.6
	)


## One dirt or cobble strip. Registered as a road so no tree grows through it.
func _path(
	node_name: String, points: Array, width: float, texture: Texture2D = TEX_PATH_DIRT
) -> void:
	var packed := PackedVector3Array()
	for point in points:
		packed.append(Vector3(point.x, 0.0, point.y))
	_ribbon(node_name, packed, width, Color(0.6, 0.52, 0.4, 1), 0.046, false, texture)
	_roads.append({"points": packed, "radius": width * 0.5 + 1.2})


func _road(node_name: String, points: Array, width: float) -> void:
	var packed := PackedVector3Array()
	for point in points:
		packed.append(point)
	_ribbon(node_name, packed, width, Color(0.51, 0.43, 0.3, 1), 0.034, false, TEX_DIRT)
	_roads.append({"points": packed, "radius": width * 0.5 + 2.6})


func _river(node_name: String, points: Array, width: float) -> void:
	var packed := PackedVector3Array()
	for point in points:
		packed.append(point)
	# Muddy bank first, then the translucent sheet on top.
	_ribbon("%sBank" % node_name, packed, width * 1.65, Color(0.42, 0.36, 0.26, 1), 0.024, false, TEX_DIRT)
	_ribbon(node_name, packed, width, Color(0.19, 0.37, 0.44, 0.72), 0.056, true, TEX_WATER)
	_roads.append({"points": packed, "radius": width * 0.9 + 2.0})
	_river_wade(node_name, packed, width)


## One `RiverWade` area per river, built from a box per polyline segment. Wading
## is a feel mechanic, not a wall: the water slows the player but never traps
## them. See `features/world/river_wade.gd`.
func _river_wade(node_name: String, points: PackedVector3Array, width: float) -> void:
	if points.size() < 2:
		return
	var area: Area3D = RIVER_WADE_SCRIPT.new()
	area.name = "%sWade" % node_name
	add_child(area)
	for i in points.size() - 1:
		var from := points[i]
		var to := points[i + 1]
		var span := from.distance_to(to)
		if span < 0.4:
			continue
		var mid := (from + to) * 0.5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Slightly narrower than the painted water so the bank stays dry.
		box.size = Vector3(width * 1.1, 3.0, span + width * 0.6)
		shape.shape = box
		shape.position = Vector3(mid.x, 1.5, mid.z)
		shape.rotation.y = atan2(to.x - from.x, to.z - from.z)
		area.add_child(shape)

	# One quiet positional loop at the middle of the river, owned by the area.
	var centre := Vector3.ZERO
	for point in points:
		centre += point
	centre /= float(points.size())
	area.add_child(AmbientAudio.make_river_loop(Vector3(centre.x, 1.2, centre.z)))


func _ribbon(
	node_name: String,
	points: PackedVector3Array,
	width: float,
	color: Color,
	surface: float,
	transparent: bool,
	texture: Texture2D
) -> void:
	var ribbon: Node3D = RIBBON_SCRIPT.new()
	ribbon.name = node_name
	ribbon.set("points", points)
	ribbon.set("width", width)
	ribbon.set("color", color)
	ribbon.set("surface_height", surface)
	ribbon.set("transparent", transparent)
	ribbon.set("ripples", transparent)
	ribbon.set("albedo_texture", texture)
	ribbon.set("uv_scale", Vector3(0.5, 0.5, 0.5))
	ribbon.set("seed_value", abs(hash(node_name)) % 50000 + 3)
	add_child(ribbon)


func _lakes() -> void:
	# The west lake, a bog pool in Ashfall's marsh, and the marsh pool.
	_lake("WestLake", Vector3(-330, 0, 335), 78.0)
	_lake("AshfallBog", Vector3(-34, 0, -338), 30.0,
		Color(0.21, 0.27, 0.24, 0.82), Color(0.34, 0.35, 0.29, 1))
	_lake("BogPool", Vector3(30, 0, 350), 34.0)
	_clear.append(Vector3(-330, 86.0, 335))
	_clear.append(Vector3(-34, 38.0, -338))
	_clear.append(Vector3(30, 42.0, 350))

	# The ocean: a shallow sheet over the south-east shelf, so the player wades
	# in instead of needing a swimming system.
	var ocean := _water(Color(0.14, 0.33, 0.44, 0.78))
	_flat("Ocean", Vector3(350, 0.07, 350), Vector3(320, 0.04, 320), ocean)
	_flat("OceanShore", Vector3(350, 0.03, 350), Vector3(336, 0.03, 336), _tiled(Color(0.72, 0.65, 0.46, 1), TEX_DIRT, 0.4))


func _lake(
	node_name: String,
	at: Vector3,
	radius: float,
	water_color: Color = Color(0.17, 0.36, 0.45, 0.74),
	shore_color: Color = Color(0.6, 0.55, 0.4, 1)
) -> void:
	var shore := _tiled(shore_color, TEX_DIRT, 0.4)
	TownParts.cylinder(self, "%sShore" % node_name, Vector3(at.x, 0.012, at.z), radius + 7.0, radius + 7.0, 0.03, shore, Vector3.ZERO, 40)
	TownParts.cylinder(self, node_name, Vector3(at.x, 0.05, at.z), radius, radius, 0.05, _water(water_color), Vector3.ZERO, 40)


# --- forest ----------------------------------------------------------------


func _forest() -> void:
	_sample_belt()
	_batch_billboards()
	_batch_pines()
	_batch_dead_trees()
	_road_trees()
	_start_forest_walls()


func _sample_belt() -> void:
	var attempts := 0
	while _tree_entries.size() + _pine_entries.size() + _dead_entries.size() < 1350 and attempts < 22000:
		attempts += 1
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf_range(100.0 * 100.0, 330.0 * 330.0))
		var p := Vector2(cos(angle), sin(angle)) * radius
		if not _is_open(p):
			continue
		var region := _region_at(p)
		if region == &"desert" or region == &"ocean":
			continue
		if region == &"marsh":
			# The bog is mostly open water and reeds, with the odd snag.
			if _rng.randf() < 0.55:
				_dead_entries.append(_tree_entry(p, _rng.randf_range(2.6, 4.6), _rng.randf_range(0.6, 1.0), DEAD_TINT))
			continue
		if region == &"arctic":
			_pine_entries.append(_tree_entry(p, _rng.randf_range(5.0, 9.5), 1.0, SNOW_TINT))
		elif region == &"forest" and _rng.randf() < 0.45:
			_pine_entries.append(_tree_entry(p, _rng.randf_range(5.0, 9.5), 1.0, TINTS[_rng.randi_range(0, 1)]))
		elif _rng.randf() < 0.24:
			_pine_entries.append(_tree_entry(p, _rng.randf_range(4.5, 8.5), 1.0, TINTS[_rng.randi_range(0, 1)]))
		else:
			_tree_entries.append(_tree_entry(p, _rng.randf_range(4.2, 9.0), _rng.randf_range(0.9, 1.5), TINTS[_rng.randi_range(0, TINTS.size() - 1)]))

	# A distant wall of trees hides the edge of the ground.
	for i in 300:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(470.0, 516.0)
		var p := Vector2(cos(angle), sin(angle)) * radius
		_tree_entries.append(_tree_entry(p, _rng.randf_range(6.0, 11.0), _rng.randf_range(1.1, 1.7), TINTS[_rng.randi_range(0, 2)]))


func _tree_entry(p: Vector2, height: float, width_scale: float, tint: Color) -> Dictionary:
	var width := height * 0.46 * width_scale
	return {"x": p.x, "z": p.y, "height": height, "width": width, "tint": tint}


func _region_at(p: Vector2) -> StringName:
	if p.y < -180.0:
		return &"forest" if p.x > 180.0 else &"arctic"
	if p.y > 180.0:
		if p.x > 180.0:
			return &"ocean"
		return &"marsh" if p.x > -180.0 else &"plains"
	if p.x > 180.0:
		return &"desert"
	return &"plains" if p.x < -180.0 else &"meadow"


func _is_open(p: Vector2) -> bool:
	# Trees stay out of roads, rivers, lake basins, villages, and the ocean.
	if p.length() < 100.0:
		return false
	for circle in _clear:
		if p.distance_to(Vector2(circle.x, circle.z)) < circle.y:
			return false
	return not _on_a_road(p)


## True when `p` sits on a road, river, or their banks. Village dressing checks
## this instead of `_is_open`, because the settlement's own keep-clear circle
## would otherwise reject every prop inside the village.
func _on_a_road(p: Vector2) -> bool:
	for road in _roads:
		var points: PackedVector3Array = road["points"]
		var reach: float = road["radius"]
		for i in points.size() - 1:
			var from := Vector2(points[i].x, points[i].z)
			var to := Vector2(points[i + 1].x, points[i + 1].z)
			if _distance_to_segment(p, from, to) < reach:
				return true
	return false


func _distance_to_segment(p: Vector2, from: Vector2, to: Vector2) -> float:
	var span := to - from
	var length_sq := span.length_squared()
	if length_sq < 0.0001:
		return p.distance_to(from)
	var t := clampf((p - from).dot(span) / length_sq, 0.0, 1.0)
	return p.distance_to(from + span * t)


func _batch_billboards() -> void:
	if _tree_entries.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEX_TREE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	# Billboard mode does not work inside a MultiMesh, which is why the far trees
	# used to read as flat sheets of art. Each tree is two crossed quads instead:
	# one draw call, and a trunk that looks like a trunk from every angle.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	var count := _tree_entries.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = count * 2
	for i in count:
		var entry := _tree_entries[i]
		var height: float = entry["height"]
		var width: float = entry["width"]
		var yaw := _rng.randf() * TAU
		# The painted tree has transparent margin under the trunk, so the quad is
		# planted slightly below the ground line instead of hovering above it.
		var sink := height * 0.07
		var at := Vector3(entry["x"], height * 0.5 - sink, entry["z"])
		for face in 2:
			var basis := (
				Basis(Vector3.UP, yaw + float(face) * PI * 0.5)
				* Basis.from_scale(Vector3(width, height, 1.0))
			)
			var index := i * 2 + face
			multimesh.set_instance_transform(index, Transform3D(basis, at))
			multimesh.set_instance_color(index, entry["tint"])

	var batch := MultiMeshInstance3D.new()
	batch.name = "ForestBillboards"
	batch.multimesh = multimesh
	batch.material_override = mat
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)


func _batch_pines() -> void:
	if _pine_entries.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.2
	trunk.height = 1.0
	trunk.radial_segments = 6

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color.WHITE
	cone_mat.roughness = 0.96
	cone_mat.vertex_color_use_as_albedo = true

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.2, 0.13, 1)
	trunk_mat.roughness = 0.96

	var cones := MultiMesh.new()
	cones.transform_format = MultiMesh.TRANSFORM_3D
	cones.use_colors = true
	cones.mesh = cone
	cones.instance_count = _pine_entries.size()

	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk
	trunks.instance_count = _pine_entries.size()

	for i in _pine_entries.size():
		var entry := _pine_entries[i]
		var height: float = entry["height"]
		var at := Vector3(entry["x"], 0.0, entry["z"])
		var cone_basis := Basis().scaled(Vector3(height * 0.3, height * 0.78, height * 0.3))
		cones.set_instance_transform(i, Transform3D(cone_basis, at + Vector3(0, height * 0.58, 0)))
		cones.set_instance_color(i, entry["tint"])
		var trunk_basis := Basis().scaled(Vector3(height * 0.13, height * 0.46, height * 0.13))
		trunks.set_instance_transform(i, Transform3D(trunk_basis, at + Vector3(0, height * 0.23, 0)))

	_add_multimesh("ForestPines", cones, cone_mat)
	_add_multimesh("ForestTrunks", trunks, trunk_mat)


func _batch_dead_trees() -> void:
	# Snags need a trunk that reads from any angle, which a billboard cannot
	# give. One dead-tree mesh is batched with per-instance scale and tint, so a
	# bog full of them costs one draw call.
	if _dead_entries.is_empty():
		return
	var mesh := _dead_tree_mesh()
	if mesh == null:
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.28, 0.24, 1)
	mat.roughness = 0.96
	mat.vertex_color_use_as_albedo = true

	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = _dead_entries.size()
	for i in _dead_entries.size():
		var entry := _dead_entries[i]
		var scale := float(entry["height"]) / 5.0
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
		batch.set_instance_transform(i, Transform3D(basis, Vector3(entry["x"], 0.0, entry["z"])))
		batch.set_instance_color(i, entry["tint"])

	_add_multimesh("ForestSnags", batch, mat)


# --- forest walls ----------------------------------------------------------


## Starts the collider ring. The far forest is drawn as one batch, so its trunks
## have no bodies of their own; this ring gives the trees nearest the player a
## solid trunk wherever they actually walk. It is a wall, not a harvest: only the
## roadside and village trees can be chopped.
func _start_forest_walls() -> void:
	if _tree_entries.is_empty() and _pine_entries.is_empty():
		return

	_forest_walls = StaticBody3D.new()
	_forest_walls.name = "ForestWalls"
	add_child(_forest_walls)

	var timer := Timer.new()
	timer.name = "ForestWallsTimer"
	timer.wait_time = FOREST_WALL_REBUILD
	timer.autostart = true
	timer.timeout.connect(_rebuild_forest_walls)
	add_child(timer)

	_rebuild_forest_walls()


func _rebuild_forest_walls() -> void:
	if _forest_walls == null:
		return

	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return

	var origin := player.global_position
	if origin.distance_squared_to(_forest_wall_origin) < FOREST_WALL_STEP * FOREST_WALL_STEP:
		return
	_forest_wall_origin = origin

	var used := _place_forest_walls(_tree_entries, origin, 0, true)
	used = _place_forest_walls(_pine_entries, origin, used, false)

	for i in range(used, _forest_wall_shapes.size()):
		_forest_wall_shapes[i].set_deferred("disabled", true)


## Gives every tree within reach a cylinder. Trees standing on top of the player
## are skipped, so a trunk can never appear inside them and pin them in place.
func _place_forest_walls(
	entries: Array[Dictionary], origin: Vector3, start: int, use_width: bool
) -> int:
	var used := start
	var reach_sq := FOREST_WALL_RADIUS * FOREST_WALL_RADIUS
	var safe_sq := 1.2 * 1.2

	for entry in entries:
		var x: float = entry["x"]
		var z: float = entry["z"]
		var dx := x - origin.x
		var dz := z - origin.z
		var distance_sq := dx * dx + dz * dz
		if distance_sq > reach_sq or distance_sq < safe_sq:
			continue

		var radius := 0.4
		if use_width:
			radius = clampf(float(entry["width"]) * 0.16, 0.3, 1.0)
		else:
			radius = clampf(float(entry["height"]) * 0.06, 0.25, 0.7)

		_apply_forest_wall(used, Vector3(x, 1.5, z), radius)
		used += 1

	return used


func _apply_forest_wall(index: int, at: Vector3, radius: float) -> void:
	var shape: CollisionShape3D
	if index < _forest_wall_shapes.size():
		shape = _forest_wall_shapes[index]
	else:
		shape = CollisionShape3D.new()
		shape.name = "Tree%d" % index
		var cylinder := CylinderShape3D.new()
		cylinder.height = 3.0
		shape.shape = cylinder
		_forest_walls.add_child(shape)
		_forest_wall_shapes.append(shape)

	var body := shape.shape as CylinderShape3D
	if body != null:
		body.radius = radius
	shape.position = at
	shape.set_deferred("disabled", false)


## Reeds are a few cylinders of one material, so all of them share one mesh.
func _batch_reeds() -> void:
	if _reed_points.is_empty():
		return
	var temp := Node3D.new()
	var leaf := TownParts.material(Color(0.25, 0.36, 0.17, 1), 0.97)
	for i in 5:
		var angle := TAU * i / 5.0
		TownParts.cylinder(temp, "Reed%d" % i, Vector3(cos(angle) * 0.35, 0.55, sin(angle) * 0.35), 0.04, 0.07, 1.1, leaf, Vector3.ZERO, 5)
	TownParts.merge_children(temp)
	var mesh: Mesh = null
	for child in temp.get_children():
		var instance := child as MeshInstance3D
		if instance != null and instance.mesh != null:
			mesh = instance.mesh
			break
	temp.free()
	if mesh == null:
		return

	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = _reed_points.size()
	for i in _reed_points.size():
		var at := _reed_points[i]
		var scale := _rng.randf_range(0.8, 1.3)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
		batch.set_instance_transform(i, Transform3D(basis, Vector3(at.x, 0.0, at.y)))

	_add_multimesh("MarshReeds", batch, leaf)


## Builds the shared dead-tree mesh once, from the same primitives as the prop.
func _dead_tree_mesh() -> Mesh:
	var temp := Node3D.new()
	var bark := TownParts.material(Color(0.33, 0.28, 0.24, 1), 0.96)
	TownParts.cylinder(temp, "Trunk", Vector3(0, 2.5, 0), 0.1, 0.28, 5.0, bark, Vector3.ZERO, 7)
	for i in 4:
		var angle := TAU * i / 4.0 + 0.35
		var at := Vector3(cos(angle) * 0.14, 5.0 * (0.52 + i * 0.1), sin(angle) * 0.14)
		var branch := TownParts.cylinder(temp, "Branch%d" % i, at, 0.04, 0.09, 5.0 * 0.36, bark, Vector3.ZERO, 5)
		branch.rotation = Vector3(deg_to_rad(42.0), angle, 0.0)
	TownParts.merge_children(temp)
	var merged: Mesh = null
	for child in temp.get_children():
		var instance := child as MeshInstance3D
		if instance != null and instance.mesh != null:
			merged = instance.mesh
			break
	temp.free()
	return merged


func _add_multimesh(node_name: String, multimesh: MultiMesh, mat: Material) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = mat
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)


## Real, solid trees near the roads and settlements, where the player is most
## likely to walk up to a trunk.
func _road_trees() -> void:
	for road in _roads:
		var points: PackedVector3Array = road["points"]
		var reach: float = road["radius"]
		for i in points.size() - 1:
			var from := Vector2(points[i].x, points[i].z)
			var to := Vector2(points[i + 1].x, points[i + 1].z)
			var steps := maxi(1, int(from.distance_to(to) / 12.0))
			for step in steps:
				if _rng.randf() > 0.5:
					continue
				var at := from.lerp(to, (step + _rng.randf()) / steps)
				var offset := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
				if offset.length_squared() < 0.01:
					offset = Vector2.RIGHT
				var p := at + offset.normalized() * _rng.randf_range(reach + 1.0, reach + 12.0)
				var region := _region_at(p)
				if not _is_open(p) or region == &"desert" or region == &"ocean":
					continue
				if region == &"arctic":
					_prop(TownProp.Kind.PINE, p, {
						"size": Vector3(1.0, _rng.randf_range(5.0, 8.0), 1.0),
						"leaf_tint": SNOW_TINT,
						"wood_item": &"item.birch_log",
					})
					continue
				_prop(TownProp.Kind.TREE, p, {
					"size": Vector3(_rng.randf_range(1.4, 2.3), _rng.randf_range(4.5, 7.5), 1.0),
					"leaf_tint": TINTS[_rng.randi_range(0, TINTS.size() - 1)],
					"facing_degrees": _rng.randf() * 360.0,
				})


# --- villages --------------------------------------------------------------


func _villages() -> void:
	for definition in VILLAGES:
		_village(definition)


func _village(definition: Dictionary) -> void:
	var centre: Vector2 = definition["centre"]
	var count: int = definition["count"]
	var wall: Color = definition["wall"]
	var roof: Color = definition["roof"]
	var radius := 19.0

	# Ashfall's green is bog mud; Thornridge's is bare hill stone. Neither uses
	# the vivid grass texture, so the two villages read colder than the Hollow.
	var ground_texture := TEX_DIRT if definition["kind"] == &"ashfall" else TEX_STONE
	var green := _tiled(definition["green"], ground_texture, 0.45)
	# The green is a thin paint layer at a known height. Everything drawn on top
	# of it (lanes, paths, pools) sits at a higher `surface_height`, so the stack
	# is: region floor 0.022, rims 0.023-0.027, green top 0.030, paths 0.048,
	# lane 0.052, sills 0.070.
	_flat("%sGreen" % definition["name"], Vector3(centre.x, 0.024, centre.y), Vector3(84, 0.012, 84), green)
	# Three faint, larger rings under the green soften the edge where the
	# settlement's own ground meets the region floor. Without them a village
	# dropped into snow or sand reads as a rectangle.
	for k in 3:
		var base: Color = definition["green"]
		var ring := _overlay(Color(base.r, base.g, base.b, 0.28 - 0.08 * k))
		_flat(
			"%sRim%d" % [definition["name"], k],
			Vector3(centre.x, 0.0235 - 0.0015 * k, centre.y),
			Vector3(104.0 + k * 20.0, 0.006, 104.0 + k * 20.0),
			ring
		)
	_ribbon("%sLane" % definition["name"], PackedVector3Array([
		Vector3(centre.x - 32.0, 0, centre.y + 14.0),
		Vector3(centre.x - 14.0, 0, centre.y + 8.0),
		Vector3(centre.x, 0, centre.y),
		Vector3(centre.x + 14.0, 0, centre.y - 8.0),
		Vector3(centre.x + 34.0, 0, centre.y - 16.0),
	]), 2.6, Color(0.51, 0.43, 0.3, 1), 0.052, false, TEX_DIRT)

	# Doorsteps, in the order the houses are built. The first few get a gate into
	# one of the village's interiors; the rest stay shut, like the town's props.
	var doorsteps: Array[Vector2] = []
	for i in count:
		var angle := TAU * i / float(count) + _rng.randf_range(-0.14, 0.14)
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(radius, radius + 7.0)
		var footprint := Vector2(_rng.randf_range(5.0, 7.4), _rng.randf_range(4.4, 6.0))
		var to_centre := centre - at
		var facing := rad_to_deg(atan2(-to_centre.x, -to_centre.y))

		var house: Node3D = BUILDING_SCRIPT.new()
		house.name = "%sHouse%d" % [definition["name"], i]
		house.position = Vector3(at.x, 0.0, at.y)
		house.set("style", 1 if _rng.randf() < 0.22 else 0)
		house.set("footprint", footprint)
		house.set("wall_color", wall.lerp(Color.WHITE, _rng.randf_range(-0.12, 0.14)))
		house.set("roof_color", roof.lightened(_rng.randf_range(-0.08, 0.08)))
		house.set("facing_degrees", facing)
		house.set("seed_value", _rng.randi_range(1, 90000))
		add_child(house)

		# A dooryard path from the front door to the lane, and the spot just
		# outside that door where a gate can sit.
		var door := at + Vector2(-sin(deg_to_rad(facing)), -cos(deg_to_rad(facing))) * (footprint.y * 0.5 + 0.4)
		doorsteps.append(at + Vector2(-sin(deg_to_rad(facing)), -cos(deg_to_rad(facing))) * (footprint.y * 0.5 + 0.9))
		_ribbon("%sPath%d" % [definition["name"], i], PackedVector3Array([
			Vector3(door.x, 0, door.y), Vector3(centre.x, 0, centre.y),
		]), 1.4, Color(0.53, 0.45, 0.32, 1), 0.048, false, TEX_DIRT)

	# Village green furniture.
	_prop(TownProp.Kind.WELL, centre, {"size": Vector3(1.1, 1.0, 1.0)})
	for i in 3:
		var angle := TAU * i / 3.0 + 0.4
		var p := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(5.0, 9.0)
		_prop(TownProp.Kind.BENCH, p, {"facing_degrees": rad_to_deg(atan2(centre.x - p.x, centre.y - p.y))})
	for i in 4:
		var angle := TAU * i / 4.0 + 0.7
		var p := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(9.0, 13.0)
		_prop(TownProp.Kind.LANTERN, p)
	for i in 2:
		var p := centre + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-14.0, 14.0))
		_prop(TownProp.Kind.GARDEN_BED, p, {"size": Vector3(_rng.randf_range(2.0, 3.2), 1.0, 1.2)})

	_prop(TownProp.Kind.SIGNPOST, centre + Vector2(-30.0, 16.0), {"text": String(definition["name"])})

	_village_flag(definition)
	_village_people(definition)
	_village_gates(definition, doorsteps)
	_village_gathering(definition, doorsteps)

	# Map fast travel arrives on the dooryard of the first house that is not a
	# gate, so the player never lands inside a door trigger or on the well.
	if not doorsteps.is_empty():
		var arrival := doorsteps[mini(3, doorsteps.size() - 1)]
		_arrivals[definition["kind"]] = Vector3(arrival.x, 0.2, arrival.y)

	match definition["kind"]:
		&"ashfall":
			_ashfall_dressing(centre)
		&"thornridge":
			_thornridge_dressing(centre)


## A safe position in `village_kind` for map fast travel. Falls back to a clear
## point south of the village centre if the map asks before the village exists.
static func arrival_for(village_kind: StringName) -> Vector3:
	if _arrivals.has(village_kind):
		return _arrivals[village_kind]
	for definition in VILLAGES:
		if definition["kind"] == village_kind:
			var centre: Vector2 = definition["centre"]
			return Vector3(centre.x, 0.2, centre.y + 12.0)
	return Vector3.ZERO


## The Old Adit: a rock mound beside the north road with a dark mouth. The
## walk-through volume is an `AreaGate` with `interior = true`, so leaving the
## cave returns the player to the road instead of a fixed spawn.
func _cave_mouth() -> void:
	_clear.append(Vector3(CAVE_MOUTH.x, 9.0, CAVE_MOUTH.y))
	var stone := TownParts.material(Color(0.4, 0.39, 0.37, 1), 0.97)
	var dark := TownParts.material(Color(0.03, 0.03, 0.035, 1), 1.0)
	var moss := TownParts.material(Color(0.26, 0.34, 0.2, 1), 0.98)

	# A low mound with a squared-off south face, so the mouth reads from the road.
	TownParts.box(
		self, "CaveMound", Vector3(CAVE_MOUTH.x, 1.5, CAVE_MOUTH.y - 2.2),
		Vector3(10.0, 3.0, 7.0), stone
	)
	TownParts.collision(self, Vector3(10.0, 3.0, 7.0), Vector3(CAVE_MOUTH.x, 1.5, CAVE_MOUTH.y - 2.2))
	# The opening is a black slab just in front of the mound face.
	TownParts.box(
		self, "CaveOpening", Vector3(CAVE_MOUTH.x, 1.3, CAVE_MOUTH.y + 1.33),
		Vector3(2.4, 2.4, 0.12), dark
	)
	# Rock shoulders and mossy posts frame the entrance.
	for side in [-1.0, 1.0]:
		TownParts.sphere(
			self, "CaveShoulder",
			Vector3(CAVE_MOUTH.x + side * 2.5, 1.2, CAVE_MOUTH.y + 0.9),
			1.3, 2.4, stone
		)
		TownParts.cylinder(
			self, "CavePost", Vector3(CAVE_MOUTH.x + side * 1.3, 1.2, CAVE_MOUTH.y + 1.2),
			0.22, 0.3, 2.4, moss, Vector3.ZERO, 6
		)
	for i in 5:
		var angle := TAU * float(i) / 5.0
		TownParts.sphere(
			self, "CaveRubble%d" % i,
			Vector3(
				CAVE_MOUTH.x + cos(angle) * 4.0, 0.45,
				CAVE_MOUTH.y + 1.6 + sin(angle) * 1.1
			),
			0.55, 0.9, stone
		)

	var label := Label3D.new()
	label.name = "CaveSign"
	label.text = "The Old Adit"
	label.position = Vector3(CAVE_MOUTH.x, 3.1, CAVE_MOUTH.y + 1.42)
	label.font_size = 44
	label.pixel_size = 0.0038
	label.outline_size = 12
	label.modulate = Color(0.86, 0.83, 0.74, 1)
	label.outline_modulate = Color(0.08, 0.07, 0.06, 1)
	add_child(label)

	var gate := Area3D.new()
	gate.name = "CaveGate"
	gate.collision_layer = 0
	gate.collision_mask = 2
	gate.set_script(GATE_SCRIPT)
	gate.set("target_scene", CAVE_SCENE)
	gate.set("interior", true)
	gate.position = Vector3(CAVE_MOUTH.x, 1.2, CAVE_MOUTH.y + 2.4)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.6, 1.4)
	shape.shape = box
	gate.add_child(shape)
	add_child(gate)


## The way down to the Spider Mother's lair, under the old cottages.
##
## Her old standing spot was an open patch of grass south of the ruined houses.
## It is still a patch of grass; it now has a stone arch and a short flight of
## steps in it. The town's ground is one solid slab, so the stair cannot truly be
## dug into it: the arch stands at ground level and the gate at its mouth carries
## the player into the lair, which is the part that is actually underground.
##
## Webbing on the lintel is the only sign of who lives below. Anyone who has met
## her will recognise it; anyone who has not will still know the stair is not
## empty.
func _spider_stair() -> void:
	_clear.append(Vector3(LAIR_STAIR.x, 8.0, LAIR_STAIR.y))
	_clear.append(Vector3(LAIR_STAIR.x, 8.0, LAIR_STAIR.y + 3.0))
	var stone := TownParts.material(Color(0.36, 0.34, 0.35, 1), 0.98)
	var stone_dark := TownParts.material(Color(0.23, 0.22, 0.24, 1), 1.0)
	var dark := TownParts.material(Color(0.015, 0.015, 0.02, 1), 1.0)
	var lantern := TownParts.material(Color(0.66, 0.6, 0.86, 1), 0.5, 2.0)
	var web := TownParts.material(Color(0.86, 0.84, 0.9, 0.85), 0.95)
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.cull_mode = BaseMaterial3D.CULL_DISABLED

	var base := Vector3(LAIR_STAIR.x, 0.0, LAIR_STAIR.y)

	# The mound the stair runs into: low, wide, and set back so the arch reads
	# against dark stone instead of open sky.
	TownParts.box(
		self, "LairMound", base + Vector3(0, 1.5, -2.6),
		Vector3(8.4, 3.0, 5.2), stone_dark
	)
	TownParts.collision(self, Vector3(8.4, 3.0, 5.2), base + Vector3(0, 1.5, -2.6))

	# Two pillars and a lintel frame a black opening.
	for side in [-1.0, 1.0]:
		TownParts.box(
			self, "LairPillar", base + Vector3(side * 1.85, 1.35, 0.0),
			Vector3(0.7, 2.7, 0.9), stone
		)
		TownParts.collision(self, Vector3(0.7, 2.7, 0.9), base + Vector3(side * 1.85, 1.35, 0.0))
	TownParts.box(
		self, "LairLintel", base + Vector3(0, 2.62, 0.0),
		Vector3(4.4, 0.5, 1.0), stone
	)
	TownParts.collision(self, Vector3(4.4, 0.5, 1.0), base + Vector3(0, 2.62, 0.0))
	TownParts.box(
		self, "LairOpening", base + Vector3(0, 1.35, -0.28),
		Vector3(3.0, 2.7, 0.16), dark
	)

	# Three shallow steps up to the threshold, so the arch is entered rather than
	# stepped over. Each one is solid, so the player walks up it normally.
	for step in 3:
		var rise := 0.12 * float(step + 1)
		var depth := 0.55
		var at := base + Vector3(0, rise * 0.5, 1.45 - float(step) * depth)
		TownParts.box(
			self, "LairStep%d" % step, at, Vector3(3.4, rise, depth + 0.08), stone
		)
		TownParts.collision(self, Vector3(3.4, rise, depth + 0.08), at)

	# Lanterns on the pillars. Violet, so the light on the grass is not daylight.
	for side in [-1.0, 1.0]:
		TownParts.box(
			self, "LairLamp", base + Vector3(side * 1.85, 1.9, 0.42),
			Vector3(0.24, 0.34, 0.24), lantern
		)
		var glow := OmniLight3D.new()
		glow.name = "LairLampLight"
		glow.position = base + Vector3(side * 1.85, 1.9, 0.5)
		glow.light_color = Color(0.66, 0.58, 0.92, 1)
		glow.light_energy = 0.85
		glow.omni_range = 5.5
		glow.shadow_enabled = false
		add_child(glow)

	# Webbing across the lintel and down one pillar. Thin boxes, not a shader.
	for i in 5:
		var strand := TownParts.box(
			self, "LairWeb%d" % i,
			base + Vector3(-1.7 + float(i) * 0.85, 2.1 - float(i % 2) * 0.55, 0.52),
			Vector3(0.03, 1.5, 0.03), web
		)
		strand.rotation = Vector3(0.0, 0.0, deg_to_rad(-22.0 + float(i) * 9.0))

	var label := Label3D.new()
	label.name = "LairSign"
	label.text = "The Webbed Stair"
	label.position = base + Vector3(0, 3.05, 0.2)
	label.font_size = 40
	label.pixel_size = 0.0038
	label.outline_size = 12
	label.modulate = Color(0.84, 0.8, 0.88, 1)
	label.outline_modulate = Color(0.06, 0.05, 0.08, 1)
	add_child(label)

	var gate := Area3D.new()
	gate.name = "LairGate"
	gate.collision_layer = 0
	gate.collision_mask = 2
	gate.set_script(GATE_SCRIPT)
	gate.set("target_scene", LAIR_SCENE)
	gate.set("interior", true)
	gate.position = base + Vector3(0, 1.2, 0.1)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 2.6, 1.0)
	shape.shape = box
	gate.add_child(shape)
	add_child(gate)


## The second way underground: a split in the rock out past the old cottages.
##
## The Old Adit is a mine and stays a mine. This cleft is the wild rock, and the
## cave behind it is different every time the player steps in. One entrance, one
## gate, no new system: the generator does the rest.
func _wild_cave_mouth() -> void:
	_clear.append(Vector3(WILD_CAVE_MOUTH.x, 9.0, WILD_CAVE_MOUTH.y))
	var stone := TownParts.material(Color(0.33, 0.33, 0.35, 1), 0.98)
	var stone_dark := TownParts.material(Color(0.21, 0.21, 0.24, 1), 1.0)
	var dark := TownParts.material(Color(0.01, 0.012, 0.016, 1), 1.0)
	var cold := TownParts.material(Color(0.62, 0.78, 0.86, 1), 0.5, 1.8)

	var base := Vector3(WILD_CAVE_MOUTH.x, 0.0, WILD_CAVE_MOUTH.y)

	# A low outcrop with a split down the middle, so it does not read as a door.
	TownParts.box(
		self, "WildCaveMound", base + Vector3(0, 2.1, -2.6),
		Vector3(9.0, 4.2, 6.0), stone_dark
	)
	TownParts.collision(self, Vector3(9.0, 4.2, 6.0), base + Vector3(0, 2.1, -2.6))
	TownParts.box(
		self, "WildCaveCrack", base + Vector3(0, 1.4, 0.22),
		Vector3(1.5, 2.8, 0.12), dark
	)
	# Two leaning jaws frame the crack; the mesh may rotate, the collider stays
	# axis-aligned because that is all TownParts makes.
	var jaw_left := TownParts.box(
		self, "WildCaveJawL", base + Vector3(-1.8, 1.9, 0.4),
		Vector3(1.5, 3.8, 1.1), stone
	)
	jaw_left.rotation = Vector3(0.0, 0.0, deg_to_rad(9.0))
	TownParts.collision(self, Vector3(1.7, 3.6, 1.2), base + Vector3(-1.8, 1.8, 0.4))
	var jaw_right := TownParts.box(
		self, "WildCaveJawR", base + Vector3(1.8, 2.0, 0.35),
		Vector3(1.4, 4.0, 1.1), stone
	)
	jaw_right.rotation = Vector3(0.0, 0.0, deg_to_rad(-11.0))
	TownParts.collision(self, Vector3(1.6, 3.8, 1.2), base + Vector3(1.8, 1.9, 0.35))

	for i in 6:
		var angle := TAU * float(i) / 6.0
		TownParts.sphere(
			self, "WildCaveRubble%d" % i,
			base + Vector3(cos(angle) * 3.4, 0.4, 0.8 + sin(angle) * 1.4),
			0.5, 0.85, stone
		)

	# Cold light, unlike the warm lantern by the mine: this cave is not worked.
	for side in [-1.0, 1.0]:
		TownParts.box(
			self, "WildCaveLamp", base + Vector3(side * 2.4, 1.7, 1.15),
			Vector3(0.2, 0.3, 0.2), cold
		)
		var glow := OmniLight3D.new()
		glow.name = "WildCaveLight"
		glow.position = base + Vector3(side * 2.4, 1.7, 1.25)
		glow.light_color = Color(0.62, 0.78, 0.9, 1)
		glow.light_energy = 0.8
		glow.omni_range = 6.0
		glow.shadow_enabled = false
		add_child(glow)

	var label := Label3D.new()
	label.name = "WildCaveSign"
	label.text = "The Breathing Cleft"
	label.position = base + Vector3(0, 4.35, 0.5)
	label.font_size = 42
	label.pixel_size = 0.0038
	label.outline_size = 12
	label.modulate = Color(0.82, 0.86, 0.88, 1)
	label.outline_modulate = Color(0.06, 0.07, 0.08, 1)
	add_child(label)

	var gate := Area3D.new()
	gate.name = "WildCaveGate"
	gate.collision_layer = 0
	gate.collision_mask = 2
	gate.set_script(GATE_SCRIPT)
	gate.set("target_scene", WILD_CAVE_SCENE)
	gate.set("interior", true)
	gate.position = base + Vector3(0, 1.2, 0.9)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.4, 0.9)
	shape.shape = box
	gate.add_child(shape)
	add_child(gate)


## A roadside memory beside the cave. The first spell the player can cast is
## Recall, so one stone lives where the player already walks: on the north road
## just outside the Old Adit. Content, not a new system; the stone is a scene.
func _memory_stone() -> void:
	var spot := Vector3(CAVE_MOUTH.x + 6.6, 0.05, CAVE_MOUTH.y + 2.6)
	_clear.append(Vector3(spot.x, 6.0, spot.z))

	var stone := MEMORY_STONE_SCENE.instantiate()
	stone.name = "CaveMemoryStone"
	stone.position = spot
	stone.set("memory_title", "The Nail Count")
	stone.set(
		"memory_text",
		"A miner stood here at the end of a shift, counting the nails in his"
		+ " palm because he could not remember whether he had already been paid."
		+ "\n\nThe count came to nine. The tenth nail was in his boot."
	)
	add_child(stone)


## Four quiet stones away from the roads. Each keeps a memory and pays a small
## permanent favour the first time it is recalled, so exploring the edges of the
## Hollow is worth more than the view. Contents, not a new system: one scene.
func _hidden_memories() -> void:
	_add_hidden_memory(
		"HiddenMemoryMill",
		Vector2(-62.0, -12.0),
		"The Mill That Wasn't",
		"A mill stood here for eleven years and ground nothing. The stone was"
		+ " already too heavy to move, so the town called it a mill and used it"
		+ " to keep the rain off meetings.\n\nThe wheel is gone. The meetings continue.",
		{},
		{"reward_silk": 10.0, "reward_flag": &"memory.mill"}
	)
	_add_hidden_memory(
		"HiddenMemoryFerry",
		Vector2(-70.0, 44.0),
		"The Ferryman's Rope",
		"There was never a river here wide enough for a ferry. The ferryman"
		+ " waited anyway, and every so often someone paid him to be waited for."
		+ "\n\nHe left the rope. It is still tied to the same post.",
		{},
		{
			"reward_item": &"item.health_potion",
			"reward_amount": 1,
			"reward_flag": &"memory.ferry",
		}
	)
	_add_hidden_memory(
		"HiddenMemorySwarm",
		Vector2(66.0, -26.0),
		"The First Swarm",
		"The Hive Tower's first swarm arrived before the tower did. The"
		+ " beekeepers built around the place the bees had already chosen, and"
		+ " the walls grew crooked to keep out of their way.\n\nOne tooth was"
		+ " offered that day. It is still holding something.",
		{},
		{"reward_anchoring": 1, "reward_flag": &"memory.swarm"}
	)
	_add_hidden_memory(
		"HiddenMemoryNames",
		Vector2(18.0, -58.0),
		"The Names on the Stones",
		"The old settlement's stones were reused, face down, for the town's"
		+ " first doorsteps. Every generation since has walked over somebody's"
		+ " name without knowing it.\n\nThe stone remembers being a doorstep.",
		{},
		{
			"reward_item": &"item.gemstone",
			"reward_amount": 1,
			"reward_flag": &"memory.names",
		}
	)


## One hidden stone. `extra` and `rewards` are applied before the node enters
## the tree so the scene's exported fields are the only source of truth.
func _add_hidden_memory(
	node_name: String,
	at: Vector2,
	title: String,
	text: String,
	extra: Dictionary,
	rewards: Dictionary
) -> void:
	_clear.append(Vector3(at.x, 6.0, at.y))
	var stone := MEMORY_STONE_SCENE.instantiate()
	stone.name = node_name
	stone.position = Vector3(at.x, 0.05, at.y)
	stone.set("memory_title", title)
	stone.set("memory_text", text)
	for key in extra:
		stone.set(key, extra[key])
	for key in rewards:
		stone.set(key, rewards[key])
	add_child(stone)


## The two outlying villages keep their own stories: one well and two hidden
## memories each, so leaving the Hollow is worth more than the view. Content,
## not a new system; placed after `_villages()` so their `_clear` circles are
## already registered.
func _village_lore() -> void:
	# Ashfall, in the northern bog.
	_village_well(
		"AshfallWell",
		Vector2(12.0, -294.0),
		"The Bog Well",
		PackedStringArray(
			[
				"The water here is brown and honest. The bog does not pretend to be a river.",
				"Ashfall's first winter, the well froze from the bottom up. The bucket came up warm.",
				"Nobody drinks from it now. It is still the first place anyone looks when something is missing.",
			]
		),
		{"reward_silk": 10.0, "reward_flag": &"well.ashfall"}
	)
	_add_hidden_memory(
		"HiddenMemoryAshfallCount",
		Vector2(-6.0, -276.0),
		"The Flake Count",
		"Ashfall counts the flakes that fall before the thaw. The number is kept on the"
		+ " chapel door in chalk, and every year it is one more than the year before."
		+ "\n\nOne flake never lands. It is the one the count is for.",
		{},
		{"reward_silk": 8.0, "reward_flag": &"memory.ashfall_flake"}
	)
	_add_hidden_memory(
		"HiddenMemoryAshfallLantern",
		Vector2(42.0, -326.0),
		"The Cold Lantern",
		"A cold violet lantern hangs at the edge of the green. It was lit for a"
		+ " reed-cutter who went out at dusk and came back at dawn, every time,"
		+ " until the one time she did not.\n\nIt is not grief. It is a schedule"
		+ " that has not been told to stop.",
		{},
		{
			"reward_item": &"item.honey",
			"reward_amount": 1,
			"reward_flag": &"memory.ashfall_lantern",
		}
	)

	# Thornridge, in the eastern rock hills.
	_village_well(
		"ThornridgeWell",
		Vector2(339.0, 23.0),
		"The Gully Well",
		PackedStringArray(
			[
				"The gully takes the rain and gives back a well. The stonecutters call that a fair trade.",
				"A stone went missing from the bridge the year the well was dug. Nobody carried it far.",
				"The well is deepest on the side that faces the peaks. So is the bridge.",
			]
		),
		{
			"reward_item": &"item.stone",
			"reward_amount": 3,
			"reward_flag": &"well.thornridge",
		}
	)
	_add_hidden_memory(
		"HiddenMemoryThornBridge",
		Vector2(290.0, 60.0),
		"The Bridge Debt",
		"The low bridge was built from seven stones. The quarry remembers cutting six."
		+ "\n\nEvery spring the bridge loses one stone and gets it back by autumn."
		+ " The debt is not the stone. It is the seventh.",
		{},
		{
			"reward_item": &"item.gemstone",
			"reward_amount": 1,
			"reward_flag": &"memory.thorn_bridge",
		}
	)
	_add_hidden_memory(
		"HiddenMemoryThornQuarry",
		Vector2(360.0, 52.0),
		"The Quarry Echo",
		"The quarry answers a beat late. The stonecutters use it as a clock,"
		+ " and the ones who work alone learn to stop when the echo does."
		+ "\n\nThe echo has never once answered a question.",
		{},
		{"reward_silk": 8.0, "reward_flag": &"memory.thorn_quarry"}
	)


## One village well. The node builds its own light and collision; this only
## places it and hands it the writing.
func _village_well(
	node_name: String,
	at: Vector2,
	title: String,
	lines: PackedStringArray,
	rewards: Dictionary
) -> void:
	_clear.append(Vector3(at.x, 10.0, at.y))
	var well := LORE_WELL_SCENE.instantiate()
	well.name = node_name
	well.position = Vector3(at.x, 0.05, at.y)
	well.set("well_title", title)
	well.set("lines", lines)
	for key in rewards:
		well.set(key, rewards[key])
	add_child(well)


## Signposts where the north and east roads leave the Hollow. The distances are
## read from `VILLAGES`, so moving a village or renaming it updates the signs.
func _road_signs() -> void:
	var north := Vector2(7.0, -108.0)
	var east := Vector2(108.0, 19.0)
	_clear.append(Vector3(north.x, 4.0, north.y))
	_clear.append(Vector3(east.x, 4.0, east.y))
	_prop(TownProp.Kind.SIGNPOST, north, {
		"text": _road_sign_text(north),
		"size": Vector3(2.1, 0.95, 0.0),
		"facing_degrees": 0.0,
	})
	_prop(TownProp.Kind.SIGNPOST, east, {
		"text": _road_sign_text(east),
		"size": Vector3(2.1, 0.95, 0.0),
		"facing_degrees": -90.0,
	})


func _road_sign_text(from: Vector2) -> String:
	var lines := PackedStringArray()
	for definition in VILLAGES:
		var centre: Vector2 = definition["centre"]
		var metres := int(roundf(from.distance_to(centre)))
		lines.append("%s  %d m" % [definition["name"], metres])
	return "\n".join(lines)



func _village_gates(definition: Dictionary, doorsteps: Array[Vector2]) -> void:
	var interiors: Array = definition["interiors"]
	var centre: Vector2 = definition["centre"]
	var total := mini(interiors.size(), doorsteps.size())
	var pad_material := TownParts.material(Color(0.56, 0.55, 0.5, 1), 0.95)
	for i in total:
		var step_at := doorsteps[i]
		# The doorstep pad turns with the house, so the walk-through volume sits
		# square across the doorway instead of at an arbitrary world angle.
		var to_centre := centre - step_at
		var facing := atan2(-to_centre.x, -to_centre.y)

		# A pale stone sill on the ground marks the doors that can be entered.
		var pad := TownParts.box(
			self, "%sSill%d" % [definition["name"], i],
			Vector3(step_at.x, 0.05, step_at.y), Vector3(1.9, 0.04, 1.1), pad_material
		)
		pad.rotation.y = facing

		var gate := Area3D.new()
		gate.name = "%sDoor%d" % [definition["name"], i]
		gate.collision_layer = 0
		gate.collision_mask = 2
		gate.set_script(GATE_SCRIPT)
		gate.set("target_scene", String(interiors[i]))
		gate.set("interior", true)
		gate.position = Vector3(step_at.x, 1.2, step_at.y)
		gate.rotation.y = facing

		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 2.4, 1.0)
		shape.shape = box
		gate.add_child(shape)
		add_child(gate)


## The village's own flag on a stone plinth, outside the houses. The whole flag
## turns to face the green, so the emblem reads as the player walks in.
func _village_flag(definition: Dictionary) -> void:
	var centre: Vector2 = definition["centre"]
	var at: Vector2 = centre + Vector2(definition["flag_at"])
	var flag := Node3D.new()
	flag.name = "%sFlag" % definition["name"]
	flag.position = Vector3(at.x, 0.0, at.y)
	var to_centre := centre - at
	flag.rotation.y = atan2(-to_centre.x, -to_centre.y)
	add_child(flag)

	var timber := TownParts.material(Color(0.32, 0.24, 0.16, 1), 0.85)
	var stone := TownParts.material(Color(0.5, 0.49, 0.46, 1), 0.95)
	TownParts.box(flag, "Plinth", Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), stone)
	TownParts.cylinder(flag, "Pole", Vector3(0, 2.65, 0), 0.06, 0.08, 5.3, timber, Vector3.ZERO, 8)
	TownParts.sphere(flag, "Finial", Vector3(0, 5.36, 0), 0.12, 0.22, timber)
	TownParts.box(flag, "Crossbar", Vector3(0.62, 4.98, 0), Vector3(1.24, 0.06, 0.06), timber)
	TownParts.collision(flag, Vector3(0.5, 2.6, 0.5), Vector3(0, 1.3, 0))

	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	banner.mesh = _banner_mesh(2.5, 1.55)
	banner.material_override = _banner_material(definition)
	banner.position = Vector3(1.27, 4.2, 0.0)
	flag.add_child(banner)

	# The emblem hangs a couple of centimetres off the cloth and is repeated on
	# the back, because a flag on a pole is seen from both sides.
	for side in [-1.0, 1.0]:
		if definition["emblem"] == &"ash":
			_ash_emblem(flag, definition, side * 0.045)
		else:
			_thorn_emblem(flag, definition, side * 0.045)

	TownParts.merge_children(flag)


## The flag cloth: a quad in the XY plane, with its UV origin at the bottom-left
## so a vertical gradient reads bottom to top.
func _banner_mesh(width: float, height: float) -> Mesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-width * 0.5, -height * 0.5, 0),
		Vector3(width * 0.5, -height * 0.5, 0),
		Vector3(width * 0.5, height * 0.5, 0),
		Vector3(-width * 0.5, height * 0.5, 0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _banner_material(definition: Dictionary) -> StandardMaterial3D:
	var palette: Array = definition["flag"]
	var gradient := Gradient.new()
	if definition["emblem"] == &"ash":
		# Grey at the top, dirty white through the middle, marsh green at the foot.
		gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.32, 0.74, 1.0])
		gradient.colors = PackedColorArray([
			palette[2], palette[2], palette[1], palette[1], palette[0],
		])
	else:
		# Slate, lighter at the foot so the bridge and peaks stand out.
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([palette[1], palette[0], palette[0]])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 64
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Unshaded so the cloth stays readable from both faces and under the fog.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## Ashfall: three falling ash flakes over a reed-filled marsh. The middle flake
## has two wings, so at a glance it is almost a moth.
func _ash_emblem(flag: Node3D, definition: Dictionary, z: float) -> void:
	var swatches: Array = definition["swatches"]
	var ash := TownParts.material(swatches[1], 0.9)
	var reed := TownParts.material(swatches[2].darkened(0.15), 0.95)

	# Reeds rising out of the marsh band along the bottom of the cloth.
	for i in 6:
		var x := -1.02 + i * 0.41
		var tall := 0.34 + 0.1 * float(i % 3)
		var stem := TownParts.box(
			flag, "Reed", Vector3(1.27 + x, 4.2 - 0.62 + tall * 0.5, z),
			Vector3(0.035, tall, 0.02), reed
		)
		stem.rotation.z = deg_to_rad(-6.0 + 4.0 * float(i % 4))

	# Flake one and flake three: plain diamonds.
	for at in [Vector2(-0.58, 0.36), Vector2(0.66, 0.44)]:
		var flake := TownParts.box(
			flag, "AshFlake", Vector3(1.27 + at.x, 4.2 + at.y, z),
			Vector3(0.16, 0.16, 0.02), ash
		)
		flake.rotation.z = deg_to_rad(45.0)

	# Flake two: two wings meeting in the middle, the moth.
	for wing in [-1.0, 1.0]:
		var half := TownParts.box(
			flag, "MothWing", Vector3(1.27 + 0.06 + wing * 0.055, 4.2 + 0.02, z),
			Vector3(0.1, 0.2, 0.02), ash
		)
		half.rotation.z = deg_to_rad(wing * 32.0)


## Thornridge: a white stone bridge between two rust-red, thorn-covered peaks.
func _thorn_emblem(flag: Node3D, definition: Dictionary, z: float) -> void:
	var swatches: Array = definition["swatches"]
	var stone := TownParts.material(swatches[3], 0.9)
	var rust := TownParts.material(swatches[1], 0.95)
	var pine := TownParts.material(swatches[2], 0.95)

	# Two peaks either side of the gap.
	for peak in [-0.6, 0.58]:
		TownParts.prism(
			flag, "Peak", Vector3(1.27 + peak, 4.2 - 0.22, z),
			Vector3(0.82, 1.05, 0.03), rust
		)
		# Thorn scrub on the shoulders, in dark pine.
		for i in 3:
			var thorn := TownParts.box(
				flag, "Thorn", Vector3(1.27 + peak - 0.22 + i * 0.22, 4.2 - 0.3 + i * 0.06, z),
				Vector3(0.07, 0.07, 0.02), pine
			)
			thorn.rotation.z = deg_to_rad(45.0)

	# The bridge deck, its rail, and three piers dropping into the gap.
	TownParts.box(flag, "BridgeDeck", Vector3(1.27, 4.2 - 0.02, z), Vector3(1.0, 0.09, 0.03), stone)
	TownParts.box(flag, "BridgeRail", Vector3(1.27, 4.2 + 0.12, z), Vector3(1.0, 0.04, 0.02), stone)
	for pier in [-0.33, 0.0, 0.33]:
		TownParts.box(flag, "BridgePier", Vector3(1.27 + pier, 4.2 - 0.2, z), Vector3(0.06, 0.3, 0.02), stone)


## Villagers who live in the village rather than the Hollow. Primitive-bodied
## `Npc` instances, so the two outlying settlements read differently from the
## 2D-art villagers of Mycelgrove.
func _village_people(definition: Dictionary) -> void:
	var centre: Vector2 = definition["centre"]
	var people: Array = definition["people"]
	var lane_angle := atan2(-30.0, 66.0)
	for i in people.size():
		var person: Dictionary = people[i]
		var npc: CharacterBody3D = NPC_SCENE.instantiate()
		npc.name = "%s_%s" % [definition["name"], String(person["name"]).to_snake_case()]
		var angle := lane_angle + PI + float(i) * 0.9
		npc.position = Vector3(
			centre.x + cos(angle) * 6.5, 0.05, centre.y + sin(angle) * 6.5
		)
		npc.set("npc_name", person["name"])
		npc.set("role", person["role"])
		npc.set("greeting_lines", PackedStringArray(person["lines"]))
		npc.set("coat_color", person["coat"])
		npc.set("trim_color", person["trim"])
		npc.set("skin_color", person["skin"])
		npc.set("hair_color", person["hair"])
		npc.set("hat_style", int(person["hat"]))
		npc.set("long_skirt", bool(person["skirt"]))
		npc.set("wander", true)
		npc.set("pause_at_points", 2.0)
		npc.set("walk_speed", 1.1)

		# One-line errands. The data lives next to the villager it belongs to, so
		# a new village quest is one dictionary entry and no new scene.
		if person.has("quest"):
			var quest: Dictionary = person["quest"]
			npc.set("offers_quest", quest["id"])
			npc.set("deliver_item", quest.get("deliver", &""))
			npc.set("deliver_amount", int(quest.get("deliver_amount", 1)))
			npc.set("reward_item", quest.get("reward", &""))
			npc.set("reward_amount", int(quest.get("reward_amount", 1)))
			npc.set("reward_coins", int(quest.get("coins", 0)))
			npc.set("reward_xp", int(quest.get("xp", 0)))
			npc.set("reward_favor", int(quest.get("favor", 0)))
			npc.set("offer_lines", PackedStringArray(quest.get("offer", [])))
			npc.set("waiting_lines", PackedStringArray(quest.get("waiting", [])))
			npc.set("turn_in_lines", PackedStringArray(quest.get("turn_in", [])))

		# A ring inside the houses and outside the benches, offset per villager so
		# the two never shadow each other.
		var ring := PackedVector3Array()
		for step in 4:
			var a := lane_angle + float(i) * 0.8 + TAU * float(step) / 4.0
			ring.append(Vector3(centre.x + cos(a) * 15.0, 0.05, centre.y + sin(a) * 15.0))
		npc.set("wander_points", ring)
		add_child(npc)


## Wood and stone the outlying villages provide. Placed on a ring outside the
## houses so a node never sits inside a wall, and worked with the same tools as
## the town's own deadfall and seams.
func _village_gathering(definition: Dictionary, doorsteps: Array[Vector2]) -> void:
	var centre: Vector2 = definition["centre"]
	var key := String(definition["kind"])
	var is_thorn: bool = definition["kind"] == &"thornridge"

	# Three resource nodes on the outer ring, at angles the lane does not use.
	var angles: Array[float] = [PI * 0.5, PI * 1.25, PI * 1.72]
	for i in angles.size():
		var angle := angles[i]
		var radius := 30.0 + 1.5 * float(i)
		var place := centre + Vector2(cos(angle), sin(angle)) * radius
		var node: StaticBody3D = GATHER_SCENE.instantiate()
		node.name = "%sGather%d" % [definition["name"], i]
		node.position = Vector3(place.x, 0.0, place.y)
		node.set("save_id", StringName("gather.%s.node_%d" % [key, i]))
		node.set("regrow_days", 5 if is_thorn else 4)
		if is_thorn:
			# Ore outcrops and one gem seam in the rock hills.
			node.set("kind", GatherNode.Kind.CRYSTAL if i == 2 else GatherNode.Kind.ORE)
			node.set("required_tool_tag", &"pickaxe")
			node.set("sprite_texture", TEX_ROCK)
			node.set("sprite_height", 1.3 if i == 2 else 1.6)
			node.set("collision_radius", 0.7 if i == 2 else 0.85)
			node.set("collision_height", 1.0 if i == 2 else 1.2)
			node.set("hits_required", 4 if i == 2 else 3)
			node.set("drop_item", &"item.gemstone" if i == 2 else &"item.iron_ore")
			node.set("drop_amount", 1 if i == 2 else 2)
			node.set("verb", "Mine")
			node.set("missing_tool_hint", "You need a pickaxe for this")
			node.set("depleted_message", "The seam breaks down to rubble" if i < 2 else "The crystal comes free with a clean ring")
			if i == 2:
				node.set("tint", Color(0.72, 0.86, 0.95, 1))
		else:
			# Dead snags standing in the bog.
			node.set("kind", GatherNode.Kind.TREE)
			node.set("required_tool_tag", &"axe")
			node.set("sprite_texture", TEX_TREE)
			node.set("sprite_height", 4.6 + 0.5 * float(i))
			node.set("collision_radius", 0.42)
			node.set("hits_required", 3)
			node.set("drop_item", &"item.wood")
			node.set("drop_amount", 2 + i)
			node.set("verb", "Chop")
			node.set("depleted_message", "The snag comes apart in your hands")
		add_child(node)

	# Thornridge hands the player a pickaxe at the forge door, so mining is
	# reachable without crafting one out of ore the player cannot mine yet.
	if is_thorn and doorsteps.size() > 1:
		var door: Vector2 = doorsteps[1]
		var side := Vector2(door.y - centre.y, centre.x - door.x).normalized()
		var pickup: StaticBody3D = PICKUP_SCENE.instantiate()
		pickup.name = "%sPickaxe" % definition["name"]
		pickup.position = Vector3(door.x + side.x * 1.3, 0.3, door.y + side.y * 1.3)
		pickup.set("save_id", StringName("pickup.%s.forge_pickaxe" % key))
		pickup.set("item_id", &"item.pickaxe")
		add_child(pickup)


## Ashfall's dressing: standing bog water, reeds, dead snags, and cold violet
## lantern light. Colder and stranger than the Hollow's meadows.
func _ashfall_dressing(centre: Vector2) -> void:
	# The bog water sits outside the houses, never across the lane or the road in.
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.35
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(29.0, 35.0)
		if _on_a_road(at):
			continue
		var radius := _rng.randf_range(2.6, 4.6)
		TownParts.cylinder(
			self, "AshfallPool%d" % i, Vector3(at.x, 0.035, at.y),
			radius, radius, 0.03, _water(Color(0.19, 0.26, 0.24, 0.76)), Vector3.ZERO, 20
		)
		for n in 9:
			_reed_points.append(at + Vector2(
				_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius)
			))

	for i in 16:
		var angle := _rng.randf() * TAU
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(20.0, 34.0)
		if _on_a_road(at):
			continue
		var roll := _rng.randf()
		if roll < 0.4:
			_prop(TownProp.Kind.DEAD_TREE, at, {"size": Vector3(1.0, _rng.randf_range(2.6, 4.4), 1.0)})
		elif roll < 0.72:
			_prop(TownProp.Kind.PINE, at, {
				"size": Vector3(1.0, _rng.randf_range(5.0, 8.0), 1.0),
				"leaf_tint": Color(0.8, 0.85, 0.82, 1),
				"wood_item": &"item.birch_log",
			})
		else:
			_billboard(TEX_ROCK, at, _rng.randf_range(0.6, 1.4) * 1.08, 0.0)

	# Violet lanterns around the green: the one cool colour in a grey place.
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 1.1
		var at := centre + Vector2(cos(angle), sin(angle)) * 16.0
		_prop(TownProp.Kind.LANTERN, at, {"accent": Color(0.58, 0.46, 0.72, 1)})

	# The settlement's two landmarks: a lamp shrine to the bog's returned dead
	# and the Fenwalker's raised watchpost. Both are built from primitives, so
	# they cost no new art and merge into the realm's material batches.
	_ashfall_shrine(centre + Vector2(-9.7, 12.0))
	_ashfall_watchpost(centre + Vector2(12.3, -10.9))

	for i in 10:
		var angle := _rng.randf() * TAU
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(8.0, 22.0)
		_billboard(TEX_MUSHROOM, at, 0.4, 0.3)


## A small wayside shrine: a stone plinth, a timber canopy, a carved slab, and
## cold violet lamps. It matches the shrine keeper's line about keeping a lamp
## for the ones the bog gives back, without naming a new deity.
func _ashfall_shrine(at: Vector2) -> void:
	var stone := TownParts.material(Color(0.5, 0.5, 0.48, 1), 0.96)
	var pale := TownParts.material(Color(0.68, 0.67, 0.63, 1), 0.94)
	var timber := TownParts.material(Color(0.31, 0.24, 0.18, 1), 0.92)
	var violet := TownParts.material(Color(0.69, 0.56, 0.86, 1), 0.55, 2.2)
	# Its own holder keeps the landmark as one named node; the realm's global
	# merge would otherwise dissolve it into a material batch.
	var holder := Node3D.new()
	holder.name = "AshfallShrine"
	holder.position = Vector3(at.x, 0.0, at.y)
	add_child(holder)

	TownParts.box(holder, "Plinth", Vector3(0, 0.16, 0), Vector3(2.8, 0.32, 2.0), stone)
	TownParts.collision(holder, Vector3(2.8, 0.32, 2.0), Vector3(0, 0.16, 0))
	TownParts.box(holder, "Back", Vector3(0, 1.0, -0.68), Vector3(2.3, 1.5, 0.26), stone)
	TownParts.box(holder, "Slab", Vector3(0, 0.86, -0.52), Vector3(0.78, 1.12, 0.14), pale)
	for side in [-1.0, 1.0]:
		TownParts.cylinder(
			holder, "Post", Vector3(side * 1.0, 1.15, 0.62),
			0.09, 0.11, 1.9, timber, Vector3.ZERO, 6
		)
		TownParts.collision(holder, Vector3(0.22, 1.9, 0.22), Vector3(side * 1.0, 1.15, 0.62))
	TownParts.prism(holder, "Roof", Vector3(0, 2.22, 0.0), Vector3(2.9, 0.52, 1.9), timber)
	# Offerings: a shallow bowl and three pale caps.
	TownParts.cylinder(holder, "Bowl", Vector3(0.7, 0.38, 0.62), 0.26, 0.3, 0.12, timber, Vector3.ZERO, 10)
	for i in 3:
		var angle := TAU * float(i) / 3.0
		TownParts.sphere(
			holder, "Offering%d" % i,
			Vector3(0.7 + cos(angle) * 0.13, 0.47, 0.62 + sin(angle) * 0.13),
			0.07, 0.12, pale
		)
	# Two lamps on the plinth, plus their glow.
	for side in [-1.0, 1.0]:
		TownParts.box(
			holder, "Lamp", Vector3(side * 0.95, 0.5, 0.72),
			Vector3(0.18, 0.24, 0.18), violet
		)
		var glow := OmniLight3D.new()
		glow.name = "Glow"
		glow.position = Vector3(side * 0.95, 0.68, 0.72)
		glow.light_color = Color(0.62, 0.5, 0.88, 1)
		glow.light_energy = 1.1
		glow.omni_range = 5.5
		glow.shadow_enabled = false
		holder.add_child(glow)
	TownParts.merge_children(holder)


## The Fenwalker's watchpost: a plank platform on four posts with a ladder and a
## violet lamp, raised above the bog pools. Scenery the player can walk under.
func _ashfall_watchpost(at: Vector2) -> void:
	var timber := TownParts.material(Color(0.32, 0.26, 0.2, 1), 0.93)
	var dark := TownParts.material(Color(0.19, 0.16, 0.13, 1), 0.95)
	var violet := TownParts.material(Color(0.7, 0.57, 0.86, 1), 0.55, 2.0)
	var holder := Node3D.new()
	holder.name = "AshfallWatchpost"
	holder.position = Vector3(at.x, 0.0, at.y)
	add_child(holder)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.cylinder(
				holder, "Post", Vector3(sx * 1.2, 1.1, sz * 1.2),
				0.1, 0.14, 2.2, dark, Vector3.ZERO, 6
			)
			TownParts.cylinder_collision(holder, 0.16, 2.2, Vector3(sx * 1.2, 1.1, sz * 1.2))
	TownParts.box(holder, "Deck", Vector3(0, 2.26, 0), Vector3(3.0, 0.18, 3.0), timber)
	TownParts.collision(holder, Vector3(3.0, 0.18, 3.0), Vector3(0, 2.26, 0))
	# A rail on three sides, leaving the ladder side open.
	for side in [-1.0, 1.0]:
		TownParts.box(
			holder, "Rail", Vector3(0, 2.92, side * 1.42),
			Vector3(3.0, 0.1, 0.08), timber
		)
		TownParts.box(
			holder, "RailEnd", Vector3(side * 1.42, 2.92, 0),
			Vector3(0.08, 0.1, 3.0), timber
		)
	# A leaning ladder on the open (+z) side.
	for side in [-1.0, 1.0]:
		var rail := TownParts.cylinder(
			holder, "LadderRail", Vector3(side * 0.34, 1.2, 1.55),
			0.05, 0.06, 2.6, timber, Vector3.ZERO, 5
		)
		rail.rotation.x = deg_to_rad(14.0)
	for i in 6:
		var rung := TownParts.box(
			holder, "LadderRung", Vector3(0, 0.28 + i * 0.38, 1.78 - i * 0.09),
			Vector3(0.74, 0.05, 0.1), timber
		)
		rung.rotation.x = deg_to_rad(14.0)
	# Lamp on the corner nearest the lane.
	TownParts.box(holder, "Lamp", Vector3(1.2, 3.35, 1.2), Vector3(0.2, 0.28, 0.2), violet)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(1.2, 3.35, 1.2)
	glow.light_color = Color(0.64, 0.52, 0.9, 1)
	glow.light_energy = 1.5
	glow.omni_range = 6.5
	glow.shadow_enabled = false
	holder.add_child(glow)
	TownParts.merge_children(holder)


## Thornridge's dressing: rock outcrops, thorny scrub, dark pines, standing
## stones along the lane, and a low stone bridge over the dry gully.
func _thornridge_dressing(centre: Vector2) -> void:
	var stone := TownParts.material(Color(0.5, 0.5, 0.49, 1), 0.96)
	var timber := TownParts.material(Color(0.3, 0.22, 0.16, 1), 0.9)

	# The gully cuts north-south across the EastRoad, and a low stone bridge
	# carries the road over it at x 299, where the road runs east-west.
	_ribbon("ThornGully", PackedVector3Array([
		Vector3(299.0, 0, 12.0),
		Vector3(299.0, 0, 43.0),
		Vector3(299.0, 0, 74.0),
	]), 5.0, Color(0.3, 0.28, 0.25, 1), 0.042, false, TEX_STONE)
	_thorn_bridge(Vector3(299.0, 0, 43.0), stone, timber)

	for i in 18:
		var angle := _rng.randf() * TAU
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(20.0, 36.0)
		if _on_a_road(at):
			continue
		var roll := _rng.randf()
		if roll < 0.42:
			_prop(TownProp.Kind.ROCK, at, {"size": Vector3(
				_rng.randf_range(1.2, 2.6), _rng.randf_range(1.0, 2.2), _rng.randf_range(1.2, 2.4)
			)})
		elif roll < 0.72:
			_prop(TownProp.Kind.BUSH, at, {"leaf_tint": Color(0.28, 0.34, 0.26, 1)})
		else:
			_prop(TownProp.Kind.PINE, at, {"size": Vector3(1.0, _rng.randf_range(5.0, 9.0), 1.0)})

	# Standing stones along the lane, like a half-remembered gate.
	for i in 4:
		var at := centre + Vector2(-24.0 + i * 3.0, 30.0 - i * 1.2)
		TownParts.box(self, "StandingStone%d" % i, Vector3(at.x, 0.75, at.y),
			Vector3(0.5, 1.5, 0.4), stone)
		TownParts.collision(self, Vector3(0.5, 1.5, 0.4), Vector3(at.x, 0.75, at.y))

	for i in 8:
		var angle := _rng.randf() * TAU
		var at := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(9.0, 22.0)
		_billboard(TEX_ROCK, at, _rng.randf_range(0.5, 1.0) * 1.08, 0.0)


## A low stone bridge. The deck sits almost flush with the ground so the player
## walks over it without a step, and the parapets are the only collision.
func _thorn_bridge(at: Vector3, stone: StandardMaterial3D, timber: StandardMaterial3D) -> void:
	var rust := TownParts.material(Color(0.52, 0.3, 0.17, 1), 0.92)
	# The deck uses the stone texture rather than flat colour, or the sun turns
	# it into a bright white slab against the textured road.
	var deck := _tiled(Color(0.46, 0.45, 0.43, 1), TEX_STONE, 0.3)
	TownParts.box(self, "ThornBridgeDeck", at + Vector3(0, 0.11, 0), Vector3(7.0, 0.16, 4.2), deck)
	# Low parapets: tall enough to read as a crossing from the road, short enough
	# that the player can still see the gully on the far side of them.
	for side in [-1.0, 1.0]:
		TownParts.box(
			self, "ThornBridgeRail", at + Vector3(0, 0.36, side * 1.95),
			Vector3(7.0, 0.34, 0.24), rust
		)
		TownParts.collision(self, Vector3(7.0, 0.34, 0.24), at + Vector3(0, 0.36, side * 1.95))
	for i in 3:
		TownParts.box(
			self, "ThornBridgePier", at + Vector3(-2.4 + i * 2.4, -0.25, 0),
			Vector3(0.6, 0.7, 4.0), stone
		)
	# Two wooden hand-posts so it reads as a crossing, not a wall.
	for side in [-1.0, 1.0]:
		TownParts.cylinder(
			self, "ThornBridgePost", at + Vector3(side * 3.1, 0.72, 1.95),
			0.08, 0.1, 1.5, timber, Vector3.ZERO, 6
		)


# --- ground dressing -------------------------------------------------------


func _dressing() -> void:
	_sample_tufts()
	_batch_tufts()
	_forage()
	_verge_flowers()
	_biome_props()
	_batch_ground_art()
	_batch_reeds()


## Paints the three round "special path" plots as irregular ground patches: a
## cobbled circle in the square, bare earth under the orchard, and a flowery
## grass circle along the lanes. Each variant is one MultiMesh, so ~130 patches
## cost three draw calls.
func _ground_patches() -> void:
	# Only the town lanes (`_path`), not the realm roads or rivers.
	var lanes: Array[Dictionary] = []
	for road in _roads:
		if float(road["radius"]) < 2.7:
			lanes.append(road)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	# A quad is drawn in the XY plane; tip it flat so it lies on the ground.
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)

	for variant in PATCH_REGIONS.size():
		var texture := _keyed_patch(variant)
		if texture == null:
			continue

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.35
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var spots: Array[Dictionary] = []
		var attempts := 0
		while spots.size() < PATCH_COUNT / PATCH_REGIONS.size() and attempts < 400:
			attempts += 1
			var spot := _patch_spot(lanes, spots.size() % 5 != 4)
			if spot.is_empty():
				continue
			spots.append(spot)

		if spots.is_empty():
			continue

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = quad
		multimesh.instance_count = spots.size()
		for i in spots.size():
			var spot: Dictionary = spots[i]
			var at: Vector2 = spot["at"]
			var width: float = spot["width"]
			# Squash one axis a little so a circular plot reads as a worn patch
			# of ground, not a decal dropped on the lawn.
			var basis := Basis(Vector3.UP, float(spot["yaw"])) * flat
			basis = basis.scaled(Vector3(width, width * float(spot["squash"]), 1.0))
			multimesh.set_instance_transform(
				i, Transform3D(basis, Vector3(at.x, float(spot["y"]), at.y))
			)

		var batch := MultiMeshInstance3D.new()
		batch.name = "GroundPatches%d" % variant
		batch.multimesh = multimesh
		batch.material_override = mat
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)


## One patch location: mostly along the town lanes, some loose in the meadow.
## Inside the town the patch sits just above the town floor (y 0.013); outside
## it sits above the region floor (y 0.027). Both stay below the path ribbons.
func _patch_spot(lanes: Array[Dictionary], inside: bool) -> Dictionary:
	if inside and not lanes.is_empty():
		var road: Dictionary = lanes[_rng.randi_range(0, lanes.size() - 1)]
		var points: PackedVector3Array = road["points"]
		var segment := _rng.randi_range(0, points.size() - 2)
		var from := Vector2(points[segment].x, points[segment].z)
		var to := Vector2(points[segment + 1].x, points[segment + 1].z)
		var at := from.lerp(to, _rng.randf())
		var dir := (to - from).normalized()
		var side := Vector2(-dir.y, dir.x)
		# Offset to one verge or the other, clear of the ribbon itself.
		var offset := _rng.randf_range(2.2, 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		at += side * offset
		return {
			"at": at,
			"y": 0.013,
			"width": _rng.randf_range(4.0, 8.5),
			"squash": _rng.randf_range(0.72, 1.0),
			"yaw": _rng.randf() * TAU,
		}

	# The meadow ring beyond the town's own ground.
	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf_range(110.0 * 110.0, 196.0 * 196.0))
	var at := Vector2(cos(angle), sin(angle)) * radius
	if not _is_open(at):
		return {}
	return {
		"at": at,
		"y": 0.027,
		"width": _rng.randf_range(5.0, 10.0),
		"squash": _rng.randf_range(0.7, 1.0),
		"yaw": _rng.randf() * TAU,
	}


## Turns one opaque tileset crop into an alpha-keyed flat decal. The atlas has
## a near-black plate behind the round plots, so the plate is keyed to
## transparency and the crop trimmed to the art's bounds.
func _keyed_patch(index: int) -> Texture2D:
	if index < 0 or index >= PATCH_REGIONS.size():
		return null
	if _patch_textures.size() < PATCH_REGIONS.size():
		_patch_textures.resize(PATCH_REGIONS.size())
	if _patch_textures[index] != null:
		return _patch_textures[index]

	var atlas := TEX_TILESET.get_image()
	if atlas == null:
		return null
	if atlas.is_compressed():
		atlas.decompress()
	var crop := atlas.get_region(PATCH_REGIONS[index])
	if crop.is_empty():
		return null
	crop.convert(Image.FORMAT_RGBA8)

	var used := Rect2i()
	var found := false
	for y in crop.get_height():
		for x in crop.get_width():
			var color := crop.get_pixel(x, y)
			if maxf(maxf(color.r, color.g), color.b) < 0.10:
				crop.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			color.a = 1.0
			crop.set_pixel(x, y, color)
			if found:
				used = used.expand(Vector2i(x, y))
			else:
				used = Rect2i(x, y, 1, 1)
				found = true

	if not found:
		return null
	crop = crop.get_region(used)
	var texture := ImageTexture.create_from_image(crop)
	_patch_textures[index] = texture
	return texture


## Flower clusters along the verges of the town lanes. Walks every lane and
## scatters blooms just off both edges, so every path out of the square has a
## ragged, overgrown border rather than a hard cut.
func _verge_flowers() -> void:
	for road in _roads:
		var reach: float = road["radius"]
		if reach >= 2.7:
			continue
		var points: PackedVector3Array = road["points"]
		for i in points.size() - 1:
			var from := Vector2(points[i].x, points[i].z)
			var to := Vector2(points[i + 1].x, points[i + 1].z)
			var span := from.distance_to(to)
			if span < 0.5:
				continue
			var steps := maxi(1, int(span / 2.6))
			var dir := (to - from).normalized()
			var side := Vector2(-dir.y, dir.x)
			for step in steps:
				var at := from.lerp(to, (step + _rng.randf()) / steps)
				for facing in [-1.0, 1.0]:
					if _rng.randf() > 0.55:
						continue
					var p: Vector2 = (
						at + side * _rng.randf_range(reach + 0.15, reach + 1.2) * float(facing)
					)
					var flower := TEX_FLOWER_CLUSTERS[
						_rng.randi_range(0, TEX_FLOWER_CLUSTERS.size() - 1)
					]
					_billboard(flower, p, _rng.randf_range(0.28, 0.58), 0.4)


func _sample_tufts() -> void:
	var regions: Array[Rect2] = [
		Rect2(-520, -520, 700, 340),
		Rect2(180, -520, 340, 340),
		Rect2(-180, 180, 360, 340),
		Rect2(-520, 180, 340, 340),
		Rect2(-520, -180, 340, 360),
	]
	for i in 900:
		var p: Vector2
		if i < 420:
			# The meadow band right around the village, where the player walks.
			var angle := _rng.randf() * TAU
			p = Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf_range(100.0 * 100.0, 178.0 * 178.0))
		else:
			var rect := regions[_rng.randi_range(0, regions.size() - 1)]
			p = Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
		if not _is_open(p):
			continue
		var region := _region_at(p)
		if region == &"desert" or region == &"ocean" or region == &"arctic":
			continue
		_tuft_points.append({
			"x": p.x,
			"z": p.y,
			"size": _rng.randf_range(1.4, 3.2),
			"variant": _rng.randi_range(0, 3),
		})


func _batch_tufts() -> void:
	if _tuft_points.is_empty():
		return

	# Flower and grass strips cut from the tileset's "Path Edges & Borders" row.
	var regions: Array[Rect2] = [
		Rect2(14, 436, 92, 50),
		Rect2(126, 442, 78, 48),
		Rect2(258, 436, 84, 50),
		Rect2(424, 442, 88, 48),
	]
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	for variant in regions.size():
		var entries: Array[Dictionary] = []
		for entry in _tuft_points:
			if int(entry["variant"]) == variant:
				entries.append(entry)
		if entries.is_empty():
			continue

		var atlas := AtlasTexture.new()
		atlas.atlas = TEX_TILESET
		atlas.region = regions[variant]
		atlas.filter_clip = true

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = atlas
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = quad
		multimesh.instance_count = entries.size()
		for i in entries.size():
			var entry := entries[i]
			var size: float = entry["size"]
			var basis := flat.scaled(Vector3(size, size * 0.55, 1.0))
			multimesh.set_instance_transform(i, Transform3D(basis, Vector3(entry["x"], 0.028, entry["z"])))

		var batch := MultiMeshInstance3D.new()
		batch.name = "GrassTufts%d" % variant
		batch.multimesh = multimesh
		batch.material_override = mat
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)


## Mushroom rings and flower clumps: the Hollow's signature ground cover.
func _forage() -> void:
	for i in 34:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(104.0, 200.0)
		if not _is_open(p):
			continue
		var scale := _rng.randf_range(0.8, 1.4)
		if _rng.randf() < 0.55:
			for n in 3:
				_billboard(TEX_MUSHROOM, p, 0.42 * scale, 0.35)
		else:
			# Four flower looks now, not one: the atlas clusters mixed with the
			# older single flower, each at its own size.
			var flower: Texture2D = TEX_FLOWER
			if _rng.randf() < 0.72:
				flower = TEX_FLOWER_CLUSTERS[_rng.randi_range(0, TEX_FLOWER_CLUSTERS.size() - 1)]
			for n in 6:
				_billboard(flower, p, 0.42 * scale * _rng.randf_range(0.7, 1.25), 0.5)

	# Flower drifts: loose patches of mixed colour along the verge, so walking
	# out of town crosses meadow, white cluster, yellow cluster, and back.
	for i in 26:
		var drift_angle := _rng.randf() * TAU
		var drift := Vector2(cos(drift_angle), sin(drift_angle)) * _rng.randf_range(96.0, 215.0)
		if not _is_open(drift):
			continue
		var drift_flower: Texture2D = (
			TEX_FLOWER_CLUSTERS[_rng.randi_range(0, TEX_FLOWER_CLUSTERS.size() - 1)]
		)
		for n in _rng.randi_range(3, 7):
			_billboard(drift_flower, drift, _rng.randf_range(0.28, 0.62), 0.85)

	for i in 14:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(108.0, 170.0)
		if not _is_open(p):
			continue
		# Old cut stumps only: the painted fern billboards were too easy to
		# mistake for floating plants out in the open.
		if _rng.randf() < 0.5:
			var at := p + Vector2(0.9, 0.4)
			_billboard(TEX_STUMP, at, 0.7, 0.0)
			TownParts.cylinder_collision(self, 0.32, 0.7, Vector3(at.x, 0.35, at.y))


## Logs and loose stones lying on the ground around the town edge, plus boulders
## a pickaxe can break. A brand-new player can gather an axe's worth of wood and
## stone without owning a tool first. Each pickup and boulder persists.
func _ground_forage() -> void:
	# A handful of starter piles just outside the town's own ground, then a
	# wider scatter through the meadow and forest edge.
	var starters: Array[Vector2] = [
		Vector2(-92.0, -18.0), Vector2(86.0, 22.0), Vector2(-12.0, -96.0),
		Vector2(18.0, 94.0), Vector2(-88.0, 46.0), Vector2(94.0, -40.0),
	]
	var index := 0
	for at in starters:
		_forage_pickup(index, at, &"item.spruce_log", ICON_SPRUCE_LOG, 3)
		index += 1
		_forage_pickup(index, at + Vector2(1.4, 0.8), &"item.stone", ICON_STONE, 2)
		index += 1

	for i in 12:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(102.0, 168.0)
		if not _is_open(p):
			continue
		if _rng.randf() < 0.5:
			_forage_pickup(index, p, &"item.spruce_log", ICON_SPRUCE_LOG, 2)
		else:
			_forage_pickup(index, p, &"item.birch_log", ICON_BIRCH_LOG, 2)
		index += 1

	for i in 14:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(101.0, 175.0)
		if not _is_open(p):
			continue
		_forage_pickup(index, p, &"item.stone", ICON_STONE, 2)
		index += 1

	# Boulders the pickaxe can break for stone. Placed among the meadow rocks
	# rather than in the road, so they read as part of the landscape.
	for i in 10:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(110.0, 185.0)
		if not _is_open(p):
			continue
		var node: StaticBody3D = GATHER_SCENE.instantiate()
		node.name = "RealmRock%d" % i
		node.position = Vector3(p.x, 0.0, p.y)
		node.set("save_id", StringName("gather.realm.rock_%d" % i))
		node.set("kind", GatherNode.Kind.ROCK)
		node.set("required_tool_tag", &"pickaxe")
		node.set("sprite_texture", TEX_ROCK)
		node.set("sprite_height", 1.5)
		node.set("collision_radius", 0.75)
		node.set("collision_height", 1.1)
		node.set("hits_required", 3)
		node.set("drop_item", &"item.stone")
		node.set("drop_amount", 2)
		node.set("regrow_days", 5)
		node.set("verb", "Mine")
		node.set("missing_tool_hint", "You need a pickaxe for this")
		node.set("depleted_message", "The boulder splits into fieldstone")
		add_child(node)


func _forage_pickup(
	index: int,
	at: Vector2,
	item_id: StringName,
	texture: Texture2D,
	amount: int
) -> void:
	var pickup: StaticBody3D = PICKUP_SCENE.instantiate()
	pickup.name = "RealmForage%d" % index
	pickup.position = Vector3(at.x, 0.0, at.y)
	pickup.set("save_id", StringName("pickup.realm.forage_%d" % index))
	pickup.set("item_id", item_id)
	pickup.set("amount", amount)
	pickup.set("sprite_texture", texture)
	add_child(pickup)


func _biome_props() -> void:
	# Desert: cacti, boulders, and the odd dead tree.
	for i in 44:
		var p := Vector2(_rng.randf_range(190.0, 505.0), _rng.randf_range(-170.0, 170.0))
		if not _is_open(p):
			continue
		var roll := _rng.randf()
		if roll < 0.45:
			_prop(TownProp.Kind.CACTUS, p, {"size": Vector3(1.0, _rng.randf_range(1.8, 3.4), 1.0)})
		elif roll < 0.72:
			_billboard(TEX_ROCK, p, _rng.randf_range(0.7, 1.8) * 1.08, 0.0)
		else:
			_prop(TownProp.Kind.DEAD_TREE, p, {"size": Vector3(1.0, _rng.randf_range(2.6, 4.5), 1.0)})

	# Arctic: snow-laden pines and stones.
	for i in 50:
		var p := Vector2(_rng.randf_range(-505.0, 170.0), _rng.randf_range(-505.0, -190.0))
		if not _is_open(p):
			continue
		if _rng.randf() < 0.4:
			_prop(TownProp.Kind.PINE, p, {
				"size": Vector3(1.0, _rng.randf_range(5.0, 9.0), 1.0),
				"leaf_tint": SNOW_TINT,
				"wood_item": &"item.birch_log",
			})
		else:
			_billboard(TEX_ROCK, p, _rng.randf_range(0.6, 1.6) * 1.08, 0.0)

	# Marsh: reeds, snags, and a little standing water.
	for i in 64:
		var p := Vector2(_rng.randf_range(-170.0, 170.0), _rng.randf_range(190.0, 505.0))
		if not _is_open(p):
			continue
		var roll := _rng.randf()
		if roll < 0.55:
			_reed_points.append(p)
		elif roll < 0.8:
			_prop(TownProp.Kind.DEAD_TREE, p, {"size": Vector3(1.0, _rng.randf_range(2.4, 4.0), 1.0)})
		else:
			_billboard(TEX_MUSHROOM, p, 0.42, 0.3)

	for i in 7:
		var at := Vector2(_rng.randf_range(-140.0, 140.0), _rng.randf_range(230.0, 470.0))
		var radius := _rng.randf_range(5.0, 13.0)
		TownParts.cylinder(self, "BogWater", Vector3(at.x, 0.045, at.y), radius, radius, 0.04, _water(Color(0.16, 0.24, 0.22, 0.7)), Vector3.ZERO, 22)
		_clear.append(Vector3(at.x, radius + 1.0, at.y))


# --- props -----------------------------------------------------------------


## Queues one upright billboard for the batched ground-cover pass. `spread` is
## the radius of a small random offset, so a mushroom ring reads as a cluster.
func _billboard(texture: Texture2D, at: Vector2, height: float, spread: float) -> void:
	var angle := _rng.randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * _rng.randf_range(0.0, spread)
	_ground_art.append({
		"texture": texture,
		"x": at.x + offset.x,
		"z": at.y + offset.y,
		"height": height,
	})


## One MultiMesh per texture, so every mushroom, flower, fern, stump, and rock
## in the realm costs five draw calls instead of hundreds.
func _batch_ground_art() -> void:
	if _ground_art.is_empty():
		return

	var groups: Dictionary = {}
	for entry in _ground_art:
		var key := str(entry["texture"].resource_path)
		if not groups.has(key):
			groups[key] = {"texture": entry["texture"], "items": []}
		(groups[key]["items"] as Array).append(entry)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var index := 0
	for key in groups:
		var group: Dictionary = groups[key]
		var texture: Texture2D = group["texture"]
		var items: Array = group["items"]
		var aspect := float(texture.get_width()) / float(maxi(texture.get_height(), 1))

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.42
		# Same reason as the far trees: a MultiMesh ignores billboard mode, so a
		# single quad reads as a page of art from the wrong side. Two crossed
		# quads per item still cost one draw call per texture.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = quad
		batch.instance_count = items.size() * 2
		for i in items.size():
			var entry: Dictionary = items[i]
			var height: float = entry["height"]
			var width := height * aspect
			var yaw := _rng.randf() * TAU
			var sink := height * 0.06
			var at := Vector3(entry["x"], height * 0.5 - sink, entry["z"])
			for face in 2:
				var basis := (
					Basis(Vector3.UP, yaw + float(face) * PI * 0.5)
					* Basis.from_scale(Vector3(width, height, 1.0))
				)
				batch.set_instance_transform(i * 2 + face, Transform3D(basis, at))

		var instance := MultiMeshInstance3D.new()
		instance.name = "GroundArt%d" % index
		instance.multimesh = batch
		instance.material_override = mat
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		index += 1


## Adds one `TownProp`. `extra` sets exported values *before* the prop enters
## the tree, because `TownProp` builds its geometry in `_ready()`.
func _prop(kind: int, at: Vector2, extra: Dictionary = {}) -> TownProp:
	_prop_counter += 1
	var prop: TownProp = PROP_SCRIPT.new()
	prop.name = "Realm%03d" % _prop_counter
	prop.position = Vector3(at.x, 0.0, at.y)
	prop.kind = kind
	prop.seed_value = _rng.randi_range(1, 90000)
	for key in extra:
		prop.set(key, extra[key])
	add_child(prop)
	return prop
