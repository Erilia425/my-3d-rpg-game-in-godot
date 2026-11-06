class_name TownProp
extends Node3D
## Small town dressing: trees, wells, market stalls, bridges, headstones.
##
## One scene-less prop class, chosen by `kind`, so the town scene stays a short
## list of placements instead of hundreds of hand-built nodes. Materials are
## shared through `TownParts`, so a hundred trees cost a hundred draw calls but
## only a handful of materials.

enum Kind { TREE, PINE, BUSH, WELL, STALL, BRIDGE, HEADSTONE, SIGNPOST, GARDEN_BED, BENCH, REEDS, ROCK, HAYSTACK, LANTERN, FENCE, MUSHROOM, FLOWERS }

@export var kind: Kind = Kind.TREE
## Meaning depends on `kind`: tree height, bridge length, stall width, and so on.
@export var size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var facing_degrees: float = 0.0
@export var seed_value: int = 0
@export var text: String = ""
@export var accent: Color = Color(0.62, 0.42, 0.24, 1)

var _rng := RandomNumberGenerator.new()
var _bark: StandardMaterial3D
var _leaf: StandardMaterial3D
var _stone: StandardMaterial3D
var _wood: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(name)
	rotation.y = deg_to_rad(facing_degrees)

	_bark = TownParts.material(Color(0.3, 0.21, 0.13, 1), 0.96)
	_leaf = TownParts.material(Color(0.25, 0.36, 0.17, 1), 0.97)
	_stone = TownParts.material(Color(0.47, 0.45, 0.42, 1), 0.95)
	_wood = TownParts.material(Color(0.36, 0.24, 0.14, 1), 0.94)
	_dark = TownParts.material(Color(0.2, 0.13, 0.08, 1), 0.92)

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

	TownParts.merge_children(self)


# --- foliage ---------------------------------------------------------------


func _tree() -> void:
	var height: float = size.y if size.y > 0.0 else 3.4
	var radius: float = size.x if size.x > 0.0 else 1.7
	TownParts.cylinder(self, "Trunk", Vector3(0, height * 0.5, 0), 0.18, 0.3, height, _bark)
	TownParts.sphere(self, "Canopy", Vector3(0, height * 0.95, 0), radius, radius * 1.5, _leaf)
	TownParts.sphere(self, "CanopyLow", Vector3(radius * 0.5, height * 0.72, radius * 0.3), radius * 0.62, radius, _leaf)
	TownParts.sphere(self, "CanopyHigh", Vector3(-radius * 0.45, height * 1.06, -radius * 0.25), radius * 0.55, radius * 0.9, _leaf)
	TownParts.cylinder_collision(self, 0.35, height, Vector3(0, height * 0.5, 0))


func _pine() -> void:
	var height: float = size.y if size.y > 0.0 else 5.0
	TownParts.cylinder(self, "Trunk", Vector3(0, height * 0.3, 0), 0.16, 0.24, height * 0.6, _bark)
	for i in 3:
		var at := Vector3(0, height * (0.42 + i * 0.2), 0)
		TownParts.cone(self, "Tier%d" % i, at, height * (0.3 - i * 0.06), height * 0.42, _leaf, 7)
	TownParts.cylinder_collision(self, 0.3, height, Vector3(0, height * 0.5, 0))


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
			Vector3(width, 0.12, 0.48), _wood
		)
	TownParts.box(self, "StringerA", Vector3(-width * 0.36, deck_y - 0.12, 0), Vector3(0.16, 0.2, length), _dark)
	TownParts.box(self, "StringerB", Vector3(width * 0.36, deck_y - 0.12, 0), Vector3(0.16, 0.2, length), _dark)
	TownParts.collision(self, Vector3(width, 0.24, length), Vector3(0, deck_y - 0.06, 0))

	for side in [-1.0, 1.0]:
		for i in int(length / 2.2) + 1:
			var z: float = -length * 0.5 + i * 2.2
			TownParts.box(self, "Post", Vector3(side * width * 0.46, deck_y + 0.5, z), Vector3(0.12, 1.0, 0.12), _dark)
		TownParts.box(self, "Rail", Vector3(side * width * 0.46, deck_y + 0.95, 0), Vector3(0.1, 0.12, length), _wood)


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
	TownParts.box(self, "Post", Vector3(0, 1.3, 0), Vector3(0.14, 2.6, 0.14), _wood)
	var board := TownParts.box(self, "Board", Vector3(0, 2.1, 0), Vector3(1.5, 0.5, 0.1), _wood)
	board.rotation.y = deg_to_rad(_rng.randf_range(-6.0, 6.0))
	if not text.is_empty():
		var label := Label3D.new()
		label.name = "Text"
		label.text = text
		label.position = Vector3(0, 2.1, 0.09)
		label.font_size = 48
		label.pixel_size = 0.0035
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


func _rock() -> void:
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	var body := TownParts.box(self, "Rock", Vector3(0, scale_i * 0.35, 0), Vector3(scale_i, scale_i * 0.8, scale_i * 0.8), _stone)
	body.rotation.y = _rng.randf() * TAU
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
	# A little cluster of faintly glowing caps — the Hollow's signature growth.
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	# Pale mint caps with a gentle glow: enough to catch the eye at dusk without
	# blowing out to white in daylight.
	var glow := TownParts.material(Color(0.74, 0.9, 0.78, 1), 0.55, 0.55)
	var stalk := TownParts.material(Color(0.9, 0.88, 0.8, 1), 0.95)

	for i in 4:
		var angle := TAU * i / 4.0 + _rng.randf_range(-0.4, 0.4)
		var distance := _rng.randf_range(0.05, 0.4) * scale_i
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var height := _rng.randf_range(0.16, 0.34) * scale_i
		var cap := _rng.randf_range(0.12, 0.22) * scale_i
		TownParts.cylinder(self, "Stalk%d" % i, at + Vector3(0, height * 0.5, 0), 0.03 * scale_i, 0.05 * scale_i, height, stalk)
		TownParts.sphere(self, "Cap%d" % i, at + Vector3(0, height, 0), cap, cap * 0.8, glow)


func _flowers() -> void:
	var scale_i: float = size.x if size.x > 0.0 else 1.0
	var petal := TownParts.material(accent, 0.85)
	var centre := TownParts.material(Color(0.96, 0.82, 0.4, 1), 0.8)
	var stem := TownParts.material(Color(0.3, 0.42, 0.22, 1), 0.95)

	for i in 6:
		var angle := TAU * i / 6.0 + _rng.randf_range(-0.5, 0.5)
		var distance := sqrt(_rng.randf()) * 0.5 * scale_i
		var at := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var height := _rng.randf_range(0.22, 0.42) * scale_i
		TownParts.cylinder(self, "Stem%d" % i, at + Vector3(0, height * 0.5, 0), 0.018, 0.022, height, stem)
		TownParts.sphere(self, "Petal%d" % i, at + Vector3(0, height, 0), 0.075 * scale_i, 0.05 * scale_i, petal)
		TownParts.sphere(self, "Heart%d" % i, at + Vector3(0, height + 0.03 * scale_i, 0), 0.03 * scale_i, 0.025 * scale_i, centre)
