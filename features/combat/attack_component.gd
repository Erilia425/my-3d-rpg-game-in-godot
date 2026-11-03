class_name AttackComponent
extends Node3D
## Melee swing probe.
##
## Sweeps a sphere in front of the active camera and damages the closest actor
## in the `enemy` group. A sphere rather than a ray because a swing should be
## forgiving to aim, and because a ray can slip past a thin capsule.

signal hit_landed(target: Node, damage: float)

@export var reach: float = 2.4
@export var swing_radius: float = 0.8
## Enemy collision layer (see AGENTS.md section 9.2).
@export var collision_mask: int = 4
@export var damage: float = 6.0

var _shape: SphereShape3D


func _ready() -> void:
	_shape = SphereShape3D.new()
	_shape.radius = swing_radius


## Damages the closest living enemy in reach. Returns it, or null on a miss.
func try_hit() -> Node:
	var center := global_position + _forward() * (reach * 0.5)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var best: Node3D = null
	var best_distance := INF
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var collider := result.get("collider") as Node3D
		if collider == null or not collider.is_in_group("enemy"):
			continue
		var distance := global_position.distance_squared_to(collider.global_position)
		if distance < best_distance:
			best_distance = distance
			best = collider

	if best == null:
		return null

	var health := best.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead():
		return null

	health.take_damage(damage)
	hit_landed.emit(best, damage)
	return best


func _forward() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		return -camera.global_basis.z
	return -global_basis.z
