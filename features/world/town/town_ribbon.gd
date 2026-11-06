class_name TownRibbon
extends Node3D
## A river, a lane, or any flat strip that follows a list of points.
##
## One ribbon is a chain of thin boxes laid end to end, each rotated to face the
## next point. That is enough for packed-earth streets and a shallow river at a
## blockout scale, and it keeps the town scene free of hand-placed road tiles.
##
## Water is drawn the same way as the ocean biome: a translucent sheet over
## walkable ground, so the player wades rather than swims. See AGENTS.md 7.

## World-space polyline (y is ignored; the ribbon lies at `surface_height`).
@export var points: PackedVector3Array = PackedVector3Array()
@export var width: float = 3.0
@export var color: Color = Color(0.5, 0.42, 0.3, 1)
## Top of the strip. Paths sit just above the ground; water a little higher.
@export var surface_height: float = 0.04
@export var thickness: float = 0.05
@export var roughness: float = 0.9
## Alpha below 1 makes it translucent water instead of packed earth.
@export var transparent: bool = false
## Small lighter cross-strips, for a river's current. Only used when transparent.
@export var ripples: bool = true
@export var ripple_spacing: float = 5.5
@export var seed_value: int = 0

var _material: StandardMaterial3D
var _ripple_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(name)
	_material = _make_material(color, roughness, transparent)
	_ripple_material = _make_material(
		Color(color.r + 0.16, color.g + 0.16, color.b + 0.18, minf(color.a + 0.2, 0.9)),
		0.25,
		true
	)

	if points.size() < 2:
		return

	for i in points.size() - 1:
		_segment(points[i], points[i + 1])

	# Square patches at the bend points hide the wedge a chain of boxes leaves.
	for i in range(1, points.size() - 1):
		var joint := BoxMesh.new()
		joint.size = Vector3(width, thickness, width)
		_place(points[i], joint, _material, 0.0)

	if transparent and ripples:
		for i in points.size() - 1:
			_ripple_run(points[i], points[i + 1])


func _segment(from: Vector3, to: Vector3) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 0.01:
		return

	var mesh := BoxMesh.new()
	# Overlap by a fraction of the width so corners never show a gap.
	mesh.size = Vector3(width, thickness, length + width * 0.6)

	var centre := (from + to) * 0.5
	centre.y = 0.0
	_place(centre, mesh, _material, atan2(flat.x, flat.z))


func _ripple_run(from: Vector3, to: Vector3) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 1.0:
		return
	var angle := atan2(flat.x, flat.z)
	var direction := flat / length
	var steps := int(length / ripple_spacing)

	for i in steps:
		var along := (float(i) + 0.5) * ripple_spacing
		if along > length:
			break
		var at := from + direction * along
		at.y = 0.0
		# A narrow band across the current, nudged sideways so it looks hand-made.
		at += Vector3(-direction.z, 0.0, direction.x) * _rng.randf_range(-width * 0.22, width * 0.22)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width * _rng.randf_range(0.55, 0.85), thickness * 0.5, 0.22)
		_place(at, mesh, _ripple_material, angle)


func _place(at: Vector3, mesh: Mesh, mat: Material, angle: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Strip"
	instance.mesh = mesh
	instance.material_override = mat
	instance.rotation.y = angle
	instance.position = Vector3(at.x, surface_height - thickness * 0.5, at.z)
	add_child(instance)


func _make_material(base: Color, mattness: float, clear: bool) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = base
	made.roughness = mattness
	if clear:
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		# A whisper of sheen so the water catches the sun.
		made.emission_enabled = true
		made.emission = Color(base.r, base.g, base.b, 1.0)
		made.emission_energy_multiplier = 0.16
	return made
