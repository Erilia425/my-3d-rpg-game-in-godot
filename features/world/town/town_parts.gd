class_name TownParts
extends RefCounted
## Primitive builders shared by the town's runtime props.
##
## The town is content, not a system: buildings and props assemble themselves
## from shared meshes and materials at `_ready()` so one small script can cover a
## whole street of cottages without a scene file per house. See AGENTS.md 4.5.

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func material(color: Color, roughness: float = 0.92, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, emission]
	if _material_cache.has(key):
		return _material_cache[key]

	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	if emission > 0.0:
		made.emission_enabled = true
		made.emission = color
		made.emission_energy_multiplier = emission
	_material_cache[key] = made
	return made


static func box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := _cached_mesh("box|%s" % size, func() -> Mesh:
		var made := BoxMesh.new()
		made.size = size
		return made
	)
	return _place(parent, node_name, position, mesh, mat)


static func cylinder(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	top_radius: float,
	bottom_radius: float,
	height: float,
	mat: Material,
	rotation: Vector3 = Vector3.ZERO,
	sides: int = 10
) -> MeshInstance3D:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [top_radius, bottom_radius, height, sides]
	var mesh := _cached_mesh(key, func() -> Mesh:
		var made := CylinderMesh.new()
		made.top_radius = top_radius
		made.bottom_radius = bottom_radius
		made.height = height
		made.radial_segments = sides
		return made
	)
	var instance := _place(parent, node_name, position, mesh, mat)
	instance.rotation = rotation
	return instance


static func sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var key := "sph|%.3f|%.3f" % [radius, height]
	var mesh := _cached_mesh(key, func() -> Mesh:
		var made := SphereMesh.new()
		made.radius = radius
		made.height = height
		made.radial_segments = 10
		made.rings = 5
		return made
	)
	return _place(parent, node_name, position, mesh, mat)


static func prism(parent: Node3D, node_name: String, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := _cached_mesh("prism|%s" % size, func() -> Mesh:
		var made := PrismMesh.new()
		made.size = size
		made.left_to_right = 0.5
		return made
	)
	return _place(parent, node_name, position, mesh, mat)


static func cone(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, mat: Material, sides: int = 8) -> MeshInstance3D:
	return cylinder(parent, node_name, position, 0.02, radius, height, mat, Vector3.ZERO, sides)


## Bakes every direct `MeshInstance3D` child into one mesh per material.
##
## Each primitive child is its own draw call: a cottage is ~36 of them. Merging
## keeps the same pixels and the same materials, but a house costs a handful of
## calls instead of three dozen. Collisions, lights, and labels are separate
## children and are left untouched. See AGENTS.md 10.2.
static func merge_children(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for child in parent.get_children():
		var instance := child as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var key := instance.material_override.get_instance_id() if instance.material_override != null else 0
		if not groups.has(key):
			var list: Array[MeshInstance3D] = []
			groups[key] = list
		(groups[key] as Array[MeshInstance3D]).append(instance)

	var index := 0
	for key in groups:
		var list: Array[MeshInstance3D] = groups[key]
		if list.size() < 2:
			continue
		var merged := _merge(list)
		if merged == null:
			continue
		var batch := MeshInstance3D.new()
		batch.name = "Batch%d" % index
		batch.mesh = merged
		batch.material_override = list[0].material_override
		parent.add_child(batch)
		index += 1
		for instance in list:
			instance.free()


static func _merge(instances: Array[MeshInstance3D]) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for instance in instances:
		if instance.mesh.get_surface_count() == 0:
			return null
		tool.append_from(instance.mesh, 0, instance.transform)
	return tool.commit()


## Adds a static box collider on the world layer. Town geometry never masks
## anything, matching the rest of the level content.
static func collision(parent: Node3D, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


static func cylinder_collision(parent: Node3D, radius: float, height: float, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var made := CylinderShape3D.new()
	made.radius = radius
	made.height = height
	shape.shape = made
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _place(parent: Node3D, node_name: String, position: Vector3, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	parent.add_child(instance)
	return instance


static func _cached_mesh(key: String, make: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = make.call()
	return _mesh_cache[key]
