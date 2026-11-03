extends Node3D
## First exterior region.
##
## The room's back door leads here through an `AreaGate`; the stone arch at the
## south edge leads back. Ground and props live in streamed chunk scenes under
## `res://features/world/chunks/`, so this scene only holds the staging: sky,
## sun, the arrival pad, the arch, and the player. See AGENTS.md sections 7, 8,
## and 10.

func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
