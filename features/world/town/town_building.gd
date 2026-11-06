class_name TownBuilding
extends Node3D
## One cottagecore building, assembled from primitives at `_ready()`.
##
## Styles share the same shape language from the Mycelgrove Hollow map: stone
## footing, wattle-and-daub walls, a heavy thatched gable, a chimney, small
## irregular windows, and moss at the base. Rooms are not enterable; the only
## door that leads anywhere is the starting cottage, whose gate lives in
## `scenes/town.tscn`.
##
## Serving suggestion: keep the geometry "grown, not built" — a couple of
## degrees of lean and uneven eaves read as cottagecore far better than a perfect
## box. See AGENTS.md 4.5 and section 7.

enum Style { COTTAGE, LONGHOUSE, CHAPEL, STONE_TOWER, HIVE_TOWER, RUIN }

@export var style: Style = Style.COTTAGE
## Width (x) and depth (z) in metres.
@export var footprint: Vector2 = Vector2(6.0, 5.0)
@export var wall_height: float = 3.0
@export var roof_height: float = 2.0
@export var wall_color: Color = Color(0.74, 0.68, 0.54, 1)
@export var roof_color: Color = Color(0.36, 0.29, 0.17, 1)
@export var stone_color: Color = Color(0.45, 0.43, 0.4, 1)
@export var facing_degrees: float = 0.0
@export var has_chimney: bool = true
@export var door_offset: float = 0.0
@export var label: String = ""
@export var ruined: bool = false
@export var seed_value: int = 0

const BASE := 0.55

var _rng := RandomNumberGenerator.new()
var _timber: StandardMaterial3D
var _dark: StandardMaterial3D
var _moss: StandardMaterial3D
var _glass: StandardMaterial3D
var _stone: StandardMaterial3D
var _wall: StandardMaterial3D
var _roof: StandardMaterial3D


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(name)
	rotation.y = deg_to_rad(facing_degrees)

	_timber = TownParts.material(Color(0.27, 0.17, 0.1, 1), 0.95)
	_dark = TownParts.material(Color(0.18, 0.12, 0.08, 1), 0.9)
	_moss = TownParts.material(Color(0.24, 0.34, 0.16, 1), 0.98)
	_glass = TownParts.material(Color(1, 0.76, 0.4, 1), 0.6, 1.6)
	_stone = TownParts.material(stone_color, 0.95)
	_wall = TownParts.material(wall_color, 0.97)
	_roof = TownParts.material(roof_color, 0.99)

	match style:
		Style.COTTAGE:
			_cottage()
		Style.LONGHOUSE:
			_longhouse()
		Style.CHAPEL:
			_chapel()
		Style.STONE_TOWER:
			_stone_tower()
		Style.HIVE_TOWER:
			_hive_tower()
		Style.RUIN:
			_ruin()

	TownParts.merge_children(self)

	if not label.is_empty():
		_add_label()


# --- styles ----------------------------------------------------------------


func _cottage() -> void:
	var fx := footprint.x
	var fz := footprint.y
	var wall_top := BASE + wall_height

	_footing(fx, fz, 0.7)
	_leaning_box("Walls", Vector3(0, BASE + wall_height * 0.5, 0), Vector3(fx, wall_height, fz), _wall, 0.02)
	_corner_posts(fx, fz, wall_top)
	_eave(fx, fz, wall_top)
	_gable_roof(fx, fz, wall_top, 1.1)
	_base_moss(fx, fz)

	_door(fx, fz)
	_front_windows(fx, fz)
	if has_chimney:
		_chimney(fx, fz, wall_top)

	TownParts.collision(self, Vector3(fx, wall_top, fz), Vector3(0, wall_top * 0.5, 0))


func _longhouse() -> void:
	_cottage()
	# A lower lean-to on one flank makes the long row read as built up over time.
	var fx := footprint.x
	var annex := Vector3(2.6, 2.4, footprint.y * 0.55)
	var annex_x := fx * 0.5 + annex.x * 0.5 - 0.1
	TownParts.box(self, "Annex", Vector3(annex_x, BASE + annex.y * 0.5, footprint.y * 0.22), annex, _wall)
	TownParts.prism(
		self, "AnnexRoof",
		Vector3(annex_x, BASE + annex.y + 0.7, footprint.y * 0.22),
		Vector3(annex.x + 0.6, 1.4, annex.z + 0.6), _roof
	)
	TownParts.box(self, "AnnexPost", Vector3(annex_x + annex.x * 0.4, BASE + 1.2, footprint.y * 0.22 + annex.z * 0.45), Vector3(0.2, 2.4, 0.2), _timber)


func _chapel() -> void:
	var fx := footprint.x
	var fz := footprint.y
	var wall_top := BASE + wall_height

	_footing(fx, fz, 0.6)
	_leaning_box("Walls", Vector3(0, BASE + wall_height * 0.5, 0), Vector3(fx, wall_height, fz), _wall, 0.0)
	_corner_posts(fx, fz, wall_top)
	_eave(fx, fz, wall_top)
	_gable_roof(fx, fz, wall_top, 0.8)

	# Bell porch and spire on the front face.
	TownParts.box(self, "Porch", Vector3(0, BASE + 1.8, -fz * 0.5 - 1.0), Vector3(2.8, 3.6, 2.0), _wall)
	TownParts.prism(self, "PorchRoof", Vector3(0, BASE + 4.3, -fz * 0.5 - 1.0), Vector3(3.4, 1.5, 2.6), _roof)
	TownParts.box(self, "SpireBase", Vector3(0, BASE + 4.4, -fz * 0.32), Vector3(1.5, 2.4, 1.5), _timber)
	TownParts.cone(self, "Spire", Vector3(0, BASE + 6.7, -fz * 0.32), 1.3, 2.6, _roof, 6)

	_door(fx, fz, 1.6, 2.4, 0.0, -fz * 0.5 - 2.0)
	for side in [-1.0, 1.0]:
		for i in 2:
			var x: float = side * fx * (0.22 + 0.24 * i)
			TownParts.box(self, "TallowFrame", Vector3(x, BASE + 2.4, -fz * 0.5 - 0.08), Vector3(0.8, 1.8, 0.08), _dark)
			TownParts.box(self, "TallowWindow", Vector3(x, BASE + 2.4, -fz * 0.5 - 0.15), Vector3(0.6, 1.6, 0.1), _glass)

	TownParts.collision(self, Vector3(fx, wall_top, fz), Vector3(0, wall_top * 0.5, 0))


func _stone_tower() -> void:
	var radius := footprint.x * 0.5
	var base_height := wall_height * 0.62
	var upper_height := wall_height * 0.5

	TownParts.cylinder(self, "Base", Vector3(0, BASE + base_height * 0.5, 0), radius, radius * 1.08, base_height, _stone, Vector3.ZERO, 12)
	TownParts.cylinder(self, "Band", Vector3(0, BASE + base_height, 0), radius * 1.02, radius * 1.02, 0.4, _timber, Vector3.ZERO, 12)
	TownParts.cylinder(
		self, "Upper",
		Vector3(0, BASE + base_height + upper_height * 0.5, 0),
		radius * 0.86, radius * 0.94, upper_height, _timber, Vector3.ZERO, 12
	)

	if ruined:
		_leaning_box("BrokenTop", Vector3(0.2, BASE + base_height + upper_height + 0.5, 0), Vector3(radius * 1.2, 1.2, radius * 0.6), _stone, 0.12)
		TownParts.box(self, "Rubble", Vector3(radius * 1.4, 0.25, radius * 0.8), Vector3(1.4, 0.5, 1.1), _stone)
	else:
		TownParts.cone(self, "Roof", Vector3(0, BASE + base_height + upper_height + 1.3, 0), radius * 1.2, 2.6, _roof, 12)

	for i in 5:
		var angle := TAU * i / 5.0
		var at := Vector3(sin(angle) * radius * 0.95, BASE + base_height * 0.62, cos(angle) * radius * 0.95)
		TownParts.box(self, "ArrowSlit", at, Vector3(0.16, 0.9, 0.35), _dark)

	TownParts.box(self, "TowerDoor", Vector3(0, BASE + 1.1, -radius * 1.02), Vector3(1.2, 2.2, 0.18), _timber)
	TownParts.cylinder_collision(self, radius * 1.05, BASE + base_height + upper_height, Vector3(0, (BASE + base_height + upper_height) * 0.5, 0))


func _hive_tower() -> void:
	var radius := footprint.x * 0.5
	var y := BASE
	var honey := Color(0.78, 0.62, 0.26, 1)

	for i in 4:
		var section := wall_height * 0.32
		var section_radius := radius * (1.0 - i * 0.12)
		TownParts.cylinder(
			self, "HiveSection%d" % i,
			Vector3(0, y + section * 0.5, 0),
			section_radius, section_radius * 1.04, section,
			TownParts.material(honey.darkened(i * 0.06), 0.95),
			Vector3.ZERO, 6
		)
		TownParts.cylinder(
			self, "HiveBand%d" % i,
			Vector3(0, y + section, 0),
			section_radius * 1.05, section_radius * 1.05, 0.18,
			_timber, Vector3.ZERO, 6
		)
		y += section + 0.18

	TownParts.cone(self, "HiveRoof", Vector3(0, y + 1.4, 0), radius * 0.9, 2.8, _roof, 6)
	TownParts.box(self, "HiveDoor", Vector3(0, BASE + 1.1, -radius * 0.98), Vector3(1.1, 2.2, 0.2), _timber)

	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		TownParts.box(
			self, "CombWindow%d" % i,
			Vector3(sin(angle) * radius * 0.92, BASE + wall_height * 0.45, cos(angle) * radius * 0.92),
			Vector3(0.3, 0.5, 0.3), _glass
		)

	TownParts.cylinder_collision(self, radius * 1.02, y + 2.0, Vector3(0, (y + 2.0) * 0.5, 0))


func _ruin() -> void:
	var fx := footprint.x
	var fz := footprint.y

	TownParts.box(self, "Footing", Vector3(0, 0.2, 0), Vector3(fx, 0.4, fz), _stone)
	for i in 3:
		var broken_height := _rng.randf_range(1.2, 3.0)
		var wall_width := _rng.randf_range(1.6, 3.2)
		var at := Vector3(
			_rng.randf_range(-fx * 0.35, fx * 0.35), 0.4 + broken_height * 0.5,
			_rng.randf_range(-fz * 0.35, fz * 0.35)
		)
		var wall := TownParts.box(self, "BrokenWall%d" % i, at, Vector3(wall_width, broken_height, 0.45), _wall)
		wall.rotation = Vector3(0, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.12, 0.12))
		TownParts.collision(self, Vector3(wall_width, broken_height, 0.5), at)

	for i in 4:
		var rubble := TownParts.box(
			self, "Rubble%d" % i,
			Vector3(_rng.randf_range(-fx * 0.5, fx * 0.5), 0.2, _rng.randf_range(-fz * 0.5, fz * 0.5)),
			Vector3(_rng.randf_range(0.5, 1.1), _rng.randf_range(0.3, 0.6), _rng.randf_range(0.5, 1.0)),
			_stone
		)
		rubble.rotation.y = _rng.randf() * TAU

	for i in 3:
		TownParts.box(
			self, "Weed%d" % i,
			Vector3(_rng.randf_range(-fx * 0.45, fx * 0.45), 0.35, _rng.randf_range(-fz * 0.45, fz * 0.45)),
			Vector3(0.7, 0.7, 0.7), _moss
		)


# --- shared pieces ---------------------------------------------------------


func _footing(fx: float, fz: float, margin: float) -> void:
	TownParts.box(self, "Footing", Vector3(0, BASE * 0.5, 0), Vector3(fx + margin, BASE, fz + margin), _stone)
	# Field stones wedged along the base, a little uneven on purpose.
	for i in 4:
		var at := Vector3((i - 1.5) * fx * 0.22, 0.18, -fz * 0.5 - 0.1)
		var stone := TownParts.box(
			self, "FieldStone%d" % i, at,
			Vector3(_rng.randf_range(0.4, 0.8), _rng.randf_range(0.25, 0.4), 0.35), _stone
		)
		stone.rotation.z = _rng.randf_range(-0.15, 0.15)


func _corner_posts(fx: float, fz: float, wall_top: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(
				self, "Post", Vector3(sx * fx * 0.5, BASE + wall_height * 0.5, sz * fz * 0.5),
				Vector3(0.3, wall_height, 0.3), _timber
			)
	TownParts.box(self, "Rail", Vector3(0, BASE + wall_height * 0.62, -fz * 0.5 - 0.02), Vector3(fx * 0.96, 0.18, 0.12), _timber)


func _eave(fx: float, fz: float, wall_top: float) -> void:
	TownParts.box(self, "Eave", Vector3(0, wall_top, 0), Vector3(fx + 0.45, 0.22, fz + 0.45), _timber)


func _gable_roof(fx: float, fz: float, wall_top: float, overhang: float) -> void:
	var size := Vector3(fx + overhang, roof_height, fz + overhang)
	var roof := TownParts.prism(self, "Thatch", Vector3(0, wall_top + roof_height * 0.5, 0), size, _roof)
	roof.rotation.y = _rng.randf_range(-0.01, 0.01)
	# PrismMesh's apex runs along Z, so the gable faces the street and the ridge
	# beam has to follow Z as well. Laid across X it speared out of the roof.
	TownParts.box(self, "Ridge", Vector3(0, wall_top + roof_height - 0.05, 0), Vector3(0.4, 0.14, fz + overhang * 0.8), _timber)
	# Moss tucked under the eave, where damp collects — not on the windows.
	TownParts.box(
		self, "WallMoss",
		Vector3(_rng.randf_range(-fx * 0.3, fx * 0.3), wall_top - 0.16, -fz * 0.5 - 0.04),
		Vector3(_rng.randf_range(0.9, 1.7), _rng.randf_range(0.18, 0.32), 0.12), _moss
	)


func _base_moss(fx: float, fz: float) -> void:
	for i in 3:
		TownParts.box(
			self, "Moss%d" % i,
			Vector3(_rng.randf_range(-fx * 0.42, fx * 0.42), BASE + 0.1, -fz * 0.5 - 0.16),
			Vector3(_rng.randf_range(0.8, 1.8), _rng.randf_range(0.2, 0.45), 0.16), _moss
		)


func _door(fx: float, fz: float, width: float = 1.1, height: float = 2.0, offset: float = 0.0, z: float = 0.0) -> void:
	var at := Vector3(door_offset + offset, BASE + height * 0.5, z if z != 0.0 else -fz * 0.5 - 0.06)
	TownParts.box(self, "Door", at, Vector3(width, height, 0.16), _timber)
	TownParts.box(self, "DoorFrameL", at + Vector3(-width * 0.5 - 0.12, 0.1, -0.02), Vector3(0.2, height + 0.24, 0.22), _dark)
	TownParts.box(self, "DoorFrameR", at + Vector3(width * 0.5 + 0.12, 0.1, -0.02), Vector3(0.2, height + 0.24, 0.22), _dark)
	TownParts.box(self, "DoorLintel", at + Vector3(0, height * 0.5 + 0.18, -0.02), Vector3(width + 0.7, 0.22, 0.24), _dark)
	# The knob must sit in front of the panel, not inside it: the door face points
	# along -z, so a positive offset would bury the knob in the wood.
	TownParts.sphere(self, "DoorKnob", at + Vector3(width * 0.32, 0, -0.12), 0.07, 0.14, _glass)


func _front_windows(fx: float, fz: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * fx * 0.31 + door_offset
		# Frame first, glass in front of it, bar in front of the glass. The other
		# order buries the glass inside the frame's solid box and the window reads
		# as a dark hole.
		TownParts.box(self, "WindowFrame", Vector3(x, BASE + wall_height * 0.62, -fz * 0.5 - 0.08), Vector3(1.0, 1.1, 0.1), _dark)
		TownParts.box(self, "Window", Vector3(x, BASE + wall_height * 0.62, -fz * 0.5 - 0.16), Vector3(0.8, 0.9, 0.1), _glass)
		TownParts.box(self, "WindowBar", Vector3(x, BASE + wall_height * 0.62, -fz * 0.5 - 0.23), Vector3(0.08, 1.1, 0.08), _dark)

	# A side window, because cottages never have just one face with glass. Frame
	# first and glass proud of it, same order as the front windows.
	TownParts.box(self, "SideWindowFrame", Vector3(fx * 0.5 + 0.03, BASE + wall_height * 0.62, 0.0), Vector3(0.12, 1.0, 1.0), _dark)
	TownParts.box(self, "SideWindow", Vector3(fx * 0.5 + 0.10, BASE + wall_height * 0.62, 0.0), Vector3(0.1, 0.8, 0.8), _glass)


func _chimney(fx: float, fz: float, wall_top: float) -> void:
	var at := Vector3(fx * 0.26, wall_top + roof_height * 0.45, fz * 0.05)
	TownParts.box(self, "Chimney", at, Vector3(0.7, roof_height + 1.7, 0.7), _stone)
	TownParts.box(self, "ChimneyCap", at + Vector3(0, (roof_height + 1.7) * 0.5, 0), Vector3(0.9, 0.18, 0.9), _stone)


func _leaning_box(node_name: String, position: Vector3, size: Vector3, mat: Material, lean: float) -> MeshInstance3D:
	var instance := TownParts.box(self, node_name, position, size, mat)
	instance.rotation = Vector3(_rng.randf_range(-lean, lean), 0.0, _rng.randf_range(-lean, lean))
	return instance


func _add_label() -> void:
	var height := BASE + wall_height + roof_height + 1.4
	if style == Style.STONE_TOWER:
		height = BASE + wall_height + 3.2
	elif style == Style.HIVE_TOWER:
		height = BASE + wall_height * 1.4 + 3.4

	var text := Label3D.new()
	text.name = "Nameboard"
	text.text = label
	text.position = Vector3(0, height, 0)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.font_size = 64
	text.pixel_size = 0.004
	text.outline_size = 20
	text.outline_modulate = Color(0.1, 0.07, 0.04, 0.9)
	text.modulate = Color(0.97, 0.92, 0.8, 1)
	text.no_depth_test = false
	add_child(text)
