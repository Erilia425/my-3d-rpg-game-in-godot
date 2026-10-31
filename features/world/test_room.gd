extends Node3D
## Phase 0 test room.
##
## Provides a temporary free-look camera so the 3D project, input map, pause
## flow, and debug overlay can be tested before the real player controller
## arrives in Phase 1. This script is replaced, not extended, in Phase 1.

const LOOK_SENSITIVITY := 0.0025
const MOVE_SPEED := 5.0
const MAX_PITCH := 1.3962634 # 80 degrees in radians

@onready var _camera_rig: Node3D = %CameraRig
@onready var _camera: Camera3D = %Camera
@onready var _spinner: Node3D = %Spinner

var _pitch := 0.0


func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_camera_rig.rotate_y(-motion.relative.x * LOOK_SENSITIVITY)
		_pitch = clampf(
			_pitch - motion.relative.y * LOOK_SENSITIVITY,
			-MAX_PITCH,
			MAX_PITCH
		)
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return

	var input_vector := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	if input_vector.length_squared() <= 0.0:
		return

	var direction := _camera_rig.global_basis * Vector3(
		input_vector.x, 0.0, input_vector.y
	)
	direction.y = 0.0
	if direction.length_squared() > 0.0:
		_camera_rig.global_position += direction.normalized() * MOVE_SPEED * delta


func _process(delta: float) -> void:
	if _spinner != null:
		_spinner.rotate_y(delta * 0.6)
