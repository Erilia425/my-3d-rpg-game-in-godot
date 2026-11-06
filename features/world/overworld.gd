extends Node3D
## First exterior region.
##
## The town's north gate leads here through an `AreaGate`; the stone arch at the
## south edge leads back to Mycelgrove Hollow. Ground and props live in streamed
## chunk scenes under `res://features/world/chunks/`, so this scene only holds
## the staging: sky, sun, the arrival pad, the arch, and the player. See
## AGENTS.md sections 7, 8, and 10.
##
## The world is a 2x2 biome block placed around the plains: ice to the north,
## desert to the north-east, ocean to the east. Each biome is its own chunk
## folder streamed by its own `ChunkManager`, offset by `chunk_origin`.
##
## Falling off the authored world is handled by the `FallGuard` node.

func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
