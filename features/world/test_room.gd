extends Node3D
## Phase 1 test room: movement, camera toggle, interaction, door, and chest.
##
## The scene is intentionally small and enclosed so third-person camera
## collision and interaction range can be tested without a full world.

func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
