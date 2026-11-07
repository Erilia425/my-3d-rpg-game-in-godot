
extends CharacterBody2D

@export var wander_speed: float = 40.0
@export var chase_speed: float = 85.0
@export var detection_range: float = 200.0
@export var attack_range: float = 30.0
@export var health: int = 3
@export var attack_damage: int = 1

@export var lunge_distance: float = 60.0
@export var lunge_duration: float = 0.18
@export var recovery_duration: float = 0.22

@export var dissolve_duration: float = 1.2
@export var dissolve_rise_distance: float = 18.0

var player: Node2D = null
var state: String = "wander"
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var chase_timer: float = 0.0
var attack_cooldown: float = 0.0

var attack_tween: Tween
var movement_tween: Tween
var dissolve_tween: Tween
var damage_flash_tween: Tween

var attacking: bool = false
var defeated: bool = false


func _ready():
	player = get_tree().get_root().find_child("player", true, false)
	print("Guest found player: ", player)

	choose_wander_direction()
	print("Guest wander direction: ", wander_direction)

	update_health_bar()


func _physics_process(delta):
	if defeated or health <= 0:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_root().find_child("player", true, false)

	if player == null:
		return

	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if attacking:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance < detection_range:
		state = "chase"
		chase_timer = 3.0

	elif state == "chase":
		chase_timer -= delta

		if chase_timer <= 0.0:
			state = "wander"

	if state == "chase" and distance <= attack_range:
		velocity = Vector2.ZERO

		if attack_cooldown <= 0.0:
			attack()

	elif state == "chase":
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * chase_speed

	else:
		wander_timer -= delta

		if wander_timer <= 0.0:
			choose_wander_direction()

		velocity = wander_direction * wander_speed

	move_and_slide()


func choose_wander_direction():
	wander_direction = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	wander_timer = randf_range(1.0, 3.0)


func attack():
	if attacking or defeated or attack_cooldown > 0.0:
		return

	attacking = true
	attack_cooldown = 1.5
	velocity = Vector2.ZERO

	print("The Guest prepares to lunge!")

	var original_position = global_position
	var direction = Vector2.RIGHT

	if player and is_instance_valid(player):
		direction = global_position.direction_to(player.global_position)

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

	var lunge_position = original_position + direction * lunge_distance
	var sprite = get_node_or_null("Sprite2D2")

	if sprite:
		if direction.x != 0.0:
			sprite.flip_h = direction.x < 0.0

		var original_scale = sprite.scale
		var original_rotation = sprite.rotation

		if attack_tween and attack_tween.is_running():
			attack_tween.kill()

		attack_tween = create_tween()
		attack_tween.set_parallel(true)

		attack_tween.tween_property(
			sprite,
			"scale",
			original_scale * Vector2(1.2, 0.85),
			lunge_duration
		)

		attack_tween.tween_property(
			sprite,
			"rotation",
			original_rotation + direction.y * 0.15,
			lunge_duration
		)

	else:
		print("WARNING: Sprite2D2 was not found!")

	movement_tween = create_tween()

	movement_tween.tween_property(
		self,
		"global_position",
		lunge_position,
		lunge_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	movement_tween.tween_callback(deal_lunge_damage)

	movement_tween.tween_property(
		self,
		"global_position",
		original_position,
		recovery_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	movement_tween.tween_callback(finish_attack)


func deal_lunge_damage():
	if defeated or not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= attack_range + 20.0:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
			print("The Guest's lunge hit Fern!")
	else:
		print("Fern dodged the Guest's lunge!")


func finish_attack():
	if defeated:
		return

	attacking = false
	velocity = Vector2.ZERO

	var sprite = get_node_or_null("Sprite2D2")

	if sprite:
		var reset_tween = create_tween()
		reset_tween.set_parallel(true)

		reset_tween.tween_property(
			sprite,
			"scale",
			Vector2.ONE,
			0.1
		)

		reset_tween.tween_property(
			sprite,
			"rotation",
			0.0,
			0.1
		)

	print("The Guest recovers from its lunge.")


func update_health_bar():
	var health_bar = find_child("HealthBar", true, false)

	if health_bar:
		health_bar.max_value = 3
		health_bar.value = health


func take_damage(amount: int = 1):
	if defeated or health <= 0:
		return

	health = maxi(health - amount, 0)
	update_health_bar()

	if health <= 0:
		defeat()
	else:
		flash_red()

	print("The Guest is hurt. Health: ", health)


func flash_red():
	if defeated:
		return

	var sprite = get_node_or_null("Sprite2D2")

	if sprite == null:
		print("WARNING: Sprite2D2 was not found for damage flash!")
		return

	# Cancel the previous flash if another hit arrives.
	if damage_flash_tween and damage_flash_tween.is_running():
		damage_flash_tween.kill()

	# Flash bright red.
	sprite.modulate = Color(1.0, 0.15, 0.15, 1.0)

	damage_flash_tween = create_tween()
	damage_flash_tween.tween_interval(0.15)

	damage_flash_tween.tween_callback(func():
		if is_instance_valid(sprite) and not defeated:
			sprite.modulate = Color.WHITE
	)

	print("The Guest flashes red!")


func defeat():
	if defeated:
		return

	defeated = true
	health = 0
	attacking = false
	velocity = Vector2.ZERO

	print("The Guest dissolves into the mist.")

	# Stop attack and damage animations.
	if attack_tween and attack_tween.is_running():
		attack_tween.kill()

	if movement_tween and movement_tween.is_running():
		movement_tween.kill()

	if damage_flash_tween and damage_flash_tween.is_running():
		damage_flash_tween.kill()

	# Drop one random item.
	if randf() < 0.5:
		GlobalInventory.add_item("Mushroom")
	else:
		GlobalInventory.add_item("Flower")

	# Disable collision.
	set_collision_layer(0)
	set_collision_mask(0)

	# Hide the health bar.
	var health_bar = find_child("HealthBar", true, false)

	if health_bar:
		health_bar.visible = false

	# Start optional mist particles.
	var mist = get_node_or_null("MistParticles")

	if mist:
		mist.global_position = global_position
		mist.emitting = true

	var sprite = get_node_or_null("Sprite2D2")

	if sprite == null:
		print("No Sprite2D2 found. Removing Guest.")
		queue_free()
		return

	# Fade and shrink the Guest into mist.
	dissolve_tween = create_tween()
	dissolve_tween.set_parallel(true)

	dissolve_tween.tween_property(
		sprite,
		"modulate",
		Color(0.65, 0.75, 0.85, 0.0),
		dissolve_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	dissolve_tween.tween_property(
		sprite,
		"scale",
		sprite.scale * 0.15,
		dissolve_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Drift upward as the Guest disappears.
	dissolve_tween.chain().tween_property(
		self,
		"global_position",
		global_position + Vector2(0, -dissolve_rise_distance),
		0.4
	)

	dissolve_tween.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)
