class_name TownForest
extends Node3D
## The forest wall around Mycelgrove Hollow.
##
## Two layers, on purpose:
##
## - A dense *ring* of trees drawn as `MultiMeshInstance3D` batches. The ring is
##   a visual boundary 60-94 m from the centre, far outside the streets, and it
##   costs a handful of draw calls instead of one per tree.
## - *Clumps* inside the town edge, built as real `TownProp` trees with colliders,
##   where the player can actually walk up and bump into them.
##
## `clumps` and `avoid` are `PackedVector3Array`s read as circles: x and z are the
## centre, y is the radius. Avoid circles keep road gates and bridges clear.
## See AGENTS.md 10.2.

const TREE_KIND := 0
const PINE_KIND := 1

## Leaf variants, so the ring is not one flat green wall.
const LEAF_COLORS: Array[Color] = [
	Color(0.19, 0.3, 0.15, 1),
	Color(0.24, 0.36, 0.17, 1),
	Color(0.16, 0.26, 0.16, 1),
]

@export var count: int = 150
@export var inner_radius: float = 60.0
@export var outer_radius: float = 94.0
@export var clumps: PackedVector3Array = PackedVector3Array()
@export var avoid: PackedVector3Array = PackedVector3Array()
@export var seed_value: int = 20261103

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	_ring()
	_clumps()


# --- distant ring ----------------------------------------------------------


func _ring() -> void:
	# Square-root sampling keeps the ring evenly dense instead of clustering at
	# the inner edge. Each entry is one tree: centre, height, canopy width.
	var trees: Array[Dictionary] = []

	for attempt in count * 8:
		if trees.size() >= count:
			break
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf_range(inner_radius * inner_radius, outer_radius * outer_radius))
		var at := Vector2(cos(angle), sin(angle)) * radius
		if _blocked(at):
			continue
		if _too_close(at, trees, 3.4):
			continue
		trees.append({
			"at": at,
			"height": _rng.randf_range(5.0, 9.5),
			"width": _rng.randf_range(1.7, 2.7),
		})

	_add_batches(trees)


func _add_batches(trees: Array[Dictionary]) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 2.0
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 4

	var trunks := _multimesh("Trunks", trunk_mesh, TownParts.material(Color(0.24, 0.17, 0.11, 1), 0.97))
	var canopies: Array[MultiMeshInstance3D] = []
	for leaf in LEAF_COLORS:
		canopies.append(_multimesh("Canopies", canopy_mesh, TownParts.material(leaf, 0.98)))

	trunks.multimesh.instance_count = trees.size()
	var canopy_lists: Array[Array] = [[], [], []]
	for i in trees.size():
		var tree := trees[i]
		var at: Vector2 = tree["at"]
		var height: float = tree["height"]
		var width: float = tree["width"]

		var trunk_basis := Basis().scaled(Vector3(1.0, height, 1.0))
		trunks.multimesh.set_instance_transform(i, Transform3D(trunk_basis, Vector3(at.x, height * 0.5 - 0.1, at.y)))

		var canopy_basis := Basis().scaled(Vector3(width, width * 0.92, width))
		var canopy_at := Vector3(at.x, height * 0.82, at.y)
		canopy_lists[i % 3].append([canopy_basis, canopy_at])

	for i in canopies.size():
		var list: Array = canopy_lists[i]
		canopies[i].multimesh.instance_count = list.size()
		for j in list.size():
			var item: Array = list[j]
			canopies[i].multimesh.set_instance_transform(j, Transform3D(item[0] as Basis, item[1] as Vector3))


func _multimesh(node_name: String, mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 0
	batch.multimesh = multimesh
	batch.material_override = mat
	add_child(batch)
	return batch


# --- near clumps -----------------------------------------------------------


func _clumps() -> void:
	for i in clumps.size():
		var clump := clumps[i]
		var centre := Vector2(clump.x, clump.z)
		var radius: float = clump.y
		var trees_here := 4 + _rng.randi_range(0, 3)

		for j in trees_here:
			var angle := _rng.randf() * TAU
			var distance := sqrt(_rng.randf()) * radius
			var at := centre + Vector2(cos(angle), sin(angle)) * distance
			if _blocked(at):
				continue

			var prop: TownProp = TownProp.new()
			prop.name = "Clump%d_%d" % [i, j]
			prop.position = Vector3(at.x, 0.0, at.y)
			prop.facing_degrees = _rng.randf() * 360.0
			prop.seed_value = 1000 + i * 97 + j
			if _rng.randf() < 0.45:
				prop.kind = TownProp.Kind.PINE
				prop.size = Vector3(1.0, _rng.randf_range(5.0, 8.5), 1.0)
			else:
				prop.kind = TownProp.Kind.TREE
				prop.size = Vector3(_rng.randf_range(1.5, 2.4), _rng.randf_range(3.4, 5.6), 1.0)
			add_child(prop)


# --- helpers ---------------------------------------------------------------


func _blocked(at: Vector2) -> bool:
	for circle in avoid:
		if at.distance_to(Vector2(circle.x, circle.z)) < circle.y:
			return true
	return false


func _too_close(at: Vector2, trees: Array[Dictionary], min_distance: float) -> bool:
	for tree in trees:
		if at.distance_to(tree["at"] as Vector2) < min_distance:
			return true
	return false
