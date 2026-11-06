class_name FallGuard
extends Node3D
## Puts the player back on solid ground if they fall out of an exterior scene.
##
## The authored world is a finite island of content: walk far enough in any
## direction and there is nothing left to stand on. Rather than fence the map,
## every exterior carries one of these and simply returns the player to its
## arrival point. See AGENTS.md section 7.

## Where the player is returned. Should be the scene's arrival point.
@export var spawn_position: Vector3 = Vector3(0.0, 0.2, 10.0)
## Below this world height the player is considered lost.
@export var fall_limit: float = -20.0

var _player: Node3D


func _ready() -> void:
	# One frame of grace so the player instance is in the tree and in its group.
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _player.global_position.y >= fall_limit:
		return

	_player.global_position = spawn_position
	var body := _player as CharacterBody3D
	if body != null:
		body.velocity = Vector3.ZERO
