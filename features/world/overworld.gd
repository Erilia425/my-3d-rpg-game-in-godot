extends Node3D
## First exterior region.
##
## The room's back door leads here through an `AreaGate`; the stone arch at the
## south edge leads back. Ground and props live in streamed chunk scenes under
## `res://features/world/chunks/`, so this scene only holds the staging: sky,
## sun, the arrival pad, the arch, and the player. See AGENTS.md sections 7, 8,
## and 10.
##
## The world is a 2x2 biome block placed around the plains: ice to the north,
## desert to the north-east, ocean to the east. Each biome is its own chunk
## folder streamed by its own `ChunkManager`, offset by `chunk_origin`.

## Used when the player walks off the authored world, so an empty edge cannot
## drop them forever. Matches the arrival point of the room's back door.
@export var spawn_position: Vector3 = Vector3(0.0, 0.2, 10.0)
@export var fall_limit: float = -20.0

var _player: Node3D


func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
