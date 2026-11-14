extends Node3D
## One enterable interior, built from primitives at `_ready()`.
##
## Interiors are content, not a system: a room is a shell plus a `layout` of
## furniture, so adding a shop or a cottage means one small scene with a
## different `layout` value instead of hand-placing two hundred nodes. The shell
## owns the floor, walls, ceiling, exit door, and lights; the layout owns the
## furniture. `TownParts` is reused for the primitives and the mesh batching.
##
## The exit does not know which street it belongs to. `Game` recorded the
## doorstep when the player walked in, and `Game.exit_interior()` uses it. See
## AGENTS.md sections 4 and 7.

@export var layout: StringName = &"bakery"
## Width (x) and depth (z) in metres, measured inside the walls.
@export var room_size: Vector2 = Vector2(7.2, 5.6)
@export var wall_height: float = 2.85
## Small deterministic variation inside a layout family, so two cottages do not
## share the exact same dressing. Set by the town generator from the name.
@export var accent: int = 0

const EXIT_SCRIPT := preload("res://features/world/interiors/interior_exit.gd")
const LEDGER_BOOK := preload("res://features/interaction/ledger_book.tscn")
const CHEST := preload("res://features/interaction/chest.tscn")
const BED_SCENE := preload("res://features/interaction/bed.tscn")

## 2D furniture art from the source game, drawn as upright billboards. The pixel
## art is imported once here rather than loaded at runtime, so walking into a
## house never stalls on disk access.
const SPRITE_DESK := preload("res://assets/from_2d/sprites/desk.png")
const SPRITE_TABLE := preload("res://assets/from_2d/sprites/table.png")
const SPRITE_CHAIR := preload("res://assets/from_2d/sprites/chair.png")
const SPRITE_BED := preload("res://assets/from_2d/sprites/bed.png")
const SPRITE_SHELF := preload("res://assets/from_2d/sprites/shelf.png")
const SPRITE_FIREPLACE := preload("res://assets/from_2d/sprites/fireplace.png")
const SPRITE_LEDGER := preload("res://assets/from_2d/sprites/ledger_book.png")

## 2D floor material from the source game. The plank boards are drawn as a
## tiled texture on the 3D floor so the room reads as the same world as the
## billboard furniture.
const TEX_FLOOR := preload("res://assets/from_2d/materials/wood_planks.png")

const DOOR_WIDTH := 1.4
const DOOR_HEIGHT := 2.15
const WALL := 0.3
## Internal partition thickness. Thinner than an outside wall so a room split
## reads as a timber stud wall rather than two buildings pushed together.
const PARTITION := 0.16

var _half := Vector2.ZERO

var _plank: StandardMaterial3D
var _plaster: StandardMaterial3D
var _timber: StandardMaterial3D
var _dark: StandardMaterial3D
var _stone: StandardMaterial3D
var _glass: StandardMaterial3D
var _cloth: StandardMaterial3D
var _linen: StandardMaterial3D
var _bread: StandardMaterial3D
var _honey: StandardMaterial3D
var _moss: StandardMaterial3D


func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_half = room_size * 0.5
	_materials()
	_environment()
	_shell()

	match layout:
		&"bakery":
			_bakery()
		&"longhouse":
			_longhouse()
		&"chapel":
			_chapel()
		&"tower":
			_tower()
		&"hive":
			_hive()
		&"office":
			_office()
		&"store":
			_store()
		&"forge":
			_forge()
		&"seamstress":
			_seamstress()
		&"loom":
			_loom()
		&"abandoned":
			_abandoned()
		&"hollow_house":
			_hollow_house()
		&"rowan_manor":
			_rowan_manor()
		&"cafe":
			_bakery_cafe()
		_:
			_cottage()

	_lights()
	# One draw call per material for the whole room. Lights, the exit area, and
	# the player are separate children and survive the merge.
	TownParts.merge_children(self)
	_exit_door()


# --- shell -----------------------------------------------------------------


func _materials() -> void:
	_plank = TownParts.material(
		Color(0.55, 0.42, 0.3, 1), 0.92, 0.0, TEX_FLOOR, Vector3(3.0, 3.0, 1.0)
	)
	_plaster = TownParts.material(Color(0.74, 0.67, 0.54, 1), 0.97)
	_timber = TownParts.material(Color(0.27, 0.17, 0.1, 1), 0.95)
	_dark = TownParts.material(Color(0.17, 0.11, 0.07, 1), 0.9)
	_stone = TownParts.material(Color(0.44, 0.42, 0.39, 1), 0.95)
	_glass = TownParts.material(Color(1, 0.82, 0.5, 1), 0.55, 1.3)
	_cloth = TownParts.material(Color(0.48, 0.22, 0.18, 1), 0.98)
	_linen = TownParts.material(Color(0.72, 0.67, 0.54, 1), 0.98)
	_bread = TownParts.material(Color(0.62, 0.42, 0.2, 1), 0.9)
	_honey = TownParts.material(Color(0.78, 0.58, 0.2, 1), 0.7)
	_moss = TownParts.material(Color(0.27, 0.35, 0.2, 1), 0.98)


func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.025, 0.02, 1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.56, 0.46, 0.34, 1)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.name = "InteriorEnvironment"
	world.environment = environment
	add_child(world)


func _shell() -> void:
	var half_height := wall_height * 0.5

	# Floor and ceiling.
	TownParts.box(self, "Floor", Vector3(0, -0.15, 0), Vector3(room_size.x, 0.3, room_size.y), _plank)
	TownParts.collision(self, Vector3(room_size.x, 0.3, room_size.y), Vector3(0, -0.15, 0))
	TownParts.box(self, "Ceiling", Vector3(0, wall_height + 0.1, 0), Vector3(room_size.x + WALL, 0.2, room_size.y + WALL), _dark)

	# A few board seams so the floor is not one flat plane underfoot.
	for i in 5:
		var x := -_half.x + room_size.x * (i + 0.5) / 5.0
		TownParts.box(self, "BoardSeam%d" % i, Vector3(x, 0.005, 0), Vector3(0.04, 0.01, room_size.y), _dark)

	# Back and side walls.
	_wall("NorthWall", Vector3(0, half_height, -_half.y), Vector3(room_size.x, wall_height, WALL))
	_wall("WestWall", Vector3(-_half.x, half_height, 0), Vector3(WALL, wall_height, room_size.y))
	_wall("EastWall", Vector3(_half.x, half_height, 0), Vector3(WALL, wall_height, room_size.y))

	# Front wall split around the doorway.
	var door_half := DOOR_WIDTH * 0.5
	var side_width := _half.x - door_half
	var side_center := door_half + side_width * 0.5
	_wall("FrontWallL", Vector3(-side_center, half_height, _half.y), Vector3(side_width, wall_height, WALL))
	_wall("FrontWallR", Vector3(side_center, half_height, _half.y), Vector3(side_width, wall_height, WALL))
	_wall(
		"FrontLintel",
		Vector3(0, DOOR_HEIGHT + (wall_height - DOOR_HEIGHT) * 0.5, _half.y),
		Vector3(DOOR_WIDTH, wall_height - DOOR_HEIGHT, WALL)
	)

	# Corner posts and a low rail: the same framing language as the outside.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(
				self, "Post", Vector3(sx * (_half.x - 0.12), half_height, sz * (_half.y - 0.12)),
				Vector3(0.24, wall_height, 0.24), _timber
			)
	TownParts.box(self, "WallRail", Vector3(0, 0.95, -_half.y + 0.16), Vector3(room_size.x, 0.12, 0.06), _timber)

	# Ceiling beams.
	for z in [-1.9, 0.0, 1.9]:
		TownParts.box(self, "Beam", Vector3(0, wall_height - 0.08, z), Vector3(room_size.x, 0.16, 0.2), _timber)

	# Door frame, closed door panel, and a mat on the inside.
	TownParts.box(self, "DoorFrameL", Vector3(-door_half - 0.09, DOOR_HEIGHT * 0.5, _half.y - 0.12), Vector3(0.18, DOOR_HEIGHT + 0.18, 0.3), _timber)
	TownParts.box(self, "DoorFrameR", Vector3(door_half + 0.09, DOOR_HEIGHT * 0.5, _half.y - 0.12), Vector3(0.18, DOOR_HEIGHT + 0.18, 0.3), _timber)
	TownParts.box(self, "DoorLintel", Vector3(0, DOOR_HEIGHT + 0.09, _half.y - 0.12), Vector3(DOOR_WIDTH + 0.36, 0.18, 0.3), _timber)
	TownParts.box(self, "DoorPanel", Vector3(0, DOOR_HEIGHT * 0.5, _half.y + 0.18), Vector3(DOOR_WIDTH - 0.06, DOOR_HEIGHT, 0.12), _dark)
	# A solid door keeps the room sealed even if the exit cannot fire (for
	# example when the room is run on its own from the editor). It sits behind
	# the exit trigger, so walking up to the door still leaves the building.
	TownParts.collision(self, Vector3(DOOR_WIDTH + 0.36, DOOR_HEIGHT, 0.24), Vector3(0, DOOR_HEIGHT * 0.5, _half.y + 0.02))
	TownParts.sphere(self, "DoorKnob", Vector3(0.38, 1.05, _half.y + 0.1), 0.06, 0.12, _honey)
	TownParts.box(self, "Doormat", Vector3(0, 0.02, _half.y - 0.55), Vector3(1.3, 0.04, 0.7), _cloth)

	# Two windows above the counter, warm glass so the room reads as daytime.
	for x in [-1.7, 1.7]:
		TownParts.box(self, "WindowFrame", Vector3(x, 2.3, -_half.y + 0.13), Vector3(1.15, 0.95, 0.08), _timber)
		TownParts.box(self, "WindowGlass", Vector3(x, 2.3, -_half.y + 0.2), Vector3(0.95, 0.75, 0.08), _glass)
		TownParts.box(self, "WindowBar", Vector3(x, 2.3, -_half.y + 0.26), Vector3(0.07, 0.95, 0.06), _dark)


func _wall(node_name: String, position: Vector3, size: Vector3) -> void:
	TownParts.box(self, node_name, position, size, _plaster)
	TownParts.collision(self, size, position)


## An internal partition running east-west at `z`, with a walk-through doorway
## centred on each coordinate in `gaps`. Doorways keep a lintel above them, so
## the partition still reads as one wall from inside the room.
func _partition_z(z: float, x_from: float, x_to: float, gaps: Array = []) -> void:
	_partition_run(Vector3(x_from, 0.0, z), Vector3(x_to, 0.0, z), Vector3(1, 0, 0), gaps)


## An internal partition running north-south at `x`; see `_partition_z`.
func _partition_x(x: float, z_from: float, z_to: float, gaps: Array = []) -> void:
	_partition_run(Vector3(x, 0.0, z_from), Vector3(x, 0.0, z_to), Vector3(0, 0, 1), gaps)


## Shared partition builder. `axis` is the unit direction the wall runs along and
## each entry in `gaps` is an absolute coordinate on that axis (a z for an
## east-west wall, an x for a north-south one), which is easier to line up with
## the furniture than an offset from the wall's start.
func _partition_run(start: Vector3, end: Vector3, axis: Vector3, gaps: Array) -> void:
	var length := absf((end - start).dot(axis))
	if length <= 0.05:
		return

	var origin := start.dot(axis)
	var sorted: Array = gaps.duplicate()
	sorted.sort()

	var cursor := 0.0
	var half := DOOR_WIDTH * 0.5
	for raw in sorted:
		var centre := clampf(float(raw) - origin, half, length - half)
		_partition_slab(start, axis, cursor, centre - half)
		_partition_lintel(start, axis, centre)
		cursor = centre + half
	_partition_slab(start, axis, cursor, length)


func _partition_slab(start: Vector3, axis: Vector3, from_d: float, to_d: float) -> void:
	var span := to_d - from_d
	if span <= 0.03:
		return
	var mid := start + axis * (from_d + span * 0.5)
	var size := (
		Vector3(PARTITION, wall_height, span) if absf(axis.z) > 0.5
		else Vector3(span, wall_height, PARTITION)
	)
	_wall("Partition", Vector3(mid.x, wall_height * 0.5, mid.z), size)


func _partition_lintel(start: Vector3, axis: Vector3, at_d: float) -> void:
	var mid := start + axis * at_d
	var lintel := wall_height - DOOR_HEIGHT
	var size := (
		Vector3(PARTITION, lintel, DOOR_WIDTH) if absf(axis.z) > 0.5
		else Vector3(DOOR_WIDTH, lintel, PARTITION)
	)
	_wall("PartitionLintel", Vector3(mid.x, DOOR_HEIGHT + lintel * 0.5, mid.z), size)


# --- layouts ---------------------------------------------------------------


func _bakery() -> void:
	# Counter across the back, with baskets of loaves on top.
	var counter_center := Vector3(-0.5, 0, -1.95)
	TownParts.box(self, "CounterBody", Vector3(counter_center.x, 0.48, counter_center.z), Vector3(3.8, 0.96, 0.85), _timber)
	TownParts.box(self, "CounterTop", Vector3(counter_center.x, 1.0, counter_center.z), Vector3(4.0, 0.12, 0.95), _plank)
	TownParts.collision(self, Vector3(4.0, 1.1, 0.95), Vector3(counter_center.x, 0.55, counter_center.z))

	for i in 3:
		var x := -1.85 + i * 1.3
		TownParts.cylinder(self, "Basket", Vector3(x, 1.18, -1.95), 0.3, 0.24, 0.2, _bread, Vector3.ZERO, 8)
		for j in 3:
			TownParts.sphere(
				self, "Loaf", Vector3(x - 0.12 + j * 0.12, 1.34, -1.95 + (j % 2) * 0.12),
				0.13, 0.26, _bread
			)

	# Back shelf with jars.
	for i in 3:
		var y := 1.45 + i * 0.45
		TownParts.box(self, "Shelf", Vector3(0, y, -_half.y + 0.3), Vector3(3.6, 0.06, 0.34), _plank)
		for j in 7:
			var x := -1.55 + j * 0.52
			TownParts.cylinder(self, "Jar", Vector3(x, y + 0.16, -_half.y + 0.3), 0.09, 0.09, 0.26, _honey, Vector3.ZERO, 6)

	# Stone oven in the west wall, with a glowing mouth.
	TownParts.box(self, "Oven", Vector3(-2.8, 1.0, -0.9), Vector3(1.3, 2.0, 1.5), _stone)
	TownParts.box(self, "OvenTop", Vector3(-2.8, 2.02, -0.9), Vector3(1.45, 0.12, 1.65), _stone)
	TownParts.box(self, "OvenChimney", Vector3(-2.8, 2.75, -0.9), Vector3(0.85, 1.5, 1.0), _stone)
	TownParts.box(self, "OvenMouth", Vector3(-2.12, 0.95, -0.9), Vector3(0.08, 0.62, 0.72), _dark)
	TownParts.box(self, "OvenFire", Vector3(-2.1, 0.86, -0.9), Vector3(0.06, 0.34, 0.5), _glass)
	TownParts.collision(self, Vector3(1.45, 2.1, 1.65), Vector3(-2.8, 1.05, -0.9))

	# Flour sacks beside the oven.
	TownParts.sphere(self, "Sack", Vector3(-2.5, 0.32, 0.55), 0.34, 0.64, _linen)
	TownParts.sphere(self, "SackB", Vector3(-2.05, 0.28, 0.82), 0.28, 0.54, _linen)

	# Fireplace on the quiet front stretch of the west wall, clear of the oven,
	# the sacks, and the door on the far wall. Uses the imported 2D hearth art.
	_sprite_prop(SPRITE_FIREPLACE, Vector3(-_half.x + 0.45, 0.0, 1.6), 1.5)
	TownParts.collision(self, Vector3(0.6, 1.2, 1.3), Vector3(-_half.x + 0.45, 0.6, 1.6))

	# Work table and stools.
	var table := Vector3(1.25, 0, 0.35)
	TownParts.box(self, "TableTop", Vector3(table.x, 0.78, table.z), Vector3(1.8, 0.1, 1.05), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(
				self, "TableLeg", Vector3(table.x + sx * 0.75, 0.39, table.z + sz * 0.4),
				Vector3(0.1, 0.78, 0.1), _timber
			)
	TownParts.collision(self, Vector3(1.9, 0.9, 1.15), Vector3(table.x, 0.45, table.z))
	TownParts.cylinder(self, "Stool", Vector3(0.25, 0.44, 1.15), 0.23, 0.2, 0.08, _plank, Vector3.ZERO, 8)
	TownParts.cylinder(self, "StoolLeg", Vector3(0.25, 0.22, 1.15), 0.06, 0.08, 0.44, _timber, Vector3.ZERO, 6)
	TownParts.cylinder(self, "StoolB", Vector3(2.15, 0.44, -0.45), 0.23, 0.2, 0.08, _plank, Vector3.ZERO, 8)
	TownParts.cylinder(self, "StoolLegB", Vector3(2.15, 0.22, -0.45), 0.06, 0.08, 0.44, _timber, Vector3.ZERO, 6)

	# East wall shelves and storage.
	for i in 3:
		var y := 1.35 + i * 0.5
		TownParts.box(self, "EastShelf", Vector3(_half.x - 0.28, y, 0.2), Vector3(0.34, 0.06, 2.4), _plank)
		for j in 4:
			TownParts.cylinder(
				self, "ShelfJar", Vector3(_half.x - 0.3, y + 0.15, -0.75 + j * 0.55),
				0.08, 0.08, 0.24, _honey, Vector3.ZERO, 6
			)
	for i in 4:
		TownParts.cylinder(
			self, "Crock", Vector3(_half.x - 0.28, 0.3, -0.9 + i * 0.5),
			0.2, 0.16, 0.6, _stone, Vector3.ZERO, 8
		)
	TownParts.cylinder(self, "Barrel", Vector3(3.0, 0.45, 1.9), 0.38, 0.42, 0.9, _timber, Vector3.ZERO, 10)
	TownParts.collision(self, Vector3(0.9, 0.9, 0.9), Vector3(3.0, 0.45, 1.9))

	# Herb bundles hanging from the beams.
	for i in 3:
		var x := -2.3 + i * 2.3
		TownParts.box(self, "HerbString", Vector3(x, 2.55, -1.35), Vector3(0.03, 0.35, 0.03), _dark)
		TownParts.cone(self, "Herbs", Vector3(x, 2.28, -1.35), 0.16, 0.3, _timber, 5)

	# A rug to soften the middle of the room.
	TownParts.box(self, "Rug", Vector3(0.1, 0.02, 0.75), Vector3(2.6, 0.03, 1.25), _cloth)


func _cottage() -> void:
	# Bed tucked into the back-left corner.
	var bed_x := -_half.x + 0.95
	var bed_z := -_half.y + 1.35
	TownParts.box(self, "BedFrame", Vector3(bed_x, 0.3, bed_z), Vector3(1.5, 0.45, 2.0), _timber)
	TownParts.box(self, "Mattress", Vector3(bed_x, 0.58, bed_z), Vector3(1.4, 0.22, 1.9), _cloth)
	TownParts.box(self, "Pillow", Vector3(bed_x, 0.76, bed_z - 0.72), Vector3(1.0, 0.16, 0.4), _linen)
	TownParts.collision(self, Vector3(1.5, 0.8, 2.0), Vector3(bed_x, 0.4, bed_z))
	_bed_body(Vector3(bed_x, 0.0, bed_z), Vector3(1.6, 0.95, 2.1))

	# Table and a stool on the other side.
	var table := Vector3(_half.x - 1.6, 0, 0.2)
	TownParts.box(self, "TableTop", Vector3(table.x, 0.78, table.z), Vector3(1.5, 0.1, 0.9), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "TableLeg", Vector3(table.x + sx * 0.6, 0.39, table.z + sz * 0.33), Vector3(0.1, 0.78, 0.1), _timber)
	TownParts.collision(self, Vector3(1.6, 0.9, 1.0), Vector3(table.x, 0.45, table.z))
	TownParts.cylinder(self, "Stool", Vector3(table.x - 1.0, 0.44, table.z + 0.5), 0.23, 0.2, 0.08, _plank, Vector3.ZERO, 8)
	TownParts.cylinder(self, "StoolLeg", Vector3(table.x - 1.0, 0.22, table.z + 0.5), 0.06, 0.08, 0.44, _timber, Vector3.ZERO, 6)

	# Hearth on the back wall.
	TownParts.box(self, "Hearth", Vector3(0, 0.6, -_half.y + 0.25), Vector3(1.8, 1.2, 0.5), _stone)
	TownParts.box(self, "HearthFire", Vector3(0, 0.45, -_half.y + 0.52), Vector3(1.0, 0.5, 0.06), _glass)
	TownParts.collision(self, Vector3(1.8, 1.2, 0.5), Vector3(0, 0.6, -_half.y + 0.25))

	# Accent: a jar shelf, a wash tub, or a woodpile.
	match accent % 3:
		0:
			for i in 3:
				TownParts.box(self, "Shelf", Vector3(0.2, 1.45 + i * 0.42, -_half.y + 0.3), Vector3(2.4, 0.06, 0.32), _plank)
				for j in 5:
					TownParts.cylinder(self, "Jar", Vector3(-0.8 + j * 0.45, 1.6 + i * 0.42, -_half.y + 0.3), 0.08, 0.08, 0.2, _honey, Vector3.ZERO, 6)
		1:
			TownParts.cylinder(self, "Tub", Vector3(_half.x - 0.8, 0.3, _half.y - 1.2), 0.36, 0.32, 0.6, _timber, Vector3.ZERO, 10)
			TownParts.cylinder(self, "TubWater", Vector3(_half.x - 0.8, 0.58, _half.y - 1.2), 0.3, 0.3, 0.04, _glass, Vector3.ZERO, 10)
		_:
			for i in 4:
				TownParts.cylinder(
					self, "Log", Vector3(table.x + 0.95, 0.12 + int(i / 2.0) * 0.24, table.z - 1.0 + (i % 2) * 0.25),
					0.11, 0.11, 0.8, _timber, Vector3(PI * 0.5, 0.0, 0.0), 6
				)

	TownParts.box(self, "Rug", Vector3(0, 0.02, 0.6), Vector3(2.2, 0.03, 1.4), _cloth)


func _longhouse() -> void:
	# Two beds along the west wall.
	for i in 2:
		var bz := -_half.y + 1.4 + i * 2.3
		var bx := -_half.x + 0.9
		TownParts.box(self, "BedFrame", Vector3(bx, 0.3, bz), Vector3(1.4, 0.45, 2.0), _timber)
		TownParts.box(self, "Mattress", Vector3(bx, 0.58, bz), Vector3(1.3, 0.22, 1.9), _cloth)
		TownParts.box(self, "Pillow", Vector3(bx, 0.76, bz - 0.72), Vector3(0.95, 0.14, 0.38), _linen)
		TownParts.collision(self, Vector3(1.4, 0.8, 2.0), Vector3(bx, 0.4, bz))
		_bed_body(Vector3(bx, 0.0, bz), Vector3(1.5, 0.95, 2.1))

	# A long table down the east side.
	var tx := _half.x - 1.9
	TownParts.box(self, "TableTop", Vector3(tx, 0.8, 0.4), Vector3(1.5, 0.1, 3.4), _plank)
	for sz in [-1.4, 0.4, 1.8]:
		for sx in [-0.6, 0.6]:
			TownParts.box(self, "TableLeg", Vector3(tx + sx, 0.4, 0.4 + sz), Vector3(0.1, 0.8, 0.1), _timber)
	TownParts.collision(self, Vector3(1.6, 0.9, 3.5), Vector3(tx, 0.45, 0.4))
	for i in 3:
		TownParts.cylinder(self, "Stool", Vector3(tx - 1.0, 0.44, -0.7 + i * 1.1), 0.22, 0.2, 0.08, _plank, Vector3.ZERO, 8)
		TownParts.cylinder(self, "StoolLeg", Vector3(tx - 1.0, 0.22, -0.7 + i * 1.1), 0.06, 0.08, 0.44, _timber, Vector3.ZERO, 6)

	# Hearth at the back, with a mantel.
	TownParts.box(self, "Hearth", Vector3(0, 0.65, -_half.y + 0.3), Vector3(2.2, 1.3, 0.6), _stone)
	TownParts.box(self, "HearthFire", Vector3(0, 0.45, -_half.y + 0.62), Vector3(1.2, 0.5, 0.06), _glass)
	TownParts.collision(self, Vector3(2.2, 1.3, 0.6), Vector3(0, 0.65, -_half.y + 0.3))
	TownParts.box(self, "Mantel", Vector3(0, 1.35, -_half.y + 0.3), Vector3(2.5, 0.12, 0.7), _plank)
	for i in 3:
		TownParts.cylinder(self, "MantelJar", Vector3(-0.7 + i * 0.7, 1.55, -_half.y + 0.35), 0.09, 0.09, 0.28, _honey, Vector3.ZERO, 6)

	# Bench and coats on the east wall.
	TownParts.box(self, "Bench", Vector3(_half.x - 0.5, 0.45, -_half.y + 1.6), Vector3(0.6, 0.1, 1.8), _plank)
	for i in 3:
		TownParts.box(self, "BenchLeg", Vector3(_half.x - 0.5, 0.22, -_half.y + 0.85 + i * 0.75), Vector3(0.5, 0.45, 0.1), _timber)
	for i in 3:
		TownParts.box(self, "Coat", Vector3(_half.x - 0.14, 1.7, 0.6 + i * 0.35), Vector3(0.08, 0.9, 0.3), _cloth if i % 2 == 0 else _linen)

	TownParts.box(self, "Rug", Vector3(0.3, 0.02, 0.4), Vector3(2.6, 0.03, 3.6), _cloth)


func _chapel() -> void:
	# Altar at the north end.
	var altar_z := -_half.y + 1.1
	TownParts.box(self, "Altar", Vector3(0, 0.5, altar_z), Vector3(2.6, 1.0, 0.9), _stone)
	TownParts.box(self, "AltarTop", Vector3(0, 1.03, altar_z), Vector3(2.9, 0.12, 1.05), _plank)
	TownParts.collision(self, Vector3(2.9, 1.1, 1.05), Vector3(0, 0.55, altar_z))
	for x in [-0.8, 0.0, 0.8]:
		TownParts.cylinder(self, "Candle", Vector3(x, 1.22, altar_z), 0.05, 0.05, 0.26, _linen, Vector3.ZERO, 6)
		TownParts.box(self, "Flame", Vector3(x, 1.4, altar_z), Vector3(0.05, 0.1, 0.05), _glass)
	TownParts.box(self, "Banner", Vector3(0, 2.1, -_half.y + 0.2), Vector3(1.3, 1.5, 0.05), _cloth)

	# Lectern off the aisle.
	var lectern_z := altar_z + 1.3
	TownParts.cylinder(self, "LecternStem", Vector3(1.7, 0.55, lectern_z), 0.08, 0.1, 1.1, _timber, Vector3.ZERO, 6)
	TownParts.box(self, "Lectern", Vector3(1.7, 1.16, lectern_z), Vector3(0.7, 0.08, 0.5), _plank)

	# Pew rows facing the altar, with a clear centre aisle.
	var rows := maxi(2, int((room_size.y - 3.6) / 1.5))
	for r in rows:
		var z := altar_z + 2.2 + r * 1.5
		if z > _half.y - 1.3:
			break
		for side in [-1.0, 1.0]:
			var x: float = side * (room_size.x * 0.23)
			TownParts.box(self, "PewSeat", Vector3(x, 0.45, z), Vector3(1.7, 0.12, 0.45), _plank)
			TownParts.box(self, "PewBack", Vector3(x, 0.75, z - 0.2), Vector3(1.7, 0.55, 0.1), _plank)
			TownParts.box(self, "PewLeg", Vector3(x - 0.7, 0.22, z), Vector3(0.1, 0.45, 0.4), _timber)
			TownParts.box(self, "PewLeg", Vector3(x + 0.7, 0.22, z), Vector3(0.1, 0.45, 0.4), _timber)
			TownParts.collision(self, Vector3(1.7, 0.9, 0.5), Vector3(x, 0.45, z - 0.1))

	# Font by the door.
	TownParts.cylinder(self, "FontBase", Vector3(-_half.x + 0.8, 0.35, _half.y - 1.1), 0.22, 0.3, 0.7, _stone, Vector3.ZERO, 8)
	TownParts.cylinder(self, "FontBowl", Vector3(-_half.x + 0.8, 0.78, _half.y - 1.1), 0.42, 0.24, 0.28, _stone, Vector3.ZERO, 8)
	TownParts.cylinder(self, "FontWater", Vector3(-_half.x + 0.8, 0.9, _half.y - 1.1), 0.3, 0.3, 0.03, _glass, Vector3.ZERO, 10)


func _tower() -> void:
	# Stone footing and a ladder to the hatch above.
	TownParts.box(self, "StoneFloor", Vector3(0, 0.02, 0), Vector3(room_size.x - 1.0, 0.04, room_size.y - 1.0), _stone)
	var lx := -_half.x + 0.55
	TownParts.box(self, "LadderRail", Vector3(lx, 1.5, -_half.y + 0.45), Vector3(0.08, 3.0, 0.08), _timber)
	TownParts.box(self, "LadderRail", Vector3(lx + 0.42, 1.5, -_half.y + 0.45), Vector3(0.08, 3.0, 0.08), _timber)
	for i in 7:
		TownParts.box(self, "Rung", Vector3(lx + 0.21, 0.35 + i * 0.4, -_half.y + 0.45), Vector3(0.5, 0.05, 0.05), _plank)

	# Bedroll, crates, and a small round table.
	TownParts.box(self, "Bedroll", Vector3(_half.x - 1.0, 0.08, 1.2), Vector3(0.9, 0.12, 1.8), _cloth)
	TownParts.sphere(self, "BedrollPillow", Vector3(_half.x - 1.0, 0.2, 1.9), 0.28, 0.22, _linen)
	TownParts.box(self, "CrateA", Vector3(0.9, 0.3, -1.4), Vector3(0.7, 0.6, 0.7), _timber)
	TownParts.box(self, "CrateB", Vector3(0.9, 0.8, -1.4), Vector3(0.55, 0.4, 0.55), _plank)
	TownParts.cylinder(self, "Table", Vector3(0.2, 0.7, 0.7), 0.55, 0.55, 0.08, _plank, Vector3.ZERO, 10)
	TownParts.cylinder(self, "TableLeg", Vector3(0.2, 0.35, 0.7), 0.09, 0.12, 0.7, _timber, Vector3.ZERO, 6)
	TownParts.cylinder(self, "Mug", Vector3(0.35, 0.79, 0.65), 0.07, 0.07, 0.12, _honey, Vector3.ZERO, 6)

	# Wall shelf with jars.
	TownParts.box(self, "Shelf", Vector3(0, 1.7, -_half.y + 0.3), Vector3(1.6, 0.06, 0.34), _plank)
	for i in 3:
		TownParts.cylinder(self, "Jar", Vector3(-0.45 + i * 0.45, 1.86, -_half.y + 0.3), 0.09, 0.09, 0.24, _honey, Vector3.ZERO, 6)


func _hive() -> void:
	# Honey vats along the back.
	for i in 2:
		var x := -_half.x + 1.0 + i * 1.5
		TownParts.cylinder(self, "Vat", Vector3(x, 0.5, -_half.y + 1.1), 0.46, 0.42, 1.0, _timber, Vector3.ZERO, 10)
		TownParts.cylinder(self, "VatRim", Vector3(x, 1.03, -_half.y + 1.1), 0.48, 0.48, 0.08, _honey, Vector3.ZERO, 10)
		TownParts.collision(self, Vector3(1.0, 1.1, 1.0), Vector3(x, 0.55, -_half.y + 1.1))

	# Hive boxes stacked on the east wall.
	for i in 3:
		TownParts.box(self, "HiveBox", Vector3(_half.x - 0.6, 0.28 + i * 0.28, -0.6), Vector3(0.62, 0.26, 0.62), _plank)

	# Drying rack with comb frames.
	TownParts.box(self, "RackTop", Vector3(0.9, 1.7, 1.4), Vector3(1.8, 0.08, 0.5), _timber)
	for sx in [-0.8, 0.8]:
		TownParts.box(self, "RackLeg", Vector3(0.9 + sx, 0.85, 1.4), Vector3(0.08, 1.7, 0.08), _timber)
	for i in 3:
		TownParts.box(self, "Comb", Vector3(0.4 + i * 0.5, 1.5, 1.4), Vector3(0.3, 0.34, 0.06), _honey)

	# Barrels and pots.
	TownParts.cylinder(self, "Barrel", Vector3(-1.6, 0.45, 1.6), 0.36, 0.4, 0.9, _timber, Vector3.ZERO, 10)
	TownParts.collision(self, Vector3(0.8, 0.9, 0.8), Vector3(-1.6, 0.45, 1.6))
	for i in 3:
		TownParts.cylinder(self, "Pot", Vector3(-2.0 + i * 0.35, 0.18, 0.4), 0.16, 0.12, 0.36, _honey, Vector3.ZERO, 8)


func _office() -> void:
	# Desk with ledgers, a candle, and a chair.
	var dz := -_half.y + 1.5
	TownParts.box(self, "DeskTop", Vector3(-0.6, 0.8, dz), Vector3(2.2, 0.1, 1.0), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "DeskLeg", Vector3(-0.6 + sx * 0.95, 0.4, dz + sz * 0.38), Vector3(0.1, 0.8, 0.1), _timber)
	TownParts.collision(self, Vector3(2.3, 0.9, 1.1), Vector3(-0.6, 0.45, dz))
	for i in 3:
		TownParts.box(self, "Ledger", Vector3(-0.95 + i * 0.35, 0.88, dz - 0.1), Vector3(0.28, 0.06, 0.4), _cloth)
	TownParts.cylinder(self, "DeskCandle", Vector3(0.3, 0.95, dz), 0.05, 0.05, 0.24, _linen, Vector3.ZERO, 6)
	TownParts.box(self, "DeskFlame", Vector3(0.3, 1.1, dz), Vector3(0.05, 0.1, 0.05), _glass)
	TownParts.box(self, "ChairSeat", Vector3(-0.6, 0.45, dz + 1.0), Vector3(0.6, 0.1, 0.55), _plank)
	TownParts.box(self, "ChairBack", Vector3(-0.6, 0.8, dz + 1.25), Vector3(0.6, 0.7, 0.08), _plank)

	# Shelves of boxes on the east wall.
	for i in 3:
		TownParts.box(self, "Shelf", Vector3(_half.x - 0.35, 1.3 + i * 0.45, -_half.y + 1.2), Vector3(0.34, 0.06, 1.8), _plank)
	for i in 6:
		var zoff := 0.9 if i >= 3 else 0.0
		TownParts.box(self, "Box", Vector3(_half.x - 0.38, 1.4 + (i % 3) * 0.45, -_half.y + 0.5 + zoff), Vector3(0.24, 0.2, 0.3), _timber)

	# Strongbox and a wall map.
	TownParts.box(self, "Strongbox", Vector3(1.4, 0.3, 1.6), Vector3(1.1, 0.6, 0.7), _timber)
	TownParts.box(self, "StrongboxLid", Vector3(1.4, 0.64, 1.6), Vector3(1.15, 0.08, 0.75), _dark)
	TownParts.collision(self, Vector3(1.2, 0.7, 0.8), Vector3(1.4, 0.35, 1.6))
	TownParts.box(self, "Map", Vector3(-_half.x + 0.2, 1.9, 0.4), Vector3(0.06, 1.0, 1.4), _linen)

	# A cot in the back-left corner. The Toothkeeper's house is also his office,
	# and an office with a bed is a house.
	var bed_x := -_half.x + 0.95
	var bed_z := -_half.y + 1.35
	TownParts.box(self, "BedFrame", Vector3(bed_x, 0.3, bed_z), Vector3(1.5, 0.45, 2.0), _timber)
	TownParts.box(self, "Mattress", Vector3(bed_x, 0.58, bed_z), Vector3(1.4, 0.22, 1.9), _cloth)
	TownParts.box(self, "Pillow", Vector3(bed_x, 0.76, bed_z - 0.72), Vector3(1.0, 0.16, 0.4), _linen)
	TownParts.collision(self, Vector3(1.5, 0.8, 2.0), Vector3(bed_x, 0.4, bed_z))
	_bed_body(Vector3(bed_x, 0.0, bed_z), Vector3(1.6, 0.95, 2.1))


func _store() -> void:
	# Counter along the west wall.
	var cx := -_half.x + 0.75
	TownParts.box(self, "CounterBody", Vector3(cx, 0.48, 0.3), Vector3(0.9, 0.96, 3.0), _timber)
	TownParts.box(self, "CounterTop", Vector3(cx, 1.02, 0.3), Vector3(1.0, 0.12, 3.1), _plank)
	TownParts.collision(self, Vector3(1.0, 1.1, 3.1), Vector3(cx, 0.55, 0.3))
	for i in 4:
		TownParts.box(self, "Goods", Vector3(cx, 1.14, -1.0 + i * 0.8), Vector3(0.5, 0.14, 0.45), _cloth)

	# Shelves on the east wall.
	for i in 3:
		TownParts.box(self, "Shelf", Vector3(_half.x - 0.35, 1.4 + i * 0.5, 0.0), Vector3(0.34, 0.06, 3.2), _plank)
		for j in 5:
			TownParts.cylinder(self, "Jar", Vector3(_half.x - 0.38, 1.58 + i * 0.5, -1.3 + j * 0.65), 0.09, 0.09, 0.26, _honey, Vector3.ZERO, 6)

	# Crates, a sack, and the shop scale.
	TownParts.box(self, "CrateA", Vector3(1.5, 0.3, -1.6), Vector3(0.8, 0.6, 0.8), _timber)
	TownParts.box(self, "CrateB", Vector3(1.5, 0.8, -1.6), Vector3(0.6, 0.4, 0.6), _plank)
	TownParts.sphere(self, "Sack", Vector3(-1.0, 0.3, 1.9), 0.3, 0.6, _linen)

	# A display table in the middle of the floor.
	TownParts.box(self, "DisplayTop", Vector3(0.8, 0.8, -0.5), Vector3(1.5, 0.1, 0.9), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "DisplayLeg", Vector3(0.8 + sx * 0.6, 0.4, -0.5 + sz * 0.33), Vector3(0.1, 0.8, 0.1), _timber)
	TownParts.collision(self, Vector3(1.6, 0.9, 1.0), Vector3(0.8, 0.45, -0.5))
	for i in 3:
		TownParts.cylinder(self, "DisplayJar", Vector3(0.4 + i * 0.4, 1.0, -0.5), 0.1, 0.1, 0.3, _honey, Vector3.ZERO, 6)

	TownParts.box(self, "ScaleBeam", Vector3(1.6, 1.0, 0.8), Vector3(0.05, 0.05, 0.9), _dark)
	TownParts.cylinder(self, "ScalePanA", Vector3(1.6, 0.95, 1.2), 0.16, 0.16, 0.04, _stone, Vector3.ZERO, 10)
	TownParts.cylinder(self, "ScalePanB", Vector3(1.6, 0.95, 0.4), 0.16, 0.16, 0.04, _stone, Vector3.ZERO, 10)

	# Hanging sign above the counter.
	TownParts.box(self, "SignBoard", Vector3(cx, 2.15, -0.3), Vector3(0.06, 0.5, 1.2), _plank)


## A working smithy: a stone forge, an anvil on a stump, a quench barrel, and a
## rack of half-finished blades. Used by Thornridge's forge interior.
func _forge() -> void:
	# Forge hearth on the west wall, mouth facing the room.
	var fx := -_half.x + 1.0
	TownParts.box(self, "ForgeHearth", Vector3(fx, 0.8, -0.8), Vector3(1.5, 1.6, 2.4), _stone)
	TownParts.box(self, "ForgeHood", Vector3(fx, 2.1, -0.8), Vector3(1.3, 0.9, 1.8), _stone)
	TownParts.box(self, "ForgeMouth", Vector3(fx + 0.72, 0.6, -0.8), Vector3(0.08, 0.6, 1.1), _dark)
	TownParts.box(self, "ForgeFire", Vector3(fx + 0.75, 0.55, -0.8), Vector3(0.05, 0.4, 0.9), _glass)
	TownParts.collision(self, Vector3(1.6, 1.7, 2.5), Vector3(fx, 0.85, -0.8))

	# Anvil on a block, out on the floor where a smith would stand.
	var anvil := Vector3(0.4, 0.0, 0.1)
	TownParts.cylinder(self, "AnvilStump", Vector3(anvil.x, 0.28, anvil.z), 0.34, 0.38, 0.56, _timber, Vector3.ZERO, 8)
	TownParts.box(self, "AnvilBody", Vector3(anvil.x, 0.72, anvil.z), Vector3(0.42, 0.26, 1.05), _dark)
	TownParts.box(self, "AnvilHorn", Vector3(anvil.x - 0.36, 0.74, anvil.z), Vector3(0.36, 0.16, 0.3), _dark)
	TownParts.collision(self, Vector3(0.9, 0.9, 1.1), Vector3(anvil.x, 0.45, anvil.z))

	# Quench barrel and a slack tub.
	TownParts.cylinder(self, "QuenchBarrel", Vector3(-1.9, 0.45, 1.5), 0.38, 0.42, 0.9, _timber, Vector3.ZERO, 10)
	TownParts.collision(self, Vector3(0.9, 0.9, 0.9), Vector3(-1.9, 0.45, 1.5))
	TownParts.cylinder(self, "SlackTub", Vector3(-0.4, 0.24, 1.9), 0.3, 0.26, 0.48, _timber, Vector3.ZERO, 10)
	TownParts.cylinder(self, "SlackWater", Vector3(-0.4, 0.46, 1.9), 0.26, 0.26, 0.03, _glass, Vector3.ZERO, 10)

	# Weapon rack on the east wall: three blades and a hammer.
	var rx := _half.x - 0.45
	TownParts.box(self, "RackBack", Vector3(rx, 1.35, 0.4), Vector3(0.14, 0.16, 2.6), _timber)
	for i in 3:
		var z := -0.5 + i * 0.75
		TownParts.box(self, "RackBlade", Vector3(rx - 0.12, 1.05, z), Vector3(0.05, 1.15, 0.12), _stone)
		TownParts.box(self, "RackHilt", Vector3(rx - 0.12, 0.52, z), Vector3(0.07, 0.26, 0.26), _dark)
	TownParts.box(self, "RackHammer", Vector3(rx - 0.12, 1.1, 1.35), Vector3(0.09, 0.9, 0.09), _timber)
	TownParts.box(self, "RackHammerHead", Vector3(rx - 0.12, 1.5, 1.35), Vector3(0.14, 0.22, 0.34), _dark)

	# Tool shelf and a coal bin.
	TownParts.box(self, "ToolShelf", Vector3(1.4, 1.55, -_half.y + 0.3), Vector3(2.2, 0.07, 0.34), _plank)
	for i in 4:
		TownParts.box(self, "Tongs", Vector3(0.6 + i * 0.5, 1.66, -_half.y + 0.3), Vector3(0.06, 0.14, 0.26), _dark)
	TownParts.box(self, "CoalBin", Vector3(2.3, 0.32, 1.9), Vector3(1.1, 0.64, 0.9), _timber)
	TownParts.box(self, "Coal", Vector3(2.3, 0.68, 1.9), Vector3(0.9, 0.12, 0.7), _dark)
	TownParts.collision(self, Vector3(1.2, 0.7, 1.0), Vector3(2.3, 0.35, 1.9))

	# A customer bench by the door.
	TownParts.box(self, "BenchSeat", Vector3(-2.6, 0.45, 2.2), Vector3(1.8, 0.1, 0.5), _plank)
	for sx in [-0.7, 0.7]:
		TownParts.box(self, "BenchLeg", Vector3(-2.6 + sx, 0.22, 2.2), Vector3(0.1, 0.45, 0.45), _timber)


func _seamstress() -> void:
	# Loom against the back wall.
	var lz := -_half.y + 0.9
	for sx in [-0.9, 0.9]:
		TownParts.box(self, "LoomPost", Vector3(sx, 1.0, lz), Vector3(0.12, 2.0, 0.12), _timber)
	TownParts.box(self, "LoomTop", Vector3(0, 1.95, lz), Vector3(1.95, 0.12, 0.16), _timber)
	TownParts.box(self, "LoomBeam", Vector3(0, 1.3, lz), Vector3(1.9, 0.14, 0.14), _timber)
	for i in 9:
		TownParts.box(self, "Warp", Vector3(-0.8 + i * 0.2, 1.0, lz), Vector3(0.02, 1.7, 0.02), _linen)
	TownParts.collision(self, Vector3(2.0, 2.0, 0.6), Vector3(0, 1.0, lz))

	# Cloth bolts on the east shelves.
	for i in 3:
		TownParts.box(self, "Shelf", Vector3(_half.x - 0.35, 1.4 + i * 0.5, 0.3), Vector3(0.34, 0.06, 2.6), _plank)
		for j in 4:
			TownParts.cylinder(
				self, "Bolt", Vector3(_half.x - 0.38, 1.55 + i * 0.5, -0.8 + j * 0.7),
				0.11, 0.11, 0.55, _cloth if j % 2 == 0 else _linen, Vector3(PI * 0.5, 0.0, 0.0), 8
			)

	# Cutting table and a mannequin.
	TownParts.box(self, "CutTable", Vector3(0.9, 0.78, 1.3), Vector3(1.6, 0.1, 1.0), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "CutTableLeg", Vector3(0.9 + sx * 0.65, 0.39, 1.3 + sz * 0.4), Vector3(0.1, 0.78, 0.1), _timber)
	TownParts.collision(self, Vector3(1.7, 0.9, 1.1), Vector3(0.9, 0.45, 1.3))
	TownParts.cylinder(self, "Stand", Vector3(-1.6, 0.25, 1.4), 0.05, 0.05, 0.5, _timber, Vector3.ZERO, 6)
	TownParts.sphere(self, "Torso", Vector3(-1.6, 1.1, 1.4), 0.32, 0.9, _linen)
	TownParts.sphere(self, "Head", Vector3(-1.6, 1.72, 1.4), 0.18, 0.34, _linen)
	for i in 5:
		TownParts.cylinder(self, "Spool", Vector3(-0.2 + i * 0.2, 0.86, 1.45), 0.05, 0.05, 0.14, _cloth, Vector3.ZERO, 6)

	# Bed in the back-left corner, clear of the loom and the cutting table. The
	# seamstress sleeps here, so the room needs a bed the player can use.
	var bed_x := -_half.x + 0.95
	var bed_z := -_half.y + 1.35
	TownParts.box(self, "BedFrame", Vector3(bed_x, 0.3, bed_z), Vector3(1.5, 0.45, 2.0), _timber)
	TownParts.box(self, "Mattress", Vector3(bed_x, 0.58, bed_z), Vector3(1.4, 0.22, 1.9), _cloth)
	TownParts.box(self, "Pillow", Vector3(bed_x, 0.76, bed_z - 0.72), Vector3(1.0, 0.16, 0.4), _linen)
	TownParts.collision(self, Vector3(1.5, 0.8, 2.0), Vector3(bed_x, 0.4, bed_z))
	_bed_body(Vector3(bed_x, 0.0, bed_z), Vector3(1.6, 0.95, 2.1))


func _loom() -> void:
	# Two standing looms at the back.
	_loom_frame(Vector3(-1.2, 0, -_half.y + 1.0))
	_loom_frame(Vector3(1.2, 0, -_half.y + 1.0))

	# Wool bales in the west corner.
	for i in 3:
		TownParts.sphere(self, "Bale", Vector3(-_half.x + 0.9, 0.4, 0.6 + i * 0.6), 0.38, 0.72, _linen)
	TownParts.collision(self, Vector3(1.2, 1.2, 2.4), Vector3(-_half.x + 0.9, 0.5, 1.2))

	# Spool racks on the east wall.
	for i in 3:
		TownParts.box(self, "SpoolShelf", Vector3(_half.x - 0.35, 1.4 + i * 0.45, 0.4), Vector3(0.34, 0.06, 2.0), _plank)
		for j in 4:
			TownParts.cylinder(self, "Spool", Vector3(_half.x - 0.38, 1.56 + i * 0.45, -0.4 + j * 0.55), 0.09, 0.09, 0.3, _honey, Vector3.ZERO, 6)

	TownParts.cylinder(self, "Stool", Vector3(0.4, 0.44, 1.0), 0.22, 0.2, 0.08, _plank, Vector3.ZERO, 8)
	TownParts.cylinder(self, "StoolLeg", Vector3(0.4, 0.22, 1.0), 0.06, 0.08, 0.44, _timber, Vector3.ZERO, 6)
	TownParts.box(self, "Rug", Vector3(0.2, 0.02, 0.6), Vector3(2.2, 0.03, 2.0), _cloth)


func _loom_frame(at: Vector3) -> void:
	for sx in [-0.8, 0.8]:
		TownParts.box(self, "LoomPost", at + Vector3(sx, 1.0, 0), Vector3(0.12, 2.0, 0.12), _timber)
	TownParts.box(self, "LoomTop", at + Vector3(0, 1.95, 0), Vector3(1.85, 0.12, 0.16), _timber)
	TownParts.box(self, "LoomBeam", at + Vector3(0, 1.3, 0), Vector3(1.8, 0.14, 0.14), _timber)
	for i in 8:
		TownParts.box(self, "Warp", at + Vector3(-0.75 + i * 0.21, 1.0, 0), Vector3(0.02, 1.7, 0.02), _linen)
	TownParts.collision(self, Vector3(1.9, 2.0, 0.5), at + Vector3(0, 1.0, 0))


func _abandoned() -> void:
	# A broken table and a toppled stool.
	TownParts.box(self, "BrokenTop", Vector3(-0.2, 0.5, -0.6), Vector3(1.6, 0.08, 0.9), _plank)
	TownParts.box(self, "BrokenLeg", Vector3(-0.9, 0.25, -0.9), Vector3(0.1, 0.5, 0.1), _timber)
	TownParts.box(self, "BrokenLeg", Vector3(0.4, 0.22, -0.35), Vector3(0.1, 0.44, 0.1), _timber)
	TownParts.cylinder(self, "ToppledStool", Vector3(1.3, 0.2, 0.7), 0.23, 0.2, 0.08, _plank, Vector3(0.0, 0.0, 1.3), 8)

	# Rubble in the back corner.
	for i in 6:
		TownParts.sphere(
			self, "Rubble", Vector3(_half.x - 0.8 - (i % 3) * 0.35, 0.1, -_half.y + 0.8 + int(i / 3.0) * 0.4),
			0.14 + (i % 2) * 0.06, 0.24, _stone
		)

	# A fallen beam and creeping moss.
	TownParts.box(self, "FallenBeam", Vector3(0.6, 0.14, 1.1), Vector3(2.4, 0.16, 0.2), _timber)
	for i in 4:
		TownParts.box(self, "Moss", Vector3(-_half.x + 0.35 + i * 0.5, 0.03, _half.y - 0.45 - (i % 2) * 0.3), Vector3(0.3, 0.02, 0.25), _moss)

	# Empty shelves, a dead hearth, and leaves that blew in.
	for i in 2:
		TownParts.box(self, "EmptyShelf", Vector3(0.2, 1.4 + i * 0.5, -_half.y + 0.3), Vector3(2.0, 0.06, 0.32), _plank)
	TownParts.box(self, "ColdHearth", Vector3(0, 0.5, -_half.y + 0.3), Vector3(1.6, 1.0, 0.5), _stone)
	TownParts.collision(self, Vector3(1.6, 1.0, 0.5), Vector3(0, 0.5, -_half.y + 0.3))
	for i in 7:
		TownParts.box(self, "Leaf", Vector3(-1.4 + (i % 4) * 0.6, 0.03, 0.2 + int(i / 4.0) * 0.7 + (i % 2) * 0.2), Vector3(0.16, 0.02, 0.1), _moss)
	TownParts.box(self, "DustRug", Vector3(0.2, 0.02, 0.4), Vector3(2.4, 0.02, 2.0), _dark)


## The imported 2D house: desk, table, chairs, bed, chest, shelf, and the ledger
## book, all dressed with the source game's pixel art. The furniture is drawn as
## upright billboards so the 2D cutouts read correctly from any angle, while the
## room shell around them stays 3D. See the AGENTS.md decision log.
func _hollow_house() -> void:
	# Hearth against the back wall.
	_sprite_prop(SPRITE_FIREPLACE, Vector3(0.0, 0.0, -_half.y + 0.5), 1.55)
	TownParts.collision(self, Vector3(1.45, 1.25, 0.45), Vector3(0.0, 0.62, -_half.y + 0.5))

	# Writing desk in the back-left corner, with Rowan's ledger open on it.
	_sprite_prop(SPRITE_DESK, Vector3(-1.95, 0.0, -2.0), 1.0)
	TownParts.collision(self, Vector3(1.45, 0.9, 0.7), Vector3(-1.95, 0.45, -2.0))
	_sprite_prop(SPRITE_CHAIR, Vector3(-1.95, 0.0, -1.1), 0.95)
	TownParts.collision(self, Vector3(0.55, 0.8, 0.5), Vector3(-1.95, 0.4, -1.1))

	var ledger := LEDGER_BOOK.instantiate() as Node3D
	ledger.name = "LedgerBook"
	ledger.position = Vector3(-1.95, 0.95, -1.98)
	add_child(ledger)

	# Bed along the east wall.
	_sprite_prop(SPRITE_BED, Vector3(2.55, 0.0, -1.6), 1.05)
	TownParts.collision(self, Vector3(1.05, 0.6, 1.9), Vector3(2.55, 0.3, -1.6))
	_bed_body(Vector3(2.55, 0.0, -1.6), Vector3(1.15, 0.9, 2.0))

	# Shelf on the east wall.
	_sprite_prop(SPRITE_SHELF, Vector3(2.9, 0.0, 0.7), 1.3)
	TownParts.collision(self, Vector3(1.3, 1.3, 0.45), Vector3(2.9, 0.65, 0.7))

	# Table and two chairs in the middle of the room.
	_sprite_prop(SPRITE_TABLE, Vector3(0.1, 0.0, 0.85), 0.85)
	TownParts.collision(self, Vector3(1.5, 0.8, 0.9), Vector3(0.1, 0.4, 0.85))
	for z in [-0.1, 1.8]:
		_sprite_prop(SPRITE_CHAIR, Vector3(0.1, 0.0, z), 0.95)
		TownParts.collision(self, Vector3(0.55, 0.8, 0.5), Vector3(0.1, 0.4, z))

	TownParts.box(self, "Rug", Vector3(0.1, 0.02, 0.85), Vector3(2.7, 0.03, 2.2), _cloth)

	# The chest by the door, holding the Sporebread Auntie Bell asks for.
	var chest := CHEST.instantiate() as Node3D
	chest.name = "Chest"
	chest.position = Vector3(-2.7, 0.0, 1.7)
	chest.rotation.y = deg_to_rad(24.0)
	chest.set("save_id", &"chest.hollow_house.sporebread")
	chest.set("loot_id", &"item.sporebread")
	chest.set("use_sprite", true)
	add_child(chest)


## Rowan's house: a front hall, a spine corridor, a dining room to the west, and
## a bedroom and study to the east. Bigger inside than the imported cottage, so
## the keeper of records has a table to work at, a hearth to eat by, and a small
## room set aside for the desk and the ledger.
##
## Built for `room_size` 13 x 9.5. The partition doorways are absolute
## coordinates; keep them in step with the furniture below if the size changes.
func _rowan_manor() -> void:
	_partition_z(2.0, -_half.x, _half.x, [0.0])           # hall / back half
	_partition_x(-0.8, -_half.y, 2.0, [0.6])              # dining / corridor
	_partition_x(0.8, -_half.y, 2.0, [-3.2, 0.2])         # corridor / east rooms
	_partition_z(-1.6, 0.8, _half.x, [])                  # bedroom / study

	# --- front hall -------------------------------------------------------
	TownParts.box(self, "HallRug", Vector3(0.0, 0.02, 3.3), Vector3(1.5, 0.03, 1.6), _cloth)
	# A settle bench along the east wall.
	TownParts.box(self, "Bench", Vector3(_half.x - 0.5, 0.45, 3.0), Vector3(0.55, 0.1, 1.8), _plank)
	for i in 3:
		TownParts.box(self, "BenchLeg", Vector3(_half.x - 0.5, 0.22, 2.3 + i * 0.7), Vector3(0.5, 0.45, 0.1), _timber)
	TownParts.collision(self, Vector3(0.6, 0.5, 1.9), Vector3(_half.x - 0.5, 0.25, 3.0))
	# A little table by the west wall, with a bowl for keys.
	_sprite_prop(SPRITE_TABLE, Vector3(-_half.x + 0.85, 0.0, 3.4), 0.85)
	TownParts.collision(self, Vector3(1.0, 0.8, 0.8), Vector3(-_half.x + 0.85, 0.4, 3.4))
	TownParts.cylinder(self, "KeyBowl", Vector3(-_half.x + 0.85, 0.9, 3.4), 0.16, 0.12, 0.1, _honey, Vector3.ZERO, 8)
	# Coat pegs either side of the door.
	for i in 3:
		TownParts.box(self, "CoatPeg", Vector3(-1.9 + i * 0.35, 1.78, _half.y - 0.16), Vector3(0.06, 0.06, 0.18), _timber)
		TownParts.box(
			self, "Coat", Vector3(-1.9 + i * 0.35, 1.36, _half.y - 0.22),
			Vector3(0.3, 0.72, 0.1), _cloth if i % 2 == 0 else _linen
		)

	# --- dining room (west) -----------------------------------------------
	_sprite_prop(SPRITE_FIREPLACE, Vector3(-_half.x + 0.35, 0.0, -2.6), 1.6)
	TownParts.collision(self, Vector3(0.55, 1.3, 1.6), Vector3(-_half.x + 0.35, 0.65, -2.6))

	var table := Vector3(-3.6, 0.0, -1.0)
	TownParts.box(self, "TableTop", Vector3(table.x, 0.78, table.z), Vector3(2.4, 0.1, 1.2), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(
				self, "TableLeg", Vector3(table.x + sx * 1.05, 0.39, table.z + sz * 0.45),
				Vector3(0.1, 0.78, 0.1), _timber
			)
	TownParts.collision(self, Vector3(2.5, 0.9, 1.3), Vector3(table.x, 0.45, table.z))
	# Four chairs, two on each long side.
	for x in [-4.4, -2.8]:
		for z in [-1.85, 0.15]:
			_sprite_prop(SPRITE_CHAIR, Vector3(x, 0.0, z), 0.95)
			TownParts.collision(self, Vector3(0.55, 0.8, 0.5), Vector3(x, 0.4, z))
	TownParts.box(self, "Rug", Vector3(table.x, 0.02, table.z), Vector3(3.0, 0.03, 2.4), _cloth)
	# Sideboard along the quiet stretch of the west wall.
	_sprite_prop(SPRITE_SHELF, Vector3(-_half.x + 0.35, 0.0, 0.9), 1.35)
	TownParts.collision(self, Vector3(0.6, 1.4, 1.4), Vector3(-_half.x + 0.35, 0.7, 0.9))
	# Crockery shelf on the back wall, clear of the window.
	_sprite_prop(SPRITE_SHELF, Vector3(-5.3, 0.0, -_half.y + 0.3), 1.3)
	TownParts.collision(self, Vector3(1.4, 1.3, 0.5), Vector3(-5.3, 0.65, -_half.y + 0.3))

	# --- bedroom (east, front) --------------------------------------------
	_sprite_prop(SPRITE_BED, Vector3(_half.x - 0.75, 0.0, 0.3), 1.1)
	TownParts.collision(self, Vector3(1.05, 0.6, 1.95), Vector3(_half.x - 0.75, 0.3, 0.3))
	_bed_body(Vector3(_half.x - 0.75, 0.0, 0.3), Vector3(1.15, 0.9, 2.05))
	for x in [2.1, 3.6]:
		_sprite_prop(SPRITE_SHELF, Vector3(x, 0.0, -1.35), 1.3)
		TownParts.collision(self, Vector3(1.4, 1.3, 0.5), Vector3(x, 0.65, -1.35))
	TownParts.cylinder(self, "Washstand", Vector3(1.6, 0.35, 1.4), 0.28, 0.22, 0.7, _timber, Vector3.ZERO, 8)
	TownParts.cylinder(self, "WashBowl", Vector3(1.6, 0.75, 1.4), 0.24, 0.16, 0.12, _linen, Vector3.ZERO, 8)
	TownParts.collision(self, Vector3(0.6, 0.8, 0.6), Vector3(1.6, 0.4, 1.4))
	TownParts.box(self, "BedroomRug", Vector3(3.8, 0.02, 1.0), Vector3(2.0, 0.03, 1.4), _cloth)

	# --- study (east, back): the desk, the chair, and the ledger ----------
	_sprite_prop(SPRITE_DESK, Vector3(4.5, 0.0, -_half.y + 0.7), 1.0)
	TownParts.collision(self, Vector3(1.45, 0.9, 0.7), Vector3(4.5, 0.45, -_half.y + 0.7))
	_sprite_prop(SPRITE_CHAIR, Vector3(4.5, 0.0, -3.3), 0.95)
	TownParts.collision(self, Vector3(0.55, 0.8, 0.5), Vector3(4.5, 0.4, -3.3))

	var ledger := LEDGER_BOOK.instantiate() as Node3D
	ledger.name = "LedgerBook"
	ledger.position = Vector3(4.5, 0.95, -_half.y + 0.72)
	ledger.rotation.y = deg_to_rad(-24.0)
	add_child(ledger)

	_sprite_prop(SPRITE_SHELF, Vector3(_half.x - 0.55, 0.0, -2.4), 1.35)
	TownParts.collision(self, Vector3(0.6, 1.4, 1.4), Vector3(_half.x - 0.55, 0.7, -2.4))

	# The chest holding the Sporebread Auntie Bell asks for.
	var chest := CHEST.instantiate() as Node3D
	chest.name = "SporebreadChest"
	chest.position = Vector3(1.7, 0.0, -_half.y + 0.65)
	chest.rotation.y = deg_to_rad(18.0)
	chest.set("save_id", &"chest.rowans_house.sporebread")
	chest.set("loot_id", &"item.sporebread")
	chest.set("use_sprite", true)
	add_child(chest)

	TownParts.box(self, "StudyRug", Vector3(3.4, 0.02, -2.4), Vector3(2.6, 0.03, 1.6), _cloth)
	# Records shelved above the chest, on the stretch of wall clear of a window.
	TownParts.box(self, "RecordShelf", Vector3(3.6, 1.5, -_half.y + 0.28), Vector3(2.0, 0.06, 0.34), _plank)
	for j in 5:
		TownParts.box(
			self, "Record", Vector3(2.8 + j * 0.38, 1.66, -_half.y + 0.28),
			Vector3(0.22, 0.28, 0.3), _cloth if j % 2 == 0 else _linen
		)

	# One lamp for each room the shell lights do not reach.
	_lamp("DiningLamp", Vector3(-3.6, 2.45, -1.0), Color(1.0, 0.78, 0.5), 1.0, 7.0, false)
	_lamp("BedroomLamp", Vector3(3.6, 2.45, 0.4), Color(1.0, 0.82, 0.58), 0.9, 6.0, false)
	_lamp("StudyLamp", Vector3(3.4, 2.45, -3.0), Color(1.0, 0.82, 0.58), 0.9, 6.0, false)


## Auntie Bell's bakery and home: a long counter across the north wall with her
## working side behind it, café tables on the shop floor, a lounge by the hearth,
## and a private bedroom and store room walled off in the north-east corner. The
## private room is only reachable through the service aisle behind the counter,
## which is how the shop keeps customers out.
##
## Built for `room_size` 14 x 10.
func _bakery_cafe() -> void:
	_partition_x(3.2, -_half.y, -1.2, [-3.4])
	_partition_z(-1.2, 3.2, _half.x, [])
	TownParts.box(self, "StaffSign", Vector3(3.9, 2.45, -1.13), Vector3(0.8, 0.28, 0.05), _plank)

	# --- the bar ----------------------------------------------------------
	var bar := Vector3(-1.3, 0.0, -2.7)
	TownParts.box(self, "CounterBody", Vector3(bar.x, 0.48, bar.z), Vector3(6.6, 0.96, 0.8), _timber)
	TownParts.box(self, "CounterTop", Vector3(bar.x, 1.0, bar.z), Vector3(6.9, 0.12, 0.95), _plank)
	TownParts.collision(self, Vector3(6.9, 1.1, 0.95), Vector3(bar.x, 0.55, bar.z))
	for i in 4:
		TownParts.box(self, "Panel", Vector3(-3.4 + i * 1.35, 0.5, bar.z + 0.42), Vector3(1.1, 0.8, 0.05), _plank)
	TownParts.box(self, "FootRail", Vector3(bar.x, 0.18, bar.z + 0.55), Vector3(6.4, 0.06, 0.06), _honey)

	# Pastry trays on cake stands, and a till and bell on the counter.
	for i in 3:
		var x := -3.6 + i * 1.5
		TownParts.box(self, "Tray", Vector3(x, 1.08, bar.z - 0.1), Vector3(0.9, 0.04, 0.5), _stone)
		TownParts.cylinder(self, "CakeStand", Vector3(x, 1.14, bar.z - 0.1), 0.22, 0.16, 0.1, _linen, Vector3.ZERO, 10)
		for j in 3:
			TownParts.sphere(self, "Pastry", Vector3(x - 0.15 + j * 0.15, 1.22, bar.z - 0.1), 0.08, 0.14, _bread)
	TownParts.box(self, "Till", Vector3(1.1, 1.18, bar.z), Vector3(0.5, 0.3, 0.5), _timber)
	TownParts.sphere(self, "ServiceBell", Vector3(1.9, 1.12, bar.z), 0.09, 0.16, _honey)

	# --- behind the bar ---------------------------------------------------
	for i in 3:
		var y := 1.45 + i * 0.45
		TownParts.box(self, "BackShelf", Vector3(-1.3, y, -_half.y + 0.35), Vector3(6.2, 0.06, 0.34), _plank)
		for j in 9:
			var x := -4.1 + j * 0.7
			TownParts.cylinder(self, "Jar", Vector3(x, y + 0.16, -_half.y + 0.35), 0.09, 0.09, 0.26, _honey, Vector3.ZERO, 6)

	# Stone oven in the north-west corner, mouth facing the bar.
	TownParts.box(self, "Oven", Vector3(-5.9, 0.95, -4.15), Vector3(1.8, 1.9, 1.3), _stone)
	TownParts.box(self, "OvenTop", Vector3(-5.9, 1.94, -4.15), Vector3(1.95, 0.1, 1.45), _stone)
	TownParts.box(self, "OvenHood", Vector3(-5.9, 2.4, -4.25), Vector3(1.5, 0.9, 1.0), _stone)
	TownParts.box(self, "OvenMouth", Vector3(-5.9, 0.8, -3.5), Vector3(0.9, 0.55, 0.06), _dark)
	TownParts.box(self, "OvenFire", Vector3(-5.9, 0.72, -3.48), Vector3(0.7, 0.32, 0.05), _glass)
	TownParts.collision(self, Vector3(1.85, 1.95, 1.35), Vector3(-5.9, 0.98, -4.15))

	# Prep table and flour sacks on Bell's side.
	TownParts.box(self, "PrepTop", Vector3(0.9, 0.8, -4.15), Vector3(2.0, 0.1, 0.85), _plank)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			TownParts.box(self, "PrepLeg", Vector3(0.9 + sx * 0.85, 0.4, -4.15 + sz * 0.3), Vector3(0.1, 0.8, 0.1), _timber)
	TownParts.collision(self, Vector3(2.1, 0.9, 0.95), Vector3(0.9, 0.45, -4.15))
	for i in 3:
		TownParts.sphere(self, "FlourSack", Vector3(-3.6 + i * 0.55, 0.28, -4.2 + (i % 2) * 0.35), 0.3, 0.55, _linen)
	TownParts.cylinder(self, "MixingBowl", Vector3(1.5, 0.9, -4.15), 0.26, 0.16, 0.2, _linen, Vector3.ZERO, 8)

	# Herb bundles hanging above the bar.
	for i in 4:
		var x := -4.0 + i * 2.0
		TownParts.box(self, "HerbString", Vector3(x, 2.6, -2.7), Vector3(0.03, 0.3, 0.03), _dark)
		TownParts.cone(self, "Herbs", Vector3(x, 2.38, -2.7), 0.15, 0.26, _moss, 5)

	# --- café floor -------------------------------------------------------
	_cafe_table(Vector2(-4.9, -0.4))
	_cafe_table(Vector2(-2.1, -0.4))
	_cafe_table(Vector2(-4.9, 2.2))
	_cafe_table(Vector2(-2.1, 2.2))

	# --- lounge (east) ----------------------------------------------------
	_sprite_prop(SPRITE_FIREPLACE, Vector3(_half.x - 0.4, 0.0, 0.6), 1.55)
	TownParts.collision(self, Vector3(0.55, 1.25, 1.5), Vector3(_half.x - 0.4, 0.62, 0.6))
	_cafe_table(Vector2(4.9, 2.8))
	TownParts.box(self, "LoungeRug", Vector3(4.6, 0.02, 1.0), Vector3(2.6, 0.03, 2.0), _cloth)
	# Potted plant by the front wall.
	TownParts.cylinder(self, "PlantPot", Vector3(_half.x - 0.8, 0.28, _half.y - 0.8), 0.28, 0.22, 0.55, _bread, Vector3.ZERO, 8)
	TownParts.sphere(self, "Plant", Vector3(_half.x - 0.8, 0.95, _half.y - 0.8), 0.4, 0.8, _moss)
	TownParts.collision(self, Vector3(0.6, 1.0, 0.6), Vector3(_half.x - 0.8, 0.5, _half.y - 0.8))

	# --- private bedroom and store room -----------------------------------
	_sprite_prop(SPRITE_BED, Vector3(_half.x - 0.85, 0.0, -3.5), 1.1)
	TownParts.collision(self, Vector3(1.05, 0.6, 1.95), Vector3(_half.x - 0.85, 0.3, -3.5))
	_bed_body(Vector3(_half.x - 0.85, 0.0, -3.5), Vector3(1.15, 0.9, 2.05))
	_sprite_prop(SPRITE_SHELF, Vector3(4.2, 0.0, -_half.y + 0.35), 1.3)
	TownParts.collision(self, Vector3(1.4, 1.3, 0.5), Vector3(4.2, 0.65, -_half.y + 0.35))
	TownParts.box(self, "StorageCrate", Vector3(4.1, 0.3, -1.8), Vector3(0.8, 0.6, 0.8), _timber)
	TownParts.box(self, "StorageCrateB", Vector3(4.1, 0.75, -1.8), Vector3(0.6, 0.3, 0.6), _plank)
	TownParts.collision(self, Vector3(0.9, 0.9, 0.9), Vector3(4.1, 0.45, -1.8))
	TownParts.cylinder(self, "WashTub", Vector3(5.6, 0.3, -1.7), 0.3, 0.26, 0.6, _timber, Vector3.ZERO, 10)

	# Extra light so the deep room is not a cave.
	_lamp("CafeLamp", Vector3(-3.4, 2.5, 1.0), Color(1.0, 0.82, 0.58), 1.1, 8.0, false)
	_lamp("LoungeLamp", Vector3(5.0, 2.5, 1.6), Color(1.0, 0.78, 0.5), 0.9, 6.5, false)
	_lamp("PrivateLamp", Vector3(5.1, 2.4, -3.1), Color(1.0, 0.7, 0.42), 0.8, 4.5, false)


## One café table with two chairs, drawn with the imported 2D furniture art, plus
## a mug and a plate so the table looks used.
func _cafe_table(at: Vector2) -> void:
	_sprite_prop(SPRITE_TABLE, Vector3(at.x, 0.0, at.y), 0.85)
	TownParts.collision(self, Vector3(1.4, 0.8, 0.95), Vector3(at.x, 0.4, at.y))
	for dz in [-0.95, 0.95]:
		_sprite_prop(SPRITE_CHAIR, Vector3(at.x, 0.0, at.y + dz), 0.95)
		TownParts.collision(self, Vector3(0.55, 0.8, 0.5), Vector3(at.x, 0.4, at.y + dz))
	TownParts.cylinder(self, "Mug", Vector3(at.x + 0.2, 0.8, at.y - 0.12), 0.06, 0.06, 0.12, _honey, Vector3.ZERO, 6)
	TownParts.cylinder(self, "Plate", Vector3(at.x - 0.22, 0.79, at.y + 0.18), 0.14, 0.14, 0.03, _linen, Vector3.ZERO, 10)


## One upright billboard of 2D furniture art. `height` is the drawn size in
## metres; the sprite's pixel size is derived from the texture so every prop keeps
## its own aspect ratio. Upright (`BILLBOARD_FIXED_Y`) rather than full billboard,
## so furniture does not lean over when the camera looks down.
func _sprite_prop(texture: Texture2D, at: Vector3, height: float) -> Sprite3D:
	if texture == null:
		return null

	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	sprite.pixel_size = height / float(maxi(texture.get_height(), 1))
	sprite.position = at + Vector3(0.0, height * 0.5, 0.0)
	add_child(sprite)
	return sprite


## Places a usable sleep body over a bed. The room's bed is scenery plus a solid
## collider; this invisible `Bed` sits a few centimetres proud of that collider
## so the interaction ray resolves to "Sleep" instead of the wall behind.
func _bed_body(at: Vector3, footprint: Vector3) -> void:
	var bed := BED_SCENE.instantiate() as StaticBody3D
	bed.name = "Bed"
	bed.position = at

	var shape := bed.get_node_or_null("Collision") as CollisionShape3D
	if shape != null:
		var box := BoxShape3D.new()
		box.size = footprint
		shape.shape = box
		shape.position = Vector3(0.0, footprint.y * 0.5, 0.0)

	add_child(bed)


# --- lights and exit -------------------------------------------------------


func _lights() -> void:
	var reach := maxf(6.0, room_size.length() * 0.75)
	_lamp("HearthLight", Vector3(-_half.x * 0.55, 1.1, -_half.y * 0.4), Color(1.0, 0.55, 0.25), 1.8, reach * 0.8, true)
	_lamp("RoomLight", Vector3(0.0, wall_height - 0.3, _half.y * 0.1), Color(1.0, 0.84, 0.62), 1.6, reach, true)
	_lamp("DoorLight", Vector3(0.0, 2.2, _half.y - 0.9), Color(1.0, 0.78, 0.5), 0.9, 4.0, false)


func _lamp(node_name: String, at: Vector3, colour: Color, energy: float, reach: float, shadows: bool) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = shadows
	add_child(light)


func _exit_door() -> void:
	var exit := Area3D.new()
	exit.name = "ExitDoor"
	exit.position = Vector3(0, 1.2, _half.y - 0.4)
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.set_script(EXIT_SCRIPT)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_WIDTH + 0.2, 2.2, 0.9)
	shape.shape = box
	exit.add_child(shape)
	add_child(exit)
