extends CharacterBody3D
class_name PlayerController
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

## Stable id for the save file. There is exactly one player in a single-player
## game, so a constant id is enough. See AGENTS.md section 8.
const SAVE_ID := &"player"
## A save taken at the instant of death is reloaded at 1 HP instead of leaving
## the player permanently dead.
const MIN_LOADED_HEALTH := 1.0

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.6
@export var jump_velocity: float = 4.8
@export var gravity: float = 18.0
@export var acceleration: float = 20.0
@export var air_control: float = 0.35
## Stamina spent on each jump. Holding jump keeps hopping until it runs out.
@export var jump_stamina_cost: float = 12.0
## A second forward tap inside this window starts running.
@export var run_double_tap_window: float = 0.3
## How far the camera/head lowers while crouching, in metres.
@export var crouch_head_drop: float = 0.45
## How fast the head blends in and out of the crouch height.
@export var crouch_blend_speed: float = 10.0
## How far the camera/head lowers while sitting on a chair, in metres.
@export var sit_head_drop: float = 0.35

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
@onready var _health: HealthComponent = %HealthComponent
@onready var _stats: StatsComponent = %StatsComponent
@onready var _inventory: InventoryComponent = %InventoryComponent
@onready var _equipment: EquipmentComponent = %EquipmentComponent
@onready var _flashlight: SpotLight3D = %Flashlight

var camera_mode: CameraMode = CameraMode.FIRST_PERSON
var _pitch := 0.0
var _current_animation: StringName = &""
var _ui_blocked := false
var _attack_lock := 0.0
var _head_stand_height := 0.0
var _run_engaged := false
var _crouching := false
var _sitting := false
var _last_forward_press_msec := -100000
## Multiplier applied to every ground speed while standing in an environment
## that slows the player (river wading, later mud or snow). `1.0` is normal.
var _environment_speed_scale := 1.0

# Base values captured once, before any skill or shop bonus is applied. Every
# call to `apply_progression()` recomputes the totals from these, so buying a
# rank twice can never stack the same bonus twice.
var _base_walk_speed := 5.0
var _base_sprint_speed := 8.0
var _base_max_health := 100.0
var _base_max_stamina := 100.0
var _base_inventory_capacity := 24
var _air_jumps_left := 1
## Air tracking for `MovementStats`: the last floor height, the highest point of
## the current hop, and how long the boots have been off the ground.
var _airborne := false
var _ground_y := 0.0
var _peak_y := 0.0
var _air_time := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	_head_stand_height = _head.position.y
	_equipment.setup(_inventory)

	_base_walk_speed = walk_speed
	_base_sprint_speed = sprint_speed
	_base_max_health = _health.max_health
	_base_max_stamina = _stats.max_stamina
	_base_inventory_capacity = _inventory.capacity
	apply_progression()

	_set_camera_mode(CameraMode.FIRST_PERSON, false)
	# Announce once after the whole scene is ready, so the HUD can match its
	# crosshair to the starting perspective.
	_announce_camera_mode.call_deferred()


func _announce_camera_mode() -> void:
	Events.camera_mode_changed.emit(is_first_person())


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING or _ui_blocked:
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

	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		if _sitting:
			stand_up()
			get_viewport().set_input_as_handled()
			return
		if _interaction_component.interact():
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return

	_attack_lock = maxf(_attack_lock - delta, 0.0)

	# While seated the player cannot walk or jump; only look and E to stand.
	# The head settles to chair height so the view reads as sitting down.
	if _sitting:
		velocity = Vector3.ZERO
		_blend_head(_head_stand_height - sit_head_drop, delta)
		return

	if _ui_blocked:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_vector := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := (global_basis * Vector3(
		input_vector.x, 0.0, input_vector.y
	)).normalized()

	var crouching := Input.is_action_pressed("crouch") and is_on_floor()
	_update_run_state(crouching)
	_update_crouch(crouching, delta)

	var target_speed := walk_speed
	if crouching:
		target_speed = crouch_speed
	elif _run_engaged and input_vector.length_squared() > 0.0:
		target_speed = sprint_speed

	var target_velocity := direction * target_speed * _environment_speed_scale
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration_rate := acceleration if is_on_floor() else acceleration * air_control
	horizontal = horizontal.move_toward(target_velocity, acceleration_rate * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Holding jump keeps hopping: the next jump starts the frame the player
	# lands. Each hop costs stamina, so the hopping stops when it runs out.
	if is_on_floor():
		_air_jumps_left = 1
	elif (
		Progression.has_skill(Progression.SKILL_DOUBLE_JUMP)
		and _air_jumps_left > 0
		and Input.is_action_just_pressed("jump")
	):
		# Second Wind: one extra jump per airtime. `just_pressed` means holding
		# jump cannot burn it by accident the frame after leaving the ground.
		if _stats.spend_stamina(jump_stamina_cost):
			velocity.y = jump_velocity
			_air_jumps_left -= 1
			MovementStats.record_jump()

	if Input.is_action_pressed("jump") and is_on_floor() and not crouching:
		if _stats.spend_stamina(jump_stamina_cost):
			velocity.y = jump_velocity
			MovementStats.record_jump()

	move_and_slide()
	_track_air(delta)

	_update_animation()


## Feeds `MovementStats` on takeoff and landing. Walking off a ledge counts as a
## drop, so the record is honest about falls as well as jumps.
func _track_air(delta: float) -> void:
	var on_floor := is_on_floor()
	if not _airborne:
		if on_floor:
			_ground_y = global_position.y
			return
		_airborne = true
		_peak_y = global_position.y
		_air_time = 0.0
		return

	_air_time += delta
	_peak_y = maxf(_peak_y, global_position.y)
	if on_floor:
		MovementStats.record_landing(_ground_y, _peak_y, global_position.y, _air_time)
		_airborne = false
		_ground_y = global_position.y


## Double-tapping forward starts running and it lasts while forward is held.
## The separate `sprint` action still works for tests and controllers.
func _update_run_state(crouching: bool) -> void:
	if crouching or not Input.is_action_pressed("move_forward"):
		_run_engaged = false
		return

	if Input.is_action_pressed("sprint"):
		_run_engaged = true

	if Input.is_action_just_pressed("move_forward"):
		var now := Time.get_ticks_msec()
		if now - _last_forward_press_msec <= int(run_double_tap_window * 1000.0):
			_run_engaged = true
		_last_forward_press_msec = now


## Blends the head between standing and crouched height. Collision is left
## alone so crouching can never wedge the player inside geometry.
func _update_crouch(crouching: bool, delta: float) -> void:
	_crouching = crouching
	var target_height := _head_stand_height
	if crouching:
		target_height -= crouch_head_drop
	_blend_head(target_height, delta)


## Moves the head toward `target_height` at a fixed rate. Used by both the
## crouch and the seated pose so there is only one blending rule.
func _blend_head(target_height: float, delta: float) -> void:
	_head.position.y = move_toward(
		_head.position.y, target_height, crouch_blend_speed * delta
	)


func is_crouching() -> bool:
	return _crouching


func is_running() -> bool:
	return _run_engaged


## Chooses the locomotion clip from the current speed and airborne state.
## The clips themselves live in player.tscn; this only selects and blends them.
func _update_animation() -> void:
	if _animation_player == null or _attack_lock > 0.0:
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


# --- progression bonuses ----------------------------------------------------
#
# Skills and shop upgrades are owned by `Progression`; this controller only
# turns their ranks into numbers the scene uses. Called on ready, after a save
# loads, and whenever a panel buys a rank.


## Recomputes every stat bonus from the current progression ranks.
func apply_progression() -> void:
	var stride := (
		0.08 * Progression.get_skill_level(Progression.SKILL_LONG_STRIDE)
		+ 0.05 * Progression.get_upgrade_level(Progression.UPGRADE_BOOTS)
	)
	walk_speed = _base_walk_speed * (1.0 + stride)
	sprint_speed = _base_sprint_speed * (1.0 + stride)

	var new_max_health := _base_max_health + (
		15.0 * Progression.get_skill_level(Progression.SKILL_IRON_SKIN)
		+ 10.0 * Progression.get_upgrade_level(Progression.UPGRADE_CHARM)
	)
	_apply_max_health(new_max_health)

	var new_max_stamina := _base_max_stamina + (
		12.0 * Progression.get_skill_level(Progression.SKILL_DEEP_LUNGS)
	)
	_apply_max_stamina(new_max_stamina)

	_inventory.capacity = _base_inventory_capacity + (
		6 * Progression.get_upgrade_level(Progression.UPGRADE_BACKPACK)
	)


## Grows the health pool while keeping the current health at the same fraction,
## so a mid-run upgrade does not look like a sudden wound or a free heal.
func _apply_max_health(new_max: float) -> void:
	if is_equal_approx(_health.max_health, new_max):
		return
	var fraction := _health.get_fraction()
	_health.max_health = new_max
	_health.set_health(fraction * new_max)


func _apply_max_stamina(new_max: float) -> void:
	if is_equal_approx(_stats.max_stamina, new_max):
		return
	var fraction := _stats.get_fraction()
	_stats.max_stamina = new_max
	_stats.set_stamina(fraction * new_max)


## Extra melee damage from Keen Edge and the Whetstone shop upgrade.
func get_bonus_damage() -> float:
	return (
		2.0 * Progression.get_skill_level(Progression.SKILL_KEEN_EDGE)
		+ 1.0 * Progression.get_upgrade_level(Progression.UPGRADE_WHETSTONE)
	)


# --- flashlight -------------------------------------------------------------


func toggle_flashlight() -> void:
	_flashlight.visible = not _flashlight.visible
	Events.notification_requested.emit(
		"Flashlight on" if _flashlight.visible else "Flashlight off"
	)


func is_flashlight_on() -> bool:
	return _flashlight.visible


# --- components and player-facing API --------------------------------------
#
# UI and interactables talk to the player through these, never by reaching into
# its child nodes. See AGENTS.md section 6.


func get_health_component() -> HealthComponent:
	return _health


func get_stats_component() -> StatsComponent:
	return _stats


func get_inventory_component() -> InventoryComponent:
	return _inventory


func get_equipment_component() -> EquipmentComponent:
	return _equipment


## The spell caster is a sibling component, not owned by the controller. Stones
## ask the player for it through this method instead of a scene path.
func get_spell_caster() -> SpellCaster:
	return get_node_or_null("%SpellCaster") as SpellCaster


## Called by interactables that hand the player loot (chests, pickups).
func add_item(data: ItemData, amount: int = 1) -> int:
	return _inventory.add_item(data, amount)


## Equips an item from the inventory. Returns false when it cannot be equipped.
func try_equip(id: StringName) -> bool:
	return _equipment.equip(id)


## Consumes a consumable. Returns false when nothing was restored.
func use_item(id: StringName) -> bool:
	var data := ItemDatabase.get_item(id)
	if data == null or not data.is_consumable() or not _inventory.has_item(id):
		return false

	var restored := 0.0
	if data.restore_health > 0.0:
		restored += _health.heal(data.restore_health)
	if data.restore_stamina > 0.0:
		restored += _stats.restore_stamina(data.restore_stamina)
	if data.restore_mana > 0.0:
		restored += _stats.restore_mana(data.restore_mana)
	if data.restore_silk > 0.0:
		restored += _stats.repair_silk(data.restore_silk)
	if data.grant_anchoring > 0 and _stats.grant_anchoring(data.grant_anchoring) > 0:
		restored += 1.0
	if restored <= 0.0:
		return false

	_inventory.remove_item(id, 1)
	Events.notification_requested.emit("Used %s" % data.display_name)
	return true


## Called by environment volumes (see `RiverWade`). A scale of 1.0 is normal.
## Clamped so a bad value cannot freeze or rocket the player.
func set_environment_speed(scale: float) -> void:
	_environment_speed_scale = clampf(scale, 0.2, 2.0)


func get_environment_speed() -> float:
	return _environment_speed_scale


## UI calls this while a panel owns the mouse. Movement and look are suspended.
func set_ui_blocked(blocked: bool) -> void:
	_ui_blocked = blocked
	if not blocked:
		return

	velocity = Vector3.ZERO
	_current_animation = &""
	if _animation_player != null:
		_animation_player.play(&"idle", 0.1)


func is_ui_blocked() -> bool:
	return _ui_blocked


## Moves the player to `position` without a scene change. Used by map fast
## travel, where the destination is in the scene the player is already in.
## Velocity is cleared so the body does not keep its old momentum, and the
## airborne jump is refreshed so the player lands normally at the far end.
func teleport_to(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_air_jumps_left = 1
	_current_animation = &""
	if _animation_player != null:
		_animation_player.play(&"idle", 0.1)


## E on a chair asks the player to sit here. The chair passes its own position
## and facing, so a chair never has to know how the camera or movement works.
func sit_at(seat_position: Vector3, seat_yaw: float) -> void:
	if _sitting:
		return

	_sitting = true
	_run_engaged = false
	_crouching = false
	velocity = Vector3.ZERO
	# Slide onto the seat horizontally but keep the current floor height, so a
	# chair can never push the player through the floor.
	global_position = Vector3(seat_position.x, global_position.y, seat_position.z)
	rotation.y = seat_yaw
	_interaction_component.call("set_paused", true)

	_current_animation = &""
	if _animation_player != null:
		_animation_player.play(&"idle", 0.1)


## Stands the player back up. Called by E while seated and on load.
func stand_up() -> void:
	if not _sitting:
		return

	_sitting = false
	_interaction_component.call("set_paused", false)


func is_sitting() -> bool:
	return _sitting


## Plays the swing clip and holds the locomotion machine off until it finishes.
func play_attack_animation() -> void:
	if _attack_lock > 0.0 or _animation_player == null:
		return

	var clip := _animation_player.get_animation(&"attack")
	if clip == null:
		return

	_attack_lock = clip.length
	_current_animation = &"attack"
	_animation_player.play(&"attack", 0.08)


# --- persistence -----------------------------------------------------------
#
# The player root is the aggregate saveable: it owns position and look, and it
# asks each component for its own slice of state. Components never write save
# files themselves. See AGENTS.md section 8.


func get_save_id() -> StringName:
	return SAVE_ID


func save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": _pitch,
		"third_person": camera_mode == CameraMode.THIRD_PERSON,
		"health": _health.get_health(),
		"stamina": _stats.get_stamina(),
		"mana": _stats.get_mana(),
		"silk": _stats.get_silk(),
		"anchoring": _stats.get_anchoring(),
		"inventory": _inventory.save_data(),
		"equipment": _equipment.save_data(),
	}


func load_data(data: Dictionary) -> void:
	stand_up()
	_head.position.y = _head_stand_height

	var position: Array = data.get("position", [])
	if position.size() == 3:
		global_position = Vector3(
			float(position[0]), float(position[1]), float(position[2])
		)
		velocity = Vector3.ZERO

	rotation.y = float(data.get("yaw", rotation.y))
	_pitch = clampf(
		float(data.get("pitch", _pitch)),
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
	_head.rotation.x = _pitch

	var third_person := bool(data.get("third_person", false))
	_set_camera_mode(
		CameraMode.THIRD_PERSON if third_person else CameraMode.FIRST_PERSON
	)

	# Progression is restored before saveables, so the new maximums exist before
	# the saved current values are clamped into them.
	apply_progression()

	_health.set_health(maxf(float(data.get("health", _health.get_max_health())), MIN_LOADED_HEALTH))
	_stats.set_stamina(float(data.get("stamina", _stats.get_max_stamina())))
	_stats.set_mana(float(data.get("mana", _stats.get_max_mana())))
	_stats.set_silk(float(data.get("silk", _stats.get_max_silk())))
	_stats.set_anchoring(int(data.get("anchoring", 0)))
	_inventory.load_data(data.get("inventory", {}))
	_equipment.load_data(data.get("equipment", {}))
	# The inventory slice also stores capacity, so recompute the upgrade bonus
	# after it loads to keep shop slots from being overwritten by the file.
	apply_progression()
