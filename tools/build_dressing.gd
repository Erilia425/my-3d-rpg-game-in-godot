extends SceneTree
## One-off generator for `features/world/dressing/cottage_dressing.tscn`.
##
## Run headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/build_dressing.gd
## Then delete `tools/`. Everything here is decorative: it adds no collision, so
## the room's tests and its enemy path are untouched.

const OUT_PATH := "res://features/world/dressing/cottage_dressing.tscn"

var _root: Node3D


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "CottageDressing"

	_floor()
	_ceiling()
	_walls()
	_hearth()
	_bed()
	_table()
	_seating()
	_shelf()
	_rug()
	_herbs()
	_mushrooms()
	_storage()
	_windows()
	_lights()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var packed := PackedScene.new()
	var error := packed.pack(_root)
	if error == OK:
		error = ResourceSaver.save(packed, OUT_PATH)
	print("build_dressing: saved=%s error=%d" % [OUT_PATH, error])
	_root.free()
	quit()


# --- room dressing ---------------------------------------------------------


func _floor() -> void:
	var floor_group := _group("FloorPlanks")
	for i in 11:
		var z := -10.8 + i * 2.0
		var tone := Color(0.37, 0.26, 0.15, 1) if i % 2 == 0 else Color(0.32, 0.22, 0.13, 1)
		_box(floor_group, "Plank%d" % i, Vector3(0, 0.03, z), Vector3(24, 0.06, 1.94), tone)


func _ceiling() -> void:
	var ceiling := _group("Ceiling")
	_box(ceiling, "Thatch", Vector3(0, 4.15, 0), Vector3(24.4, 0.3, 24.4), Color(0.24, 0.18, 0.11, 1))
	for i in 5:
		var z := -8.0 + i * 4.0
		_box(ceiling, "Beam%d" % i, Vector3(0, 3.92, z), Vector3(24.2, 0.26, 0.36), Color(0.19, 0.12, 0.07, 1))
	for i in 4:
		var x := -7.5 + i * 5.0
		_box(ceiling, "Rafter%d" % i, Vector3(x, 3.95, 0), Vector3(0.3, 0.22, 24.2), Color(0.2, 0.13, 0.08, 1))


func _walls() -> void:
	var walls := _group("Walls")
	var daub := Color(0.73, 0.67, 0.53, 1)
	var plaster := Color(0.66, 0.6, 0.46, 1)
	var timber := Color(0.24, 0.15, 0.09, 1)
	var stone := Color(0.42, 0.41, 0.38, 1)

	# Inner daub panels, inset 0.2 m from the collision walls.
	_box(walls, "DaubFront", Vector3(0, 2.05, 11.7), Vector3(23.5, 3.5, 0.14), daub)
	_box(walls, "DaubLeft", Vector3(-11.7, 2.05, 0), Vector3(0.14, 3.5, 23.5), plaster)
	_box(walls, "DaubRight", Vector3(11.7, 2.05, 0), Vector3(0.14, 3.5, 23.5), plaster)
	_box(walls, "DaubBackLeft", Vector3(-6.7, 2.05, -11.7), Vector3(10.4, 3.5, 0.14), daub)
	_box(walls, "DaubBackRight", Vector3(6.7, 2.05, -11.7), Vector3(10.4, 3.5, 0.14), daub)

	# Stone plinth at the foot of every wall.
	_box(walls, "PlinthFront", Vector3(0, 0.25, 11.55), Vector3(23.8, 0.5, 0.4), stone)
	_box(walls, "PlinthLeft", Vector3(-11.55, 0.25, 0), Vector3(0.4, 0.5, 23.8), stone)
	_box(walls, "PlinthRight", Vector3(11.55, 0.25, 0), Vector3(0.4, 0.5, 23.8), stone)
	_box(walls, "PlinthBack", Vector3(0, 0.25, -11.55), Vector3(23.8, 0.5, 0.4), stone)

	# Timber posts and rails on all four walls.
	for i in 6:
		var x := -10.5 + i * 4.2
		_box(walls, "PostFront%d" % i, Vector3(x, 2.0, 11.62), Vector3(0.28, 3.6, 0.28), timber)
		_box(walls, "PostBack%d" % i, Vector3(x, 2.0, -11.62), Vector3(0.28, 3.6, 0.28), timber)
	for i in 6:
		var z := -10.5 + i * 4.2
		_box(walls, "PostLeft%d" % i, Vector3(-11.62, 2.0, z), Vector3(0.28, 3.6, 0.28), timber)
		_box(walls, "PostRight%d" % i, Vector3(11.62, 2.0, z), Vector3(0.28, 3.6, 0.28), timber)

	_box(walls, "RailFrontLow", Vector3(0, 0.95, 11.6), Vector3(23.4, 0.2, 0.2), timber)
	_box(walls, "RailFrontHigh", Vector3(0, 2.95, 11.6), Vector3(23.4, 0.2, 0.2), timber)
	_box(walls, "RailBackLow", Vector3(0, 0.95, -11.6), Vector3(23.4, 0.2, 0.2), timber)
	_box(walls, "RailBackHigh", Vector3(0, 2.95, -11.6), Vector3(23.4, 0.2, 0.2), timber)
	_box(walls, "RailLeftLow", Vector3(-11.6, 0.95, 0), Vector3(0.2, 0.2, 23.4), timber)
	_box(walls, "RailLeftHigh", Vector3(-11.6, 2.95, 0), Vector3(0.2, 0.2, 23.4), timber)
	_box(walls, "RailRightLow", Vector3(11.6, 0.95, 0), Vector3(0.2, 0.2, 23.4), timber)
	_box(walls, "RailRightHigh", Vector3(11.6, 2.95, 0), Vector3(0.2, 0.2, 23.4), timber)

	# Door frame around the back-door gap (x -1.4 .. 1.4).
	_box(walls, "DoorFrameLeft", Vector3(-1.55, 1.9, -11.6), Vector3(0.3, 3.8, 0.3), timber)
	_box(walls, "DoorFrameRight", Vector3(1.55, 1.9, -11.6), Vector3(0.3, 3.8, 0.3), timber)
	_box(walls, "DoorFrameTop", Vector3(0, 3.65, -11.6), Vector3(3.4, 0.3, 0.3), timber)


func _hearth() -> void:
	var hearth := _group("Hearth")
	var stone := Color(0.46, 0.45, 0.42, 1)
	var soot := Color(0.08, 0.07, 0.06, 1)

	_box(hearth, "ChimneyBreast", Vector3(-11.1, 1.85, -3), Vector3(1.3, 3.7, 3.4), stone)
	_box(hearth, "Firebox", Vector3(-10.4, 0.85, -3), Vector3(0.3, 1.3, 2.1), soot)
	_box(hearth, "HearthStone", Vector3(-10.8, 0.07, -3), Vector3(1.8, 0.1, 3.8), Color(0.38, 0.37, 0.35, 1))
	_box(hearth, "Mantel", Vector3(-10.95, 2.45, -3), Vector3(1.5, 0.22, 3.6), Color(0.26, 0.17, 0.1, 1))
	_box(hearth, "Embers", Vector3(-10.35, 0.2, -3), Vector3(0.14, 0.14, 1.5), Color(1, 0.42, 0.12, 1), 2.6)
	_cylinder(hearth, "LogA", Vector3(-10.25, 0.18, -3.2), 0.13, 0.13, 1.3, Color(0.22, 0.14, 0.09, 1), Vector3(deg_to_rad(90), 0, 0))
	_cylinder(hearth, "LogB", Vector3(-10.2, 0.32, -2.8), 0.12, 0.12, 1.1, Color(0.19, 0.12, 0.08, 1), Vector3(deg_to_rad(90), 0, 0))

	# Firewood beside the hearth.
	for i in 4:
		_cylinder(
			hearth, "Firewood%d" % i,
			Vector3(-10.9, 0.16 + (i % 2) * 0.22, -5.6 + (i / 2) * 0.32),
			0.13, 0.13, 1.4, Color(0.25, 0.16, 0.1, 1), Vector3(0, 0, deg_to_rad(90))
		)


func _bed() -> void:
	var bed := _group("Bed")
	var wood := Color(0.3, 0.2, 0.12, 1)
	_box(bed, "Frame", Vector3(9.6, 0.25, -9.2), Vector3(2.3, 0.3, 3.0), wood)
	_box(bed, "LegFL", Vector3(8.55, 0.15, -7.8), Vector3(0.16, 0.3, 0.16), wood)
	_box(bed, "LegFR", Vector3(10.65, 0.15, -7.8), Vector3(0.16, 0.3, 0.16), wood)
	_box(bed, "Mattress", Vector3(9.6, 0.55, -9.2), Vector3(2.1, 0.32, 2.8), Color(0.82, 0.78, 0.66, 1))
	_box(bed, "Blanket", Vector3(9.6, 0.74, -8.55), Vector3(2.12, 0.14, 1.6), Color(0.5, 0.24, 0.2, 1))
	_box(bed, "Pillow", Vector3(9.6, 0.76, -10.2), Vector3(1.5, 0.22, 0.6), Color(0.9, 0.87, 0.78, 1))
	_box(bed, "Headboard", Vector3(9.6, 1.0, -10.75), Vector3(2.4, 1.0, 0.16), wood)


func _table() -> void:
	var table := _group("Table")
	var wood := Color(0.35, 0.23, 0.13, 1)
	_box(table, "Top", Vector3(-8.4, 0.87, 6.0), Vector3(2.4, 0.14, 1.3), wood)
	for i in 4:
		var dx := -1.0 if i % 2 == 0 else 1.0
		var dz := -0.5 if i < 2 else 0.5
		_box(table, "Leg%d" % i, Vector3(-8.4 + dx, 0.42, 6.0 + dz), Vector3(0.14, 0.84, 0.14), Color(0.27, 0.17, 0.1, 1))
	_box(table, "StoolA", Vector3(-7.0, 0.45, 6.4), Vector3(0.55, 0.1, 0.55), wood)
	_box(table, "StoolALeg", Vector3(-7.0, 0.22, 6.4), Vector3(0.4, 0.44, 0.4), Color(0.27, 0.17, 0.1, 1))
	_box(table, "StoolB", Vector3(-9.8, 0.45, 5.4), Vector3(0.55, 0.1, 0.55), wood)
	_box(table, "StoolBLeg", Vector3(-9.8, 0.22, 5.4), Vector3(0.4, 0.44, 0.4), Color(0.27, 0.17, 0.1, 1))

	# Bowl, mug, and a candle on the table.
	_cylinder(table, "Bowl", Vector3(-8.6, 0.98, 5.9), 0.26, 0.18, 0.16, Color(0.62, 0.55, 0.42, 1))
	_cylinder(table, "Mug", Vector3(-8.0, 1.02, 6.2), 0.11, 0.1, 0.22, Color(0.42, 0.3, 0.2, 1))
	_cylinder(table, "Candle", Vector3(-8.9, 1.02, 6.3), 0.06, 0.06, 0.3, Color(0.92, 0.88, 0.76, 1))
	_sphere(table, "Flame", Vector3(-8.9, 1.22, 6.3), 0.07, 0.14, Color(1, 0.75, 0.35, 1), 3.0)


func _seating() -> void:
	# Two worn armchairs and a side table facing the hearth: the room's sitting
	# corner. Decorative only, like the rest of the dressing, so it adds no
	# collision and cannot block the room's enemy or the walk tests.
	var seating := _group("Seating")
	var frame := Color(0.34, 0.22, 0.13, 1)
	var cushion_colours: Array[Color] = [
		Color(0.56, 0.42, 0.44, 1),
		Color(0.45, 0.48, 0.34, 1),
	]

	for i in 2:
		var z: float = -1.4 - i * 3.2
		var cushion: Color = cushion_colours[i]
		_box(seating, "Seat%d" % i, Vector3(-8.2, 0.42, z), Vector3(0.9, 0.2, 0.85), frame)
		_box(seating, "Back%d" % i, Vector3(-7.8, 0.82, z), Vector3(0.18, 0.85, 0.85), frame)
		for side in [-1.0, 1.0]:
			_box(seating, "Arm%d_%d" % [i, int(side)], Vector3(-8.2, 0.62, z + side * 0.42), Vector3(0.8, 0.28, 0.12), frame)
			for end in [-1.0, 1.0]:
				_box(
					seating, "Leg%d_%d_%d" % [i, int(side), int(end)],
					Vector3(-8.2 + end * 0.34, 0.16, z + side * 0.34),
					Vector3(0.1, 0.32, 0.1), Color(0.26, 0.16, 0.1, 1)
				)
		_box(seating, "Cushion%d" % i, Vector3(-8.24, 0.56, z), Vector3(0.72, 0.14, 0.68), cushion)

	# Low round table between the chairs, with a mug and a closed book.
	_cylinder(seating, "SideTableTop", Vector3(-8.65, 0.53, -3.0), 0.36, 0.34, 0.07, frame)
	_cylinder(seating, "SideTableLeg", Vector3(-8.65, 0.27, -3.0), 0.07, 0.07, 0.5, Color(0.27, 0.17, 0.1, 1))
	_cylinder(seating, "SideTableBase", Vector3(-8.65, 0.04, -3.0), 0.24, 0.24, 0.06, Color(0.27, 0.17, 0.1, 1))
	_cylinder(seating, "SideMug", Vector3(-8.55, 0.66, -2.92), 0.09, 0.08, 0.18, Color(0.62, 0.5, 0.32, 1))
	_box(seating, "Book", Vector3(-8.8, 0.59, -3.1), Vector3(0.24, 0.05, 0.17), Color(0.4, 0.24, 0.22, 1))

	# Footstool in front of the far chair.
	_box(seating, "Footstool", Vector3(-9.3, 0.24, -4.6), Vector3(0.58, 0.18, 0.46), frame)
	_box(seating, "FootstoolPad", Vector3(-9.3, 0.35, -4.6), Vector3(0.52, 0.1, 0.4), cushion_colours[1])

	# A second, smaller rug ties the group together.
	_box(seating, "HearthRug", Vector3(-8.6, 0.065, -3.0), Vector3(3.2, 0.03, 3.6), Color(0.45, 0.3, 0.26, 1))
	_box(seating, "HearthRugBorder", Vector3(-8.6, 0.07, -3.0), Vector3(2.8, 0.03, 3.2), Color(0.58, 0.45, 0.3, 1))


func _shelf() -> void:
	var shelf := _group("Shelf")
	var wood := Color(0.32, 0.21, 0.12, 1)
	var jars := [
		Color(0.42, 0.55, 0.34, 1), Color(0.75, 0.62, 0.28, 1), Color(0.55, 0.35, 0.4, 1),
		Color(0.35, 0.45, 0.5, 1), Color(0.6, 0.48, 0.3, 1), Color(0.45, 0.5, 0.32, 1),
	]

	for i in 3:
		var y := 1.15 + i * 0.62
		_box(shelf, "Board%d" % i, Vector3(11.45, y, 2.0), Vector3(0.55, 0.1, 3.6), wood)
		for j in 3:
			var jar: Color = jars[(i * 3 + j) % jars.size()]
			_cylinder(
				shelf, "Jar%d%d" % [i, j],
				Vector3(11.45, y + 0.22, 0.9 + j * 1.0),
				0.13, 0.13, 0.34, jar
			)
			_cylinder(shelf, "Lid%d%d" % [i, j], Vector3(11.45, y + 0.4, 0.9 + j * 1.0), 0.1, 0.13, 0.06, Color(0.3, 0.22, 0.15, 1))

	# Two jars on the floor under the shelf, and a basket of teeth by the bed.
	_cylinder(shelf, "FloorJarA", Vector3(11.3, 0.3, -0.4), 0.2, 0.24, 0.6, Color(0.44, 0.5, 0.36, 1))
	_cylinder(shelf, "FloorJarB", Vector3(11.3, 0.24, -1.1), 0.18, 0.2, 0.48, Color(0.7, 0.6, 0.34, 1))
	_basket(shelf, "ToothBasket", Vector3(8.0, 0.22, -6.4))


func _basket(root: Node3D, node_name: String, position: Vector3) -> void:
	_cylinder(root, node_name, position, 0.34, 0.28, 0.42, Color(0.55, 0.4, 0.22, 1))
	_cylinder(root, node_name + "Rim", position + Vector3(0, 0.22, 0), 0.36, 0.34, 0.06, Color(0.45, 0.32, 0.18, 1))


func _rug() -> void:
	var rug := _group("Rug")
	_box(rug, "Wool", Vector3(0, 0.055, 2.6), Vector3(5.0, 0.04, 3.4), Color(0.42, 0.26, 0.24, 1))
	_box(rug, "Border", Vector3(0, 0.06, 2.6), Vector3(4.4, 0.03, 2.8), Color(0.55, 0.42, 0.28, 1))
	_box(rug, "Centre", Vector3(0, 0.065, 2.6), Vector3(3.2, 0.03, 1.8), Color(0.38, 0.32, 0.24, 1))


func _herbs() -> void:
	var herbs := _group("Herbs")
	var colours := [
		Color(0.38, 0.32, 0.2, 1), Color(0.3, 0.34, 0.22, 1), Color(0.4, 0.3, 0.24, 1),
	]
	for i in 5:
		var x := -6.0 + i * 3.0
		_cylinder(herbs, "Stem%d" % i, Vector3(x, 3.35, -4.0), 0.02, 0.02, 0.9, Color(0.35, 0.3, 0.2, 1))
		_cone(herbs, "Bundle%d" % i, Vector3(x, 3.05, -4.0), 0.22, 0.7, colours[i % colours.size()])


func _mushrooms() -> void:
	var mushrooms := _group("Mushrooms")
	var glow := Color(0.62, 1.0, 0.72, 1)
	var spots := [
		Vector3(-9.6, 0.0, -11.3), Vector3(-9.1, 0.0, -11.1), Vector3(-10.2, 0.0, -11.2),
		Vector3(-8.6, 0.0, -11.4), Vector3(-9.9, 0.0, -10.8),
	]
	for i in spots.size():
		var base: Vector3 = spots[i]
		var scale_i := 0.7 + 0.12 * i
		_cylinder(mushrooms, "Stalk%d" % i, base + Vector3(0, 0.09 * scale_i, 0), 0.03, 0.05, 0.18 * scale_i, Color(0.9, 0.88, 0.8, 1))
		_sphere(mushrooms, "Cap%d" % i, base + Vector3(0, 0.2 * scale_i, 0), 0.14 * scale_i, 0.12 * scale_i, glow, 2.2)

	# A second cluster in the front-left corner.
	for i in 3:
		var base := Vector3(-11.0 + i * 0.35, 0.0, 9.9 + i * 0.3)
		_cylinder(mushrooms, "StalkB%d" % i, base + Vector3(0, 0.08, 0), 0.03, 0.05, 0.16, Color(0.9, 0.88, 0.8, 1))
		_sphere(mushrooms, "CapB%d" % i, base + Vector3(0, 0.18, 0), 0.13, 0.11, glow, 2.0)


func _storage() -> void:
	var storage := _group("Storage")
	var barrel := Color(0.34, 0.22, 0.12, 1)
	_cylinder(storage, "BarrelA", Vector3(10.9, 0.42, -2.2), 0.36, 0.36, 0.84, barrel)
	_cylinder(storage, "BarrelABand", Vector3(10.9, 0.42, -2.2), 0.38, 0.38, 0.1, Color(0.25, 0.18, 0.12, 1))
	_cylinder(storage, "BarrelB", Vector3(10.6, 0.36, -1.2), 0.3, 0.3, 0.72, barrel)
	_box(storage, "CrateSmall", Vector3(10.9, 0.35, 8.4), Vector3(0.7, 0.7, 0.7), Color(0.4, 0.27, 0.15, 1))


func _windows() -> void:
	var windows := _group("Windows")
	var frame := Color(0.24, 0.15, 0.09, 1)
	var glass := Color(0.85, 0.9, 0.78, 1)

	# Left wall, in front of and behind the hearth.
	for spot in [Vector3(-11.82, 2.2, -7.4), Vector3(-11.82, 2.2, 4.4)]:
		_box(windows, "GlassL", spot, Vector3(0.08, 1.3, 1.5), glass, 0.7)
		_box(windows, "FrameL", spot, Vector3(0.1, 1.5, 1.7), frame)
		_box(windows, "MullionL", spot + Vector3(0.06, 0, 0), Vector3(0.06, 1.4, 0.09), frame)
		_box(windows, "TransomL", spot + Vector3(0.06, 0, 0), Vector3(0.06, 0.09, 1.5), frame)

	# Right wall, clear of the shelf (z 0.2 .. 3.8) and the bed (z -10.7 .. -7.7).
	for spot in [Vector3(11.82, 2.2, -4.6), Vector3(11.82, 2.2, 6.4)]:
		_box(windows, "GlassR", spot, Vector3(0.08, 1.3, 1.5), glass, 0.7)
		_box(windows, "FrameR", spot, Vector3(0.1, 1.5, 1.7), frame)
		_box(windows, "MullionR", spot - Vector3(0.06, 0, 0), Vector3(0.06, 1.4, 0.09), frame)
		_box(windows, "TransomR", spot - Vector3(0.06, 0, 0), Vector3(0.06, 0.09, 1.5), frame)


func _lights() -> void:
	# Four warm pools and two cool window fills. A 24 m hall needs more than the
	# hearth alone, or the far side of the room reads as a cave.
	_light("HearthLight", Vector3(-9.6, 1.2, -3.0), Color(1, 0.62, 0.32, 1), 2.6, 12.0)
	_light("LanternLight", Vector3(0.0, 3.2, 4.0), Color(1, 0.84, 0.6, 1), 2.4, 13.0)
	_light("TableLight", Vector3(-8.4, 2.1, 6.0), Color(1, 0.78, 0.5, 1), 1.5, 8.0)
	_light("BedLight", Vector3(9.2, 1.7, -9.0), Color(1, 0.74, 0.46, 1), 0.9, 6.0)
	_light("WindowLightLeft", Vector3(-10.4, 2.0, -6.0), Color(0.72, 0.82, 1, 1), 1.1, 8.0)
	_light("WindowLightRight", Vector3(10.4, 2.0, 5.0), Color(0.72, 0.82, 1, 1), 1.1, 8.0)


# --- helpers ---------------------------------------------------------------


func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_root.add_child(node)
	node.owner = _root
	return node


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, position, mesh, color, emission)


func _cylinder(parent: Node3D, node_name: String, position: Vector3, top: float, bottom: float, height: float, color: Color, rotation: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	var instance := _mesh(parent, node_name, position, mesh, color, emission)
	instance.rotation = rotation
	return instance


func _cone(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return _mesh(parent, node_name, position, mesh, color, 0.0)


func _sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 5
	return _mesh(parent, node_name, position, mesh, color, emission)


func _mesh(parent: Node3D, node_name: String, position: Vector3, mesh: Mesh, color: Color, emission: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	instance.owner = _root
	return instance


func _light(node_name: String, position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	_root.add_child(light)
	light.owner = _root
