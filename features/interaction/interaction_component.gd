extends Node3D
## Finds an interactable object in front of the active camera.
##
## The ray starts at this node (placed at the player's head) and travels along
## the active camera's forward direction. This keeps interaction range
## consistent in both first and third person.

@export var interaction_distance: float = 3.0
@export var collision_mask: int = 17 # Layer 1 (world) + layer 5 (interactable)
@export var check_interval: float = 0.1

var _current_target: Node = null
var _current_prompt := ""
var _time_until_check := 0.0


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		_clear_target()
		return

	_time_until_check -= delta
	if _time_until_check > 0.0:
		return

	_time_until_check = check_interval
	_refresh_target()


func interact() -> bool:
	if Game.state != Game.State.PLAYING:
		return false
	if not is_instance_valid(_current_target):
		return false
	if not _current_target.has_method("interact"):
		return false

	_current_target.interact(owner)
	_refresh_target()
	return true


func _refresh_target() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_clear_target()
		return

	var origin := global_position
	var direction := -camera.global_basis.z
	var end := origin + direction * interaction_distance

	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
	var body := owner as CollisionObject3D
	if body != null:
		query.exclude = [body.get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_clear_target()
		return

	var collider := result.get("collider") as Node
	if collider == null or not collider.is_in_group("interactable"):
		_clear_target()
		return
	if not collider.has_method("get_interaction_text") or not collider.has_method("interact"):
		_clear_target()
		return

	var prompt := String(collider.get_interaction_text())
	if prompt.is_empty():
		_clear_target()
		return

	_set_target(collider, prompt)


func _set_target(target: Node, prompt: String) -> void:
	if target == _current_target and prompt == _current_prompt:
		return

	_current_target = target
	_current_prompt = prompt
	Events.interaction_prompt_changed.emit(prompt)


func _clear_target() -> void:
	_set_target(null, "")


func _exit_tree() -> void:
	if _current_target != null:
		Events.interaction_prompt_changed.emit("")
