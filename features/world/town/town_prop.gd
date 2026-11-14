class_name TownProp
extends Node3D
## Small town dressing: trees, wells, market stalls, bridges, headstones.
##
## One scene-less prop class, chosen by `kind`, so the town scene stays a short
## list of placements instead of hundreds of hand-built nodes. Materials are
## shared through `TownParts`, so a hundred trees cost a hundred draw calls but
## only a handful of materials.

enum Kind { TREE, PINE, BUSH, WELL, STALL, BRIDGE, HEADSTONE, SIGNPOST, GARDEN_BED, BENCH, REEDS, ROCK, HAYSTACK, LANTERN, FENCE, MUSHROOM, FLOWERS, FERN, STUMP, CACTUS, DEAD_TREE }

## Pixel-art props cut from the 2D game. Each is drawn as an upright billboard so
## the town keeps the storybook look while staying a 3D space you can walk
## through. Collision stays a simple 3D shape.
const TREE_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/tree.png")
const ROCK_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/rock.png")
const FLOWER_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/flower.png")
const MUSHROOM_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/mushroom.png")
const FERN_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/fern.png")
const STUMP_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/stump.png")
## Bridge decking cut from the 2D game's river sheet.
const BRIDGE_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/wooden_bridge.png")
## Seating body instanced under a bench so E can sit the player down.
const CHAIR_SCENE: PackedScene = preload("res://features/interaction/chair.tscn")
## A tree prop hands its trunk to this scene so the same tree can also be
## chopped. The gather node drives this prop's visuals instead of drawing a
## second copy of the art.
const GATHER_SCENE: PackedScene = preload("res://features/gathering/gather_node.tscn")

@export var kind: Kind = Kind.TREE
## Meaning depends on `kind`: tree height, bridge length, stall width, and so on.
@export var size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var facing_degrees: float = 0.0
@export var seed_value: int = 0
@export var text: String = ""
@export var accent: Color = Color(0.62, 0.42, 0.24, 1)
## Tints the leaf art. `Color.WHITE` is the painted colour, so several tree
## instances can share one texture and still read as different species.
@export var leaf_tint: Color = Color.WHITE
## Trees only: the log item this species drops when chopped.
@export var wood_item: StringName = &"item.spruce_log"
## Trees only: set false for a decorative tree that cannot be harvested.
@export var choppable: bool = true
## Trees only: stable save id for the stump. Empty derives one from placement.
@export var save_id: StringName = &""

var _rng := RandomNumberGenerator.new()
var _bark: StandardMaterial3D
var _leaf: StandardMaterial3D
var _stone: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _plank: StandardMaterial3D


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(name)
	rotation.y = deg_to_rad(facing_degrees)

	_bark = TownParts.material(Color(0.3, 0.21, 0.13, 1), 0.96)
	_leaf = TownParts.material(Color(0.25, 0.36, 0.17, 1), 0.97)
	_stone = TownParts.material(Color(0.47, 0.45, 0.42, 1), 0.95)
	_wood = TownParts.material(Color(0.36, 0.24, 0.14, 1), 0.94)
	_dark = TownParts.material(Color(0.2, 0.13, 0.08, 1), 0.92)
	# A lighter tint lets the pixel-art grain read instead of sinking into shadow.
	_plank = TownParts.material(Color(0.62, 0.47, 0.31, 1), 0.94, 0.0, BRIDGE_TEXTURE, Vector3(2, 2, 1))

	match kind:
		Kind.TREE:
			_tree()
		Kind.PINE:
			_pine()
		Kind.BUSH:
			_bush()
		Kind.WELL:
			_well()
		Kind.STALL:
			_stall()
		Kind.BRIDGE:
			_bridge()
		Kind.HEADSTONE:
			_headstone()
		Kind.SIGNPOST:
			_signpost()
		Kind.GARDEN_BED:
			_garden_bed()
		Kind.BENCH:
			_bench()
		Kind.REEDS:
			_reeds()
		Kind.ROCK:
			_rock()
		Kind.HAYSTACK:
			_haystack()
		Kind.LANTERN:
			_lantern()
		Kind.FENCE:
			_fence()
		Kind.MUSHROOM:
			_mushroom()
		Kind.FLOWERS:
			_flowers()
		Kind.FERN:
			_fern()
		Kind.STUMP:
			_stump()
		Kind.CACTUS:
			_cactus()
		Kind.DEAD_TREE:
			_dead_tree()

	TownParts.merge_children(self)


# --- foliage ---------------------------------------------------------------


func _tree() -> void:
	var height: float = size.y if size.y > 0.0 else 3.4
	# One upright billboard keeps the whole tree silhouette from the 2D art.
	var sprite := _sprite(self, "TreeArt", TREE_TEXTURE, height)
	sprite.modulate = leaf_tint
	# `size.x` is the wanted width in metres. The art has its own aspect ratio,
	# so stretch only across the billboard to honour it.
	var natural := height * float(TREE_TEXTURE.get_width()) / float(maxi(TREE_TEXTURE.get_height(), 1))
	if size.x > 0.0 and natural > 0.0:
		sprite.scale.x = size.x / natural
	_hand_to_gather(height, 0.35)


func _fern() -> void:
	var height: float = size.y if size.y > 0.0 else 0.9
	var sprite := _sprite(self, "FernArt", FERN_TEXTURE, height)
	sprite.modulate = leaf_tint


func _stump() -> void:
	var height: float = size.y if size.y > 0.0 else 0.7
	_sprite(self, "StumpArt", STUMP_TEXTURE, height)
	TownParts.cylinder_collision(self, 0.32, height, Vector3(0, height * 0.5, 0))


func _cactus() -> void:
	var height: float = size.y if size.y > 0.0 else 2.6
	var skin := TownParts.material(Color(0.34, 0.48, 0.26, 1), 0.92)
	TownParts.cylinder(self, "Body", Vector3(0, height * 0.5, 0), 0.24, 0.3, height, skin, Vector3.ZERO, 8)
	TownParts.sphere(self, "Crown", Vector3(0, height, 0), 0.24, 0.3, skin)
	for side in [-1.0, 1.0]:
		var arm_y := height * (0.55 + (0.12 if side > 0.0 else 0.0))
		TownParts.cylinder(self, "Arm", Vector3(side * 0.35, arm_y, 0), 0.14, 0.16, 0.42, skin, Vector3(0, 0, deg_to_rad(side * 90.0)), 6)
		TownParts.cylinder(self, "ArmUp", Vector3(side * 0.52, arm_y + 0.3, 0), 0.14, 0.14, 0.5, skin, Vector3.ZERO, 6)
	TownParts.cylinder_collision(self, 0.4, height, Vector3(0, height * 0.5, 0))


func _dead_tree() -> void:
	var height: float = size.y if size.y > 0.0 else 5.0
	var bark := TownParts.material(Color(0.33, 0.28, 0.24, 1), 0.96)
	TownParts.cylinder(self, "Trunk", Vector3(0, height * 0.5, 0), 0.1, 0.28, height, bark, Vector3.ZERO, 7)
	for i in 4:
		var angle := TAU * i / 4.0 + _rng.randf_range(-0.5, 0.5)
		var at := Vector3(cos(angle) * 0.14, height * (0.52 + i * 0.1), sin(angle) * 0.14)
		var branch := TownParts.cylinder(self, "Branch%d" % i, at, 0.04, 0.09, height * 0.36, bark, Vector3.ZERO, 5)
		branch.rotation = Vector3(deg_to_rad(42.0), angle, 0.0)
	# Deadfall is already seasoned, so it gives the old generic wood rather than
	# a named species log.
	_hand_to_gather(height, 0.3, &"item.wood")


func _pine() -> void:
	var height: float = size.y if size.y > 0.0 else 5.0
	TownParts.cylinder(self, "Trunk", Vector3(0, height * 0.3, 0), 0.16, 0.24, height * 0.6, _bark)
	for i in 3:
		var at := Vector3(0, height * (0.42 + i * 0.2), 0)
		TownParts.cone(self, "Tier%d" % i, at, height * (0.3 - i * 0.06), height * 0.42, _leaf, 7)
	_hand_to_gather(height, 0.3)


## Gives the trunk to a `GatherNode` so the same tree is scenery, an obstacle,
## and a source of logs. `proxy_visual` lets the gather node tip this whole prop
## over and hide its art while leaving the stump behind.
func _hand_to_gather(height: float, radius: float, drop_override: StringName = &"") -> void:
	if not choppable or not is_inside_tree():
		TownParts.cylinder_collision(self, radius, height, Vector3(0, height * 0.5, 0))
		return

	var gather := GATHER_SCENE.instantiate() as GatherNode
	gather.name = "Choppable"
	gather.proxy_visual = self
	gather.save_id = save_id if not save_id.is_empty() else _derived_save_id()
	gather.kind = GatherNode.Kind.TREE
	gather.drop_item = drop_override if not drop_override.is_empty() else wood_item
	gather.drop_amount = 2
	gather.hits_required = 3
	gather.regrow_days = 6
	gather.collision_radius = radius
	gather.collision_height = clampf(height * 0.4, 1.2, 2.4)
	gather.verb = "Chop"
	gather.missing_tool_hint = "You need an axe for this"
	gather.depleted_message = "Timber! The stump will regrow"
	add_child(gather)


## A placement-derived id keeps the stump's save state stable without relying on
## engine-generated node names.
func _derived_save_id() -> StringName:
	var at := global_position
	return StringName("gather.tree.%d_%d" % [roundi(at.x * 10.0), roundi(at.z * 10.0)])


func _bush() -> void:
	var radius: float = size.x if size.x > 0.0 else 0.7
	TownParts.sphere(self, "LeafA", Vector3(0, radius * 0.7, 0), radius, radius * 1.2, _leaf)
	TownParts.sphere(self, "LeafB", Vector3(radius * 0.7, radius * 0.55, radius * 0.2), radius * 0.7, radius, _leaf)
	if _rng.randf() < 0.5:
		TownParts.sphere(self, "Berry", Vector3(-radius * 0.4, radius * 0.9, -radius * 0.3), radius * 0.16, radius * 0.32, TownParts.material(Color(0.66, 0.22, 0.26, 1), 0.8))


func _reeds() -> void:
	var count := 5
	for i in count:
		var angle := TAU * i / float(count) + _rng.randf_range(-0.3, 0.3)
		var at := Vector3(cos(angle) * 0.35, 0.55, sin(angle) * 0.35)
		TownParts.cylinder(self, "Reed%d" % i, at, 0.04, 0.07, 1.1 + _rng.randf_range(-0.2, 0.3), _leaf)


func _haystack() -> void:
	TownParts.cylinder(self, "Stack", Vector3(0, 0.8, 0), 0.9, 1.2, 1.6, TownParts.material(Color(0.72, 0.6, 0.3, 1), 1.0))
	TownParts.cone(self, "Top", Vector3(0, 1.9, 0), 1.05, 0.8, TownParts.material(Color(0.66, 0.54, 0.26, 1), 1.0))
	TownParts.cylinder_collision(self, 1.1, 2.2, Vector3(0, 1.1, 0))


# --- town furniture --------------------------------------------------------


func _well() -> void:
	var radius: float = size.x if size.x > 0.0 else 1.1
	TownParts.cylinder(self, "Ring", Vector3(0, 0.45, 0), radius, radius * 1.06, 0.9, _stone, Vector3.ZERO, 12)
	TownParts.cylinder(self, "Water", Vector3(0, 0.86, 0), radius * 0.82, radius * 0.82, 0.06, TownParts.material(Color(0.1, 0.18, 0.22, 1), 0.2))
	for side in [-1.0, 1.0]:
		TownParts.box(self, "Post", Vector3(side * radius * 0.85, 1.6, 0), Vector3(0.16, 1.6, 0.16), _wood)
	TownParts.prism(self, "Roof", Vector3(0, 2.55, 0), Vector3(radius * 2.4, 0.7, radius * 1.4), _wood)
	TownParts.cylinder(self, "Bucket", Vector3(radius * 0.4, 1.2, 0), 0.16, 0.14, 0.28, _wood)
	TownParts.cylinder_collision(self, radius * 1.1, 1.0, Vector3(0, 0.5, 0))


func _stall() -> void:
	var width: float = size.x if size.x > 0.0 else 2.8
	var depth: float = size.z if size.z > 0.0 else 1.8
	var height := 2.2

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "Post", Vector3(sx * width * 0.45, height * 0.5, sz * depth * 0.4), Vector3(0.14, height, 0.14), _wood)

	TownParts.box(self, "Counter", Vector3(0, 0.85, depth * 0.15), Vector3(width, 0.12, depth * 0.5), _wood)
	TownParts.box(self, "CounterCloth", Vector3(0, 0.93, depth * 0.15), Vector3(width * 0.96, 0.04, depth * 0.46), TownParts.material(accent, 0.9))

	# Striped awning: alternating panels tilted towards the street.
	var panels := 5
	for i in panels:
		var panel_width := width / float(panels)
		var x := -width * 0.5 + panel_width * (i + 0.5)
		var colour := accent if i % 2 == 0 else Color(0.92, 0.88, 0.74, 1)
		var panel := TownParts.box(
			self, "Awning%d" % i,
			Vector3(x, height + 0.22, -depth * 0.12),
			Vector3(panel_width * 0.96, 0.1, depth * 1.15),
			TownParts.material(colour, 0.9)
		)
		panel.rotation.x = deg_to_rad(14.0)

	TownParts.box(self, "Goods", Vector3(-width * 0.25, 1.0, depth * 0.15), Vector3(0.5, 0.3, 0.5), TownParts.material(Color(0.7, 0.45, 0.2, 1), 0.9))
	TownParts.box(self, "GoodsB", Vector3(width * 0.2, 1.0, depth * 0.15), Vector3(0.4, 0.26, 0.4), TownParts.material(Color(0.42, 0.5, 0.3, 1), 0.9))
	TownParts.collision(self, Vector3(width, height, depth * 0.5), Vector3(0, height * 0.5, depth * 0.15))


func _bridge() -> void:
	var width: float = size.x if size.x > 0.0 else 3.0
	var length: float = size.z if size.z > 0.0 else 9.0
	var deck_y := 0.28

	# Planks across the span, laid along x so the grain runs with the deck.
	for i in int(length / 0.55):
		TownParts.box(
			self, "Plank%d" % i,
			Vector3(0, deck_y, -length * 0.5 + 0.28 + i * 0.55),
			Vector3(width, 0.12, 0.48), _plank
		)
	TownParts.box(self, "StringerA", Vector3(-width * 0.36, deck_y - 0.12, 0), Vector3(0.16, 0.2, length), _dark)
	TownParts.box(self, "StringerB", Vector3(width * 0.36, deck_y - 0.12, 0), Vector3(0.16, 0.2, length), _dark)
	TownParts.collision(self, Vector3(width, 0.24, length), Vector3(0, deck_y - 0.06, 0))

	for side in [-1.0, 1.0]:
		for i in int(length / 2.2) + 1:
			var z: float = -length * 0.5 + i * 2.2
			TownParts.box(self, "Post", Vector3(side * width * 0.46, deck_y + 0.5, z), Vector3(0.12, 1.0, 0.12), _dark)
		TownParts.box(self, "Rail", Vector3(side * width * 0.46, deck_y + 0.95, 0), Vector3(0.1, 0.12, length), _plank)


func _headstone() -> void:
	var height: float = size.y if size.y > 0.0 else 0.9
	var leaning := _rng.randf_range(-0.12, 0.12)
	if _rng.randf() < 0.35:
		var stone := TownParts.cylinder(self, "Stone", Vector3(0, height * 0.5, 0), height * 0.28, height * 0.3, height, _stone, Vector3.ZERO, 8)
		stone.rotation.z = leaning
	else:
		var slab := TownParts.box(self, "Stone", Vector3(0, height * 0.5, 0), Vector3(height * 0.62, height, 0.16), _stone)
		slab.rotation.z = leaning


func _signpost() -> void:
	var board_width: float = size.x if size.x > 0.0 else 1.5
	var board_height: float = size.y if size.y > 0.0 else 0.5
	TownParts.box(self, "Post", Vector3(0, 1.3, 0), Vector3(0.14, 2.6, 0.14), _wood)
	var board := TownParts.box(
		self, "Board", Vector3(0, 2.1, 0), Vector3(board_width, board_height, 0.1), _wood
	)
	board.rotation.y = deg_to_rad(_rng.randf_range(-6.0, 6.0))
	if not text.is_empty():
		var label := Label3D.new()
		label.name = "Text"
		label.text = text
		label.position = Vector3(0, 2.1, 0.09)
		label.font_size = 44 if board_height > 0.6 else 48
		label.pixel_size = 0.0032 if board_height > 0.6 else 0.0035
		label.outline_size = 14
		label.modulate = Color(0.98, 0.94, 0.84, 1)
		label.outline_modulate = Color(0.14, 0.1, 0.06, 1)
		add_child(label)
	TownParts.collision(self, Vector3(0.3, 2.6, 0.3), Vector3(0, 1.3, 0))


func _garden_bed() -> void:
	var width: float = size.x if size.x > 0.0 else 2.4
	var depth: float = size.z if size.z > 0.0 else 1.2
	TownParts.box(self, "Soil", Vector3(0, 0.12, 0), Vector3(width, 0.24, depth), TownParts.material(Color(0.28, 0.2, 0.13, 1), 1.0))
	TownParts.box(self, "BorderA", Vector3(0, 0.14, -depth * 0.5), Vector3(width, 0.18, 0.1), _wood)
	TownParts.box(self, "BorderB", Vector3(0, 0.14, depth * 0.5), Vector3(width, 0.18, 0.1), _wood)

	var crops := int(width / 0.45)
	for i in crops:
		var x := -width * 0.5 + 0.25 + i * 0.45
		TownParts.sphere(self, "Crop%d" % i, Vector3(x, 0.35, 0), 0.16, 0.3, TownParts.material(Color(0.34, 0.5, 0.24, 1), 0.95))
		TownParts.sphere(self, "CropB%d" % i, Vector3(x, 0.35, depth * 0.32), 0.14, 0.26, TownParts.material(Color(0.44, 0.56, 0.26, 1), 0.95))


func _bench() -> void:
	TownParts.box(self, "Seat", Vector3(0, 0.45, 0), Vector3(1.8, 0.12, 0.5), _wood)
	TownParts.box(self, "Back", Vector3(0, 0.75, 0.22), Vector3(1.8, 0.5, 0.1), _wood)
	for side in [-1.0, 1.0]:
		TownParts.box(self, "Leg", Vector3(side * 0.75, 0.22, 0), Vector3(0.12, 0.44, 0.44), _dark)

	# The bench mesh is scenery; this invisible body is what E finds. It faces
	# away from the backrest, and sitting is handled entirely by the player.
	var seat := CHAIR_SCENE.instantiate() as StaticBody3D
	seat.name = "Chair"
	seat.position = Vector3(0, 0, 0)
	seat.rotation.y = PI
	add_child(seat)


func _rock() -> void:
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	# Match the billboard's width to the old block's footprint. The rock art is
	# 83 wide by 90 tall, so a small extra height keeps it about `scale_i` wide.
	var art_height := scale_i * 1.08
	_sprite(self, "RockArt", ROCK_TEXTURE, art_height)
	TownParts.collision(self, Vector3(scale_i, scale_i * 0.8, scale_i * 0.8), Vector3(0, scale_i * 0.35, 0))


func _lantern() -> void:
	TownParts.box(self, "Post", Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 0.12), _dark)
	TownParts.box(self, "Arm", Vector3(0.25, 2.15, 0), Vector3(0.5, 0.08, 0.08), _dark)
	TownParts.box(self, "Lantern", Vector3(0.45, 2.0, 0), Vector3(0.24, 0.3, 0.24), TownParts.material(Color(1, 0.78, 0.42, 1), 0.5, 2.4))
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position = Vector3(0.45, 2.0, 0)
	light.light_color = Color(1, 0.74, 0.42, 1)
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)


func _fence() -> void:
	var length: float = size.x if size.x > 0.0 else 4.0
	for side in [-1.0, 1.0]:
		TownParts.box(self, "Rail", Vector3(0, 0.75 + side * 0.12, 0), Vector3(length, 0.1, 0.08), _wood)
	for i in int(length / 1.6) + 1:
		var x: float = -length * 0.5 + i * 1.6
		TownParts.box(self, "Post", Vector3(x, 0.45, 0), Vector3(0.12, 0.9, 0.12), _wood)


func _mushroom() -> void:
	# A little cluster of the Hollow's signature growth, now drawn from the 2D
	# art so the caps keep their painted colour and glow.
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	for i in 3:
		var angle := TAU * i / 3.0 + _rng.randf_range(-0.4, 0.4)
		var distance := _rng.randf_range(0.05, 0.35) * scale_i
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var height := _rng.randf_range(0.3, 0.5) * scale_i
		_sprite(self, "MushroomArt%d" % i, MUSHROOM_TEXTURE, height, at)


func _flowers() -> void:
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	for i in 6:
		var angle := TAU * i / 6.0 + _rng.randf_range(-0.5, 0.5)
		var distance := sqrt(_rng.randf()) * 0.5 * scale_i
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var height := _rng.randf_range(0.3, 0.5) * scale_i
		_sprite(self, "FlowerArt%d" % i, FLOWER_TEXTURE, height, at)


## An upright camera-facing billboard. `height` is the world height in metres;
## the pixel size is derived from the texture so the art keeps its proportions.
func _sprite(
	parent: Node3D,
	node_name: String,
	texture: Texture2D,
	height: float,
	at: Vector3 = Vector3.ZERO
) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	# FIXED_Y billboards turn to face the camera only around the vertical axis,
	# so a tree stays upright instead of tilting back when you look up at it.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = height / float(maxi(texture.get_height(), 1))
	sprite.position = at + Vector3(0, height * 0.5, 0)
	parent.add_child(sprite)
	return sprite
