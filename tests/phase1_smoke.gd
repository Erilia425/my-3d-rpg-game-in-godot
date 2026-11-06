extends Node
## Phase 1 smoke test.
##
## Run from a terminal:
##   godot --headless --path . tests/phase1_smoke.tscn
## Or open this scene in the editor and press F6.
##
## Loads the real test room and drives the player: camera toggle, camera
## collision, walk/sprint/jump/gravity, crouch, double-tap running, hold-jump
## stamina, animation states, door, chest, HUD, fade overlay, and pause.
## Prints PHASE1_SMOKE_OK on success.

const EPSILON := 0.05
const ANIMATION_CLIPS := ["idle", "walk", "run", "jump"]

var _failures: PackedStringArray = []
var _prompt_text := ""
var _last_notification := ""

var _room: Node3D
var _player: CharacterBody3D
var _head: Node3D
var _first_person_camera: Camera3D
var _third_person_camera: Camera3D
var _spring_arm: SpringArm3D
var _visual: Node3D
var _interaction: Node3D
var _animation_player: AnimationPlayer
var _hip_l: Node3D
var _door: Node3D
var _chest: Node3D
var _crosshair: Control


func _ready() -> void:
	await get_tree().process_frame

	Events.interaction_prompt_changed.connect(_on_prompt_changed)
	Events.notification_requested.connect(_on_notification)

	var packed := load("res://scenes/test_room.tscn") as PackedScene
	_check(packed != null, "test room scene loads")
	if packed == null:
		_finish()
		return

	_room = packed.instantiate() as Node3D
	add_child(_room)
	await _physics_frames(4)

	_check_player_setup()
	_check_camera_toggle_preserves_pose()
	await _check_camera_collision()
	await _check_movement()
	await _check_gravity_and_jump()
	await _check_animations()
	await _check_crouch_and_double_tap_run()
	await _check_hold_jump()
	await _check_door()
	await _check_chest()
	_check_hud()
	_check_fade_overlay()
	await _check_pause_freezes_player()

	_finish()


# --- checks ---------------------------------------------------------------


func _check_player_setup() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_check(_player != null, "player exists in the player group")
	if _player == null:
		return

	_head = _player.find_child("Head", true, false) as Node3D
	_first_person_camera = _player.find_child("FirstPersonCamera", true, false) as Camera3D
	_third_person_camera = _player.find_child("ThirdPersonCamera", true, false) as Camera3D
	_spring_arm = _player.find_child("ThirdPersonArm", true, false) as SpringArm3D
	_visual = _player.find_child("Visual", true, false) as Node3D
	_interaction = _player.find_child("InteractionComponent", true, false) as Node3D
	_animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_hip_l = _player.find_child("HipL", true, false) as Node3D

	_check(_head != null, "player has a Head node")
	_check(_first_person_camera != null, "player has a first-person camera")
	_check(_third_person_camera != null, "player has a third-person camera")
	_check(_spring_arm != null, "player has a SpringArm3D")
	_check(_visual != null, "player has a visual body")
	_check(_interaction != null, "player has an interaction component")
	_check(_animation_player != null, "player has an AnimationPlayer")

	_check(_player.is_first_person(), "new game starts in first person")
	_check(_first_person_camera.current, "first-person camera is active on start")
	_check(not _third_person_camera.current, "third-person camera is inactive on start")
	_check(not _visual.visible, "own body is hidden in first person")
	_check(_spring_arm.collision_mask != 0, "SpringArm3D has a collision mask")

	_crosshair = _room.find_child("Crosshair", true, false) as Control
	_check(_crosshair != null and _crosshair.visible, "crosshair is visible in first person on load")


func _check_camera_toggle_preserves_pose() -> void:
	var start_position := _player.global_position
	var start_yaw := _player.rotation.y
	_head.rotation.x = deg_to_rad(-12.0)
	var start_pitch := _head.rotation.x

	_player.toggle_camera()

	_check(not _player.is_first_person(), "V-style toggle switches to third person")
	_check(_third_person_camera.current, "third-person camera becomes active")
	_check(not _first_person_camera.current, "first-person camera becomes inactive")
	_check(_visual.visible, "own body is visible in third person")
	_check(not _crosshair.visible, "crosshair hides in third person")
	_check(
		_player.global_position.distance_to(start_position) < EPSILON,
		"toggling to third person does not move the player"
	)
	_check(
		absf(_player.rotation.y - start_yaw) < EPSILON,
		"toggling to third person does not change yaw"
	)
	_check(
		absf(_head.rotation.x - start_pitch) < EPSILON,
		"toggling to third person does not change pitch"
	)

	_player.toggle_camera()

	_check(_player.is_first_person(), "toggling again returns to first person")
	_check(_first_person_camera.current, "first-person camera is active again")
	_check(not _visual.visible, "own body is hidden again")
	_check(_crosshair.visible, "crosshair returns in first person")
	_check(
		absf(_player.rotation.y - start_yaw) < EPSILON and absf(_head.rotation.x - start_pitch) < EPSILON,
		"toggling back preserves yaw and pitch"
	)
	_head.rotation.x = 0.0


func _check_camera_collision() -> void:
	if _spring_arm == null:
		return

	# Open floor space: the arm should reach (close to) its full spring length.
	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	_player._set_camera_mode(1, false)
	await _physics_frames(6)
	var open_distance := _third_person_camera.global_position.distance_to(_head.global_position)
	_check(
		open_distance > _spring_arm.spring_length * 0.8,
		"third-person camera sits at full spring length in open space (%.2f m)" % open_distance
	)

	# Backed against the front wall: the arm must shorten instead of clipping.
	_place_player(Vector3(0, 0.1, 9.5), 0.0, 0.0)
	await _physics_frames(6)
	var wall_distance := _third_person_camera.global_position.distance_to(_head.global_position)
	_check(
		wall_distance < open_distance - 0.5,
		"third-person camera pulls in near a wall (%.2f m)" % wall_distance
	)
	_check(
		wall_distance > 0.2,
		"third-person camera does not collapse onto the player (%.2f m)" % wall_distance
	)

	_player._set_camera_mode(0, false)
	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(4)


func _check_movement() -> void:
	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(6)

	var walk_start := _player.global_position
	Input.action_press("move_forward")
	await _physics_frames(45)
	Input.action_release("move_forward")
	var walk_distance := _player.global_position.distance_to(walk_start)
	_check(walk_distance > 0.5, "player walks forward (%.2f m)" % walk_distance)
	_check(
		_player.global_position.z < walk_start.z - 0.5,
		"walking moves the player along the facing direction"
	)

	await _physics_frames(30)
	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(6)

	var sprint_start := _player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(45)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var sprint_distance := _player.global_position.distance_to(sprint_start)
	_check(
		sprint_distance > walk_distance * 1.15,
		"sprinting covers more ground than walking (%.2f m vs %.2f m)" % [sprint_distance, walk_distance]
	)

	await _physics_frames(20)


func _check_gravity_and_jump() -> void:
	_place_player(Vector3(0, 3.0, 6), 0.0, 0.0)
	await _physics_frames(5)
	_check(_player.velocity.y < 0.0, "gravity pulls the player down in the air")

	await _physics_frames(90)
	_check(_player.is_on_floor(), "player lands on the floor after falling")
	_check(absf(_player.velocity.y) < 0.5, "player comes to rest vertically after landing")

	var floor_y := _player.global_position.y
	Input.action_press("jump")
	await _physics_frames(3)
	Input.action_release("jump")
	_check(_player.velocity.y > 1.0, "jump gives upward velocity")
	await _physics_frames(12)
	_check(_player.global_position.y > floor_y + 0.3, "jump lifts the player off the floor")

	await _physics_frames(120)
	_check(_player.is_on_floor(), "player returns to the floor after jumping")


func _check_animations() -> void:
	if _animation_player == null:
		_check(false, "animation checks need an AnimationPlayer")
		return

	for clip in ANIMATION_CLIPS:
		_check(
			_animation_player.has_animation(clip),
			"player has a \"%s\" animation" % clip
		)

	_check(_all_tracks_resolve(), "every animation track targets a real node property")

	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(20)
	_check(
		_animation_player.current_animation == &"idle",
		"standing still plays idle (%s)" % _animation_player.current_animation
	)

	Input.action_press("move_forward")
	await _physics_frames(20)
	_check(
		_animation_player.current_animation == &"walk",
		"walking plays walk (%s)" % _animation_player.current_animation
	)

	# The clips are only real if the limbs actually move: sample the left hip
	# over half a cycle and require the rotation to sweep.
	var samples: Array[float] = []
	for _i in 8:
		await _physics_frames(4)
		if _hip_l != null:
			samples.append(_hip_l.rotation.x)
	if samples.size() >= 2:
		var swing: float = samples.max() - samples.min()
		_check(swing > 0.15, "the walk cycle swings the legs (%.2f rad)" % swing)
	else:
		_check(false, "player has a HipL node for the walk cycle")

	Input.action_press("sprint")
	await _physics_frames(30)
	_check(
		_animation_player.current_animation == &"run",
		"sprinting plays run (%s)" % _animation_player.current_animation
	)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _physics_frames(20)

	_place_player(Vector3(0, 3.0, 6), 0.0, 0.0)
	await _physics_frames(6)
	_check(
		_animation_player.current_animation == &"jump",
		"being airborne plays jump (%s)" % _animation_player.current_animation
	)

	await _physics_frames(90)
	_check(
		_animation_player.current_animation != &"jump",
		"landing leaves the jump animation (%s)" % _animation_player.current_animation
	)


func _check_crouch_and_double_tap_run() -> void:
	var shift_press := InputEventKey.new()
	shift_press.physical_keycode = KEY_SHIFT
	shift_press.pressed = true
	_check(
		InputMap.event_is_action(shift_press, &"crouch"),
		"a real Shift press matches the crouch action"
	)
	_check(
		InputMap.action_get_events(&"sprint").is_empty(),
		"sprint has no key of its own (running is double-tap forward)"
	)

	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(10)
	var stand_head_y := _head.position.y

	Input.action_press("crouch")
	await _physics_frames(20)
	_check(_player.is_crouching(), "holding crouch enters the crouch state")
	_check(
		_head.position.y < stand_head_y - 0.1,
		"crouching lowers the camera (%.2f -> %.2f)" % [stand_head_y, _head.position.y]
	)
	Input.action_release("crouch")
	await _physics_frames(20)
	_check(not _player.is_crouching(), "releasing crouch stands the player back up")
	_check(
		absf(_head.position.y - stand_head_y) < 0.05,
		"camera returns to standing height"
	)

	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(6)
	Input.action_press("move_forward")
	await _physics_frames(2)
	Input.action_release("move_forward")
	await _physics_frames(3)
	Input.action_press("move_forward")
	await _physics_frames(20)
	_check(_player.is_running(), "a second forward tap engages running")
	_check(
		_animation_player.current_animation == &"run",
		"double-tap running plays run (%s)" % _animation_player.current_animation
	)
	Input.action_release("move_forward")
	await _physics_frames(10)
	_check(not _player.is_running(), "releasing forward stops running")


func _check_hold_jump() -> void:
	var stats := _player.find_child("StatsComponent", true, false) as StatsComponent
	_check(stats != null, "player has a StatsComponent for jump stamina")
	if stats == null:
		return

	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(20)
	var stamina_before := stats.get_stamina()
	var hops := 0
	var was_on_floor := true

	Input.action_press("jump")
	for _i in 90:
		await _physics_frames(1)
		var on_floor: bool = _player.is_on_floor()
		if was_on_floor and not on_floor:
			hops += 1
		was_on_floor = on_floor
	var stamina_after := stats.get_stamina()
	Input.action_release("jump")
	await _physics_frames(80)

	_check(hops >= 2, "holding jump keeps hopping (%d hops)" % hops)
	_check(
		stamina_after < stamina_before - 5.0,
		"holding jump spends stamina (%.1f -> %.1f)" % [stamina_before, stamina_after]
	)
	_check(_player.is_on_floor(), "player is on the floor after holding jump")


func _all_tracks_resolve() -> bool:
	var root := _animation_player.get_node_or_null(_animation_player.root_node)
	if root == null:
		push_error("AnimationPlayer root node does not resolve: %s" % _animation_player.root_node)
		return false

	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation == null or animation.get_track_count() == 0:
			push_error("animation has no tracks: %s" % animation_name)
			return false

		for track_index in animation.get_track_count():
			var track_path := str(animation.track_get_path(track_index))
			var parts := track_path.split(":", true, 1)
			var target := root.get_node_or_null(NodePath(parts[0]))
			if target == null:
				push_error("track node missing in %s: %s" % [animation_name, track_path])
				return false
			if parts.size() > 1 and not _has_property(target, parts[1]):
				push_error("track property missing in %s: %s" % [animation_name, track_path])
				return false

	return true


func _has_property(node: Node, property_name: String) -> bool:
	for entry in node.get_property_list():
		if String(entry["name"]) == property_name:
			return true
	return false


func _check_door() -> void:
	_door = _room.find_child("Door", true, false) as Node3D
	_check(_door != null, "test room contains a door")
	if _door == null:
		return

	_check(_door.is_in_group("interactable"), "door is in the interactable group")
	_check(_door.has_method("get_interaction_text"), "door exposes get_interaction_text()")

	_prompt_text = ""
	_place_player(Vector3(0, 0.2, -10), 0.0, 0.0)
	await _physics_frames(12)
	_check(_prompt_text == "Open door", "interaction prompt appears for the door (\"%s\")" % _prompt_text)

	_send_interact()
	await _physics_frames(2)
	_check(bool(_door.is_open), "pressing interact opens the door")
	# Read the prompt here, not after the swing: the panel rotates -100 deg into
	# the room, so a fixed wait races the moment it leaves the interaction ray.
	_check(_prompt_text == "Close door", "prompt updates to Close door (\"%s\")" % _prompt_text)

	_send_interact()
	await _physics_frames(2)
	_check(not bool(_door.is_open), "pressing interact closes the door again")


func _check_chest() -> void:
	_chest = _room.find_child("Chest", true, false) as Node3D
	_check(_chest != null, "test room contains a chest")
	if _chest == null:
		return

	_check(_chest.is_in_group("interactable"), "chest is in the interactable group")

	_prompt_text = ""
	_last_notification = ""
	_place_player(Vector3(5, 0.2, -6.5), 0.0, -45.0)
	await _physics_frames(12)
	_check(_prompt_text == "Open chest", "interaction prompt appears for the chest (\"%s\")" % _prompt_text)

	_send_interact()
	await _physics_frames(2)
	_check(bool(_chest.is_open), "pressing interact opens the chest")
	_check(not _last_notification.is_empty(), "opening the chest shows a notification (\"%s\")" % _last_notification)

	await _physics_frames(12)
	_check(_prompt_text.is_empty(), "an opened chest no longer shows a prompt")

	_last_notification = ""
	_send_interact()
	await _physics_frames(2)
	_check(_last_notification.is_empty(), "an opened chest cannot be looted twice")


func _check_hud() -> void:
	var hud := _room.find_child("HUD", true, false) as CanvasLayer
	_check(hud != null, "test room contains a HUD")
	if hud == null:
		return

	_check(hud.find_child("Crosshair", true, false) != null, "HUD has a crosshair")
	_check(hud.find_child("PromptPanel", true, false) != null, "HUD has an interaction prompt")
	_check(hud.find_child("ToastLabel", true, false) != null, "HUD has a notification label")


func _check_fade_overlay() -> void:
	var fade_layer := SceneRouter.get_node_or_null("FadeLayer")
	_check(fade_layer != null, "SceneRouter creates a fade layer")
	if fade_layer == null:
		return

	var fade_rect := fade_layer.get_node_or_null("FadeRect") as ColorRect
	_check(fade_rect != null, "SceneRouter creates a fade rectangle")
	if fade_rect == null:
		return
	_check(not fade_rect.visible, "fade rectangle is hidden while playing")
	_check(fade_rect.color.a <= 0.001, "fade rectangle is fully transparent while playing")


func _check_pause_freezes_player() -> void:
	_place_player(Vector3(0, 0.1, 6), 0.0, 0.0)
	await _physics_frames(6)

	Game.pause_game()
	_check(Game.state == Game.State.PAUSED, "pause enters PAUSED with the player loaded")
	_check(get_tree().paused, "pause freezes the scene tree")

	var paused_position := _player.global_position
	Input.action_press("move_forward")
	await _physics_frames(20)
	Input.action_release("move_forward")
	var drifted := _player.global_position.distance_to(paused_position)

	Game.resume_game()
	_check(not get_tree().paused, "resume unfreezes the scene tree")
	_check(drifted < EPSILON, "the player cannot move while paused (%.3f m)" % drifted)

	Game.set_state(Game.State.MAIN_MENU)


# --- helpers --------------------------------------------------------------


func _place_player(position: Vector3, yaw_degrees: float, pitch_degrees: float) -> void:
	if _player == null:
		return
	_player.global_position = position
	_player.rotation.y = deg_to_rad(yaw_degrees)
	_player.velocity = Vector3.ZERO
	if _head != null:
		_head.rotation.x = deg_to_rad(pitch_degrees)


func _send_interact() -> void:
	if _player == null:
		return
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	_player._unhandled_input(event)


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _on_prompt_changed(text: String) -> void:
	_prompt_text = text


func _on_notification(text: String) -> void:
	_last_notification = text


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE1_SMOKE_OK")
		get_tree().quit(0)
	else:
		push_error("PHASE1_SMOKE_FAILED: " + ", ".join(_failures))
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures.append(message)
		push_error("  FAIL: " + message)
