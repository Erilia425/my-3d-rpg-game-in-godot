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
## Optional pixel-art texture for the strip (water, dirt bank, gravel lane).
## Left empty, the strip is a flat colour exactly as before.
@export var albedo_texture: Texture2D = null
## How many times the texture repeats across the strip. Triplanar mapping is
## used so the art follows the ribbon's shape without hand-made UVs.
@export var uv_scale: Vector3 = Vector3.ONE
## Optional art for the small cross-strips that show a river's current.
@export var ripple_texture: Texture2D = null

var _material: StandardMaterial3D
var _ripple_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(name)
	_material = _make_material(color, roughness, transparent, albedo_texture)
	_ripple_material = _make_material(
		Color(color.r + 0.16, color.g + 0.16, color.b + 0.18, minf(color.a + 0.2, 0.9)),
		0.25,
		true,
		ripple_texture
	)

	if points.size() < 2:
		return

	_build_strip()

	if transparent and ripples:
		for i in points.size() - 1:
			_ripple_run(points[i], points[i + 1])

	# Every strip and ripple shares the ribbon's two materials, so merging them
	# turns a long river from hundreds of draw calls into two. See AGENTS.md 10.2.
	TownParts.merge_children(self)


## One continuous strip built as a welded triangle band along the points.
##
## The old version laid a chain of boxes end to end and dropped a square patch
## on every bend. That is what made a lane read as a row of stamped tiles: the
## patches filled the corners, but they also showed every seam and every change
## of direction. A single welded strip has no internal edges at all.
##
## Width tapers at both ends and breathes slightly along its length, so a dirt
## lane starts and stops in the grass instead of being cut off square. The
## texture is unchanged and still triplanar-projected by `_make_material`.
func _build_strip() -> void:
	var centres: Array[Vector2] = []
	for point in points:
		var flat := Vector2(point.x, point.z)
		if centres.is_empty() or centres[centres.size() - 1].distance_to(flat) > 0.05:
			centres.append(flat)
	if centres.size() < 2:
		return

	# Cumulative distance, used for the width wobble and the end taper.
	var travel: Array[float] = [0.0]
	for i in range(1, centres.size()):
		travel.append(travel[i - 1] + centres[i - 1].distance_to(centres[i]))
	var total: float = maxf(travel[travel.size() - 1], 0.01)

	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in centres.size():
		# A mitre normal keeps the width constant around a bend: the two
		# neighbouring edge normals are averaged into one shared edge.
		var incoming := _direction(centres, i - 1, i)
		var outgoing := _direction(centres, i, i + 1)
		var normal := Vector2(-incoming.y, incoming.x) + Vector2(-outgoing.y, outgoing.x)
		if normal.length_squared() < 0.0001:
			normal = Vector2(-incoming.y, incoming.x)
		normal = normal.normalized()

		var half := _half_width(travel[i], total)
		var centre := centres[i]
		left.append(Vector3(centre.x + normal.x * half, surface_height, centre.y + normal.y * half))
		right.append(Vector3(centre.x - normal.x * half, surface_height, centre.y - normal.y * half))

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in centres.size():
		vertices.append(left[i])
		vertices.append(right[i])
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, travel[i]))
		uvs.append(Vector2(1.0, travel[i]))

	for i in centres.size() - 1:
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		# Two triangles per segment, wound counter-clockwise seen from above.
		indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "Strip"
	instance.mesh = mesh
	instance.material_override = _material
	add_child(instance)


## Unit direction of one polyline segment, clamped at the ends so the first and
## last point reuse their only neighbour.
func _direction(centres: Array[Vector2], from: int, to: int) -> Vector2:
	var a: int = clampi(from, 0, centres.size() - 2)
	var b: int = clampi(to, 1, centres.size() - 1)
	if a >= b:
		a = maxi(b - 1, 0)
	var vector := centres[b] - centres[a]
	if vector.length_squared() < 0.0001:
		return Vector2(0.0, 1.0)
	return vector.normalized()


## Half the strip's width at one point along it.
##
## Three metres at each end narrow to just over half width, so a lane thins out
## where it meets a road instead of ending in a square cut. The rest wobbles
## slowly and predictably: a path worn by feet is never one width all the way.
## Water keeps an even width.
func _half_width(along: float, total: float) -> float:
	var scale := 1.0
	if not transparent:
		const TAPER := 3.0
		var edge: float = minf(along, total - along)
		if edge < TAPER:
			scale *= lerpf(0.55, 1.0, clampf(edge / TAPER, 0.0, 1.0))
		scale *= 0.93 + sin(along * 0.35 + float(seed_value % 97) * 0.31) * 0.07
	return width * 0.5 * scale


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


func _make_material(base: Color, mattness: float, clear: bool, texture: Texture2D) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = base
	made.roughness = mattness
	if texture != null:
		made.albedo_texture = texture
		made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# The ribbon is built from plain boxes with no hand-made UVs, so the
		# texture is projected from world space instead. Triplanar keeps the
		# pixel art the same size on every segment, whatever its length.
		made.uv1_triplanar = true
		made.uv1_scale = uv_scale
		made.uv1_world_triplanar = true
	if clear:
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		# A whisper of sheen so the water catches the sun.
		made.emission_enabled = true
		made.emission = Color(base.r, base.g, base.b, 1.0)
		made.emission_energy_multiplier = 0.16
	return made
