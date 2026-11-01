extends CharacterBody3D
## First/third-person player controller.
##
## New games start in first person. V toggles to third person without moving
## the player or changing the look direction. See AGENTS.md section 7.

enum CameraMode {
	FIRST_PERSON,
	THIRD_PERSON,
}

## Seconds spent blending between two locomotion clips.
const ANIMATION_BLEND_TIME := 0.15
## Below this horizontal speed (m/s) the player counts as standing still.
const WALK_ANIMATION_THRESHOLD := 0.2

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.8
@export var gravity: float = 18.0
@export var acceleration: float = 20.0
@export var air_control: float = 0.35

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0022
@export var min_pitch_degrees: float = -85.0
@export var max_pitch_degrees: float = 85.0

@onready var _head: Node3D = %Head
@onready var _first_person_camera: Camera3D = %FirstPersonCamera
@onready var _third_person_camera: Camera3D = %ThirdPersonCamera
@onready var _visual: Node3D = %Visual
@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _interaction_component: Node3D = %InteractionComponent

var camera_mode: CameraMode = CameraMode.FIRST_PERSON
var _pitch := 0.0
var _current_animation: StringName = &""


func _ready() -> void:
	_set_camera_mode(CameraMode.FIRST_PERSON, false)
	# Announce once after the whole scene is ready, so the HUD can match its
	# crosshair to the starting perspective.
	_announce_camera_mode.call_deferred()


func _announce_camera_mode() -> void:
	Events.camera_mode_changed.emit(is_first_person())


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)

		_pitch = clampf(
			_pitch - motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		_head.rotation.x = _pitch
		return

	if event.is_action_pressed("toggle_camera"):
		toggle_camera()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		if _interaction_component.interact():
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_vector := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (global_basis * Vector3(
		input_vector.x, 0.0, input_vector.y
	)).normalized()

	var target_speed := walk_speed
	if Input.is_action_pressed("sprint") and input_vector.length_squared() > 0.0:
		target_speed = sprint_speed

	var target_velocity := direction * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration_rate := acceleration if is_on_floor() else acceleration * air_control
	horizontal = horizontal.move_toward(target_velocity, acceleration_rate * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	_update_animation()


## Chooses the locomotion clip from the current speed and airborne state.
## The clips themselves live in player.tscn; this only selects and blends them.
func _update_animation() -> void:
	if _animation_player == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var next: StringName = &"idle"

	if not is_on_floor():
		next = &"jump"
	elif horizontal_speed > walk_speed * 1.1:
		next = &"run"
	elif horizontal_speed > WALK_ANIMATION_THRESHOLD:
		next = &"walk"

	if next != _current_animation:
		_current_animation = next
		_animation_player.play(next, ANIMATION_BLEND_TIME)

	# Scale the cycle to the real speed so the feet do not slide.
	match next:
		&"walk":
			_animation_player.speed_scale = clampf(horizontal_speed / walk_speed, 0.6, 1.4)
		&"run":
			_animation_player.speed_scale = clampf(horizontal_speed / sprint_speed, 0.7, 1.3)
		_:
			_animation_player.speed_scale = 1.0


func toggle_camera() -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		_set_camera_mode(CameraMode.THIRD_PERSON)
	else:
		_set_camera_mode(CameraMode.FIRST_PERSON)


func get_camera_mode_name() -> StringName:
	return &"first" if camera_mode == CameraMode.FIRST_PERSON else &"third"


func is_first_person() -> bool:
	return camera_mode == CameraMode.FIRST_PERSON


func _set_camera_mode(mode: CameraMode, announce: bool = true) -> void:
	camera_mode = mode
	var first_person := camera_mode == CameraMode.FIRST_PERSON

	_first_person_camera.current = first_person
	_third_person_camera.current = not first_person
	_visual.visible = not first_person

	if announce:
		Events.camera_mode_changed.emit(first_person)
