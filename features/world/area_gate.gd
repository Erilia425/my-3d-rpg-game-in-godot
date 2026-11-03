class_name AreaGate
extends Area3D
## A doorway that carries the player to another scene when they walk through.
##
## Arming rule: a gate ignores bodies until the player has been outside it at
## least once. That way arriving inside a gate (or spawning at the scene start
## inside one) never bounces the player straight back.
##
## The gate only asks `Game` to travel; `Game` owns the state carry-over and the
## fade. See AGENTS.md sections 6 and 7.

@export_file("*.tscn") var target_scene: String = ""
## Where the player appears in the target scene. Ignored when `use_target_position`
## is false, in which case the target scene's own spawn is kept.
@export var target_position: Vector3 = Vector3.ZERO
@export var use_target_position: bool = true

var _armed := false
var _travelling := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Arm immediately when the player starts outside the gate.
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null and not overlaps_body(player):
		_armed = true


func is_armed() -> bool:
	return _armed


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_armed = true


func _on_body_entered(body: Node3D) -> void:
	if not _armed or _travelling:
		return
	if not body.is_in_group("player"):
		return

	if target_scene.is_empty() or not ResourceLoader.exists(target_scene):
		push_warning("AreaGate %s: target scene is missing: '%s'" % [name, target_scene])
		return

	_armed = false
	_travelling = true

	if use_target_position:
		Game.travel_to(target_scene, target_position)
	else:
		Game.travel_to(target_scene)
