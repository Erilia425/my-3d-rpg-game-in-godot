class_name Guest
extends CharacterBody3D
## The Guest: a fungal spirit ported from the 2D game.
##
## It drifts around until it notices the player, then closes in and throws
## itself forward in a short lunge. Getting hit flashes it red; dying dissolves
## it into a puff of spores. It keeps the `enemy` group and a `HealthComponent`
## so the player's `AttackComponent` finds and damages it unchanged.
##
## No navigation mesh: like the placeholder enemy, it walks in a straight line
## and can be blocked by walls. See AGENTS.md sections 4 and 7.

enum State {
	WANDER,
	CHASE,
	LUNGE,
	RECOVER,
	DEAD,
}

const SMOKE_PUFFS := 9
const SMOKE_TEXTURE_SIZE := 64
const SMOKE_SIZE_METRES := 0.9

@export_group("Movement")
@export var wander_speed: float = 1.1
@export var chase_speed: float = 2.4
@export var turn_speed: float = 7.0
@export var gravity: float = 18.0

@export_group("Combat")
@export var detection_range: float = 9.0
## Distance at which a lunge starts.
@export var attack_range: float = 2.0
@export var attack_damage: float = 2.0
@export var attack_cooldown: float = 1.1
## How far the lunge carries the Guest forward.
@export var lunge_distance: float = 1.2
@export var lunge_duration: float = 0.18
@export var recovery_duration: float = 0.22

@export_group("Dissolve")
@export var dissolve_duration: float = 1.2
@export var dissolve_rise: float = 0.7
## Items it may drop when defeated. One is chosen at random.
@export var drop_items: Array[StringName] = [&"item.mushroom", &"item.flower"]

@export_group("Persistence")
@export var save_id: StringName = &""

@export_group("The Ledger")
## True for Guests that answer the player's Ledger. A fixed, authored encounter
## sets this false so its difficulty cannot drift with the player's imbalance.
@export var answers_the_ledger: bool = true

var state: State = State.WANDER

var _target: Node3D
var _health: HealthComponent
var _cooldown := 0.0
var _wander_direction := Vector3.ZERO
var _wander_timer := 0.0
var _flash_tween: Tween
var _lunge_tween: Tween
var _rng := RandomNumberGenerator.new()

@onready var _visual: Node3D = %Visual
@onready var _sprite: AnimatedSprite3D = %AnimatedSprite
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_rng.randomize()
	_health = $HealthComponent as HealthComponent
	if _health != null:
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)

	_fit_sprite_height()
	_answer_the_ledger()

	_target = get_tree().get_first_node_in_group("player") as Node3D
	_pick_wander_direction()

	if not save_id.is_empty():
		add_to_group(&"saveable")


## A Guest the Ledger sent arrives already changed by how loudly the record is
## speaking. The multiplier is read once, on arrival, so a Guest already in the
## world keeps the strength it came with and a save restores it unchanged.
func _answer_the_ledger() -> void:
	if not answers_the_ledger:
		return

	var scale := Ledger.get_escalation_scale()
	if is_equal_approx(scale, 1.0):
		return

	attack_damage *= scale
	detection_range *= scale

	if _health != null:
		_health.max_health = roundf(_health.max_health * scale)
		_health.set_health(_health.max_health)


## Frame height sets the scale, so the spirit is about 1.9 m tall whatever the
## source art resolution happens to be.
func _fit_sprite_height() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var names := _sprite.sprite_frames.get_animation_names()
	if names.is_empty():
		return
	var animation := StringName(names[0])
	if _sprite.sprite_frames.get_frame_count(animation) <= 0:
		return
	var texture := _sprite.sprite_frames.get_frame_texture(animation, 0)
	if texture == null:
		return
	_sprite.pixel_size = 1.9 / float(maxi(texture.get_height(), 1))
	if not _sprite.is_playing():
		_sprite.play(animation)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if Game.state != Game.State.PLAYING:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	_cooldown = maxf(_cooldown - delta, 0.0)

	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D

	# The lunge tween owns the body while it runs.
	if state == State.LUNGE or state == State.RECOVER:
		return

	var distance := INF
	if is_instance_valid(_target):
		distance = global_position.distance_to(_target.global_position)

	if distance > detection_range:
		_wander(delta)
	elif distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		_face(_target.global_position, delta)
		if _cooldown <= 0.0:
			_lunge()
	else:
		_chase(delta)

	move_and_slide()


func get_state_name() -> StringName:
	match state:
		State.WANDER:
			return &"WANDER"
		State.CHASE:
			return &"CHASE"
		State.LUNGE:
			return &"LUNGE"
		State.RECOVER:
			return &"RECOVER"
		State.DEAD:
			return &"DEAD"
	return &"UNKNOWN"


func get_health_component() -> HealthComponent:
	return _health


# --- movement --------------------------------------------------------------


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()

	var step := _wander_direction * wander_speed
	velocity.x = step.x
	velocity.z = step.z
	_face(global_position + _wander_direction, delta)


func _pick_wander_direction() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	_wander_direction = Vector3(sin(angle), 0.0, cos(angle))
	_wander_timer = _rng.randf_range(1.5, 3.5)


func _chase(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	var offset := _target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return

	var direction := offset.normalized()
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	_face(_target.global_position, delta)


## Turns smoothly toward a world point. A billboard sprite still needs a facing
## so the lunge carries it in the right direction and name labels stay readable.
func _face(point: Vector3, delta: float) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) < 0.05:
		return
	var direction := (flat - global_position).normalized()
	var wanted := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, wanted, clampf(turn_speed * delta, 0.0, 1.0))


# --- lunge -----------------------------------------------------------------


func _lunge() -> void:
	if not is_instance_valid(_target):
		return

	_cooldown = attack_cooldown
	state = State.LUNGE
	velocity = Vector3.ZERO

	# A quick snap to face the player before the body travels forward.
	var offset := _target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		var direction := offset.normalized()
		rotation.y = atan2(-direction.x, -direction.z)

	var forward := -global_basis.z
	var start := global_position
	var end := start + forward * lunge_distance

	if _lunge_tween != null and _lunge_tween.is_valid():
		_lunge_tween.kill()

	_lunge_tween = create_tween()
	_lunge_tween.tween_property(self, "global_position", end, lunge_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_callback(_on_lunge_reached)
	_lunge_tween.tween_callback(func() -> void: state = State.RECOVER)
	_lunge_tween.tween_property(self, "global_position", start, recovery_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_lunge_tween.tween_callback(func() -> void: state = State.CHASE)


func _on_lunge_reached() -> void:
	if not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > attack_range + 0.8:
		return

	var health := _target.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		return

	# Flat armor reduction, matching the placeholder enemy.
	var armor := 0.0
	var equipment := _target.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if equipment != null:
		armor = equipment.get_armor_value()

	health.take_damage(maxf(attack_damage - armor, 1.0))


# --- hit feedback and death ------------------------------------------------


func _on_damaged(_amount: float) -> void:
	if _sprite == null or state == State.DEAD:
		return

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_sprite.modulate = Color(1.0, 0.32, 0.32, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _on_died() -> void:
	_apply_dead(true)


## Puts the Guest in its defeated state. `animated` is false when a save is
## restoring a Guest that already died, so a reload is instant and silent.
func _apply_dead(animated: bool) -> void:
	state = State.DEAD
	velocity = Vector3.ZERO

	if _lunge_tween != null and _lunge_tween.is_valid():
		_lunge_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

	_collision.set_deferred("disabled", true)
	set_physics_process(false)

	if _health != null and not _health.is_dead():
		_health.set_health(0.0)

	if not animated:
		visible = false
		return

	_dissolve()
	_drop_loot()
	Events.notification_requested.emit("The Guest dissolves into spores")


## Fades the spirit out while a ring of soft grey puffs rises and spreads.
func _dissolve() -> void:
	var texture := _smoke_texture()

	for i in SMOKE_PUFFS:
		var puff := Sprite3D.new()
		puff.texture = texture
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.shaded = false
		puff.double_sided = true
		puff.transparent = true
		puff.pixel_size = SMOKE_SIZE_METRES / float(SMOKE_TEXTURE_SIZE)
		puff.no_depth_test = false

		var angle := TAU * float(i) / float(SMOKE_PUFFS)
		var radius := _rng.randf_range(0.05, 0.3)
		puff.position = Vector3(
			cos(angle) * radius,
			_rng.randf_range(0.35, 0.95),
			sin(angle) * radius
		)
		puff.modulate = Color(1, 1, 1, 0.9)
		add_child(puff)

		var rise := dissolve_rise * _rng.randf_range(0.7, 1.2)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position:y", puff.position.y + rise, dissolve_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * _rng.randf_range(1.8, 2.6), dissolve_duration)
		tween.tween_property(puff, "modulate:a", 0.0, dissolve_duration)
		tween.chain().tween_callback(puff.queue_free)

	if _sprite != null:
		var fade := create_tween()
		fade.set_parallel(true)
		fade.tween_property(_sprite, "modulate:a", 0.0, dissolve_duration * 0.7)
		fade.tween_property(_sprite, "scale", Vector3(0.2, 0.2, 0.2), dissolve_duration * 0.7)

	var hide_tween := create_tween()
	hide_tween.tween_interval(dissolve_duration + 0.1)
	hide_tween.tween_callback(func() -> void: visible = false)


## A soft radial dot, built in code because the supplied smoke image has a
## checkerboard baked into it instead of real transparency.
func _smoke_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.88, 0.88, 0.84, 0.85))
	gradient.set_color(1, Color(0.78, 0.78, 0.73, 0.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = SMOKE_TEXTURE_SIZE
	texture.height = SMOKE_TEXTURE_SIZE
	return texture


## Hands one remembered foraging item to the player, mirroring the 2D drop.
func _drop_loot() -> void:
	if drop_items.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("add_item"):
		return

	var id := drop_items[_rng.randi_range(0, drop_items.size() - 1)]
	var data := ItemDatabase.get_item(id)
	if data == null:
		return

	var granted := int(player.call("add_item", data, 1))
	if granted > 0:
		Events.notification_requested.emit("%s collected" % data.display_name)


# --- persistence -----------------------------------------------------------
#
# Like the placeholder enemy: position, facing, health, and whether it is
# already defeated. A defeated Guest stays defeated.


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"health": 0.0 if _health == null else _health.get_health(),
		"dead": state == State.DEAD,
	}


func load_data(data: Dictionary) -> void:
	var position: Array = data.get("position", [])
	if position.size() == 3:
		global_position = Vector3(
			float(position[0]), float(position[1]), float(position[2])
		)
		velocity = Vector3.ZERO

	rotation.y = float(data.get("yaw", rotation.y))

	if bool(data.get("dead", false)):
		_apply_dead(false)
		return

	var health := float(data.get("health", -1.0))
	if health > 0.0 and _health != null:
		_health.set_health(health)
