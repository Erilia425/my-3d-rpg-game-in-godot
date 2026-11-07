
extends CharacterBody2D

const SPEED = 200.0
const RUN_SPEED = 320.0

const JUMP_HEIGHT = 25.0
const JUMP_TIME = 0.4

const MAX_HEALTH = 5
const ATTACK_RANGE = 60.0
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 0.5

const SPOREBREAD_HEAL = 2

var health = MAX_HEALTH
var jumping = false
var jump_timer = 0.0
var crouching = false
var attack_timer = 0.0
var game_over = false

@onready var sprite = $Sprite2D

var normal_scale = Vector2.ONE


func _ready():
	add_to_group("player")
	normal_scale = sprite.scale
	update_health_bar()

	print("Fern health: ", health, "/", MAX_HEALTH)
	print("Hold Shift to run.")
	print("Press R to eat Sporebread and restore health.")


func _physics_process(delta):
	if game_over:
		velocity = Vector2.ZERO
		return

	attack_timer = maxf(0.0, attack_timer - delta)

	var direction = Vector2.ZERO

	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	# Crouch
	crouching = Input.is_action_pressed("crouch") and not jumping

	if crouching:
		sprite.scale = Vector2(
			normal_scale.x,
			normal_scale.y * 0.65
		)
	else:
		sprite.scale = normal_scale

	# Running: hold Shift while moving, unless crouching.
	var current_speed = SPEED

	if Input.is_action_pressed("run") and not crouching:
		current_speed = RUN_SPEED

	velocity = direction.normalized() * current_speed
	move_and_slide()

	# Jump
	if Input.is_action_pressed("jump") and not jumping:
		jumping = true
		jump_timer = 0.0

	if jumping:
		jump_timer += delta
		var progress = jump_timer / JUMP_TIME

		if progress >= 1.0:
			jumping = false
			sprite.position.y = 0
		else:
			sprite.position.y = -sin(progress * PI) * JUMP_HEIGHT

	# Attack with F
	if Input.is_action_pressed("attack") and attack_timer <= 0.0:
		attack()


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("eat"):
			eat_sporebread()


func eat_sporebread():
	if game_over:
		return

	if health >= MAX_HEALTH:
		print("Fern is already at full health!")
		return

	if GlobalInventory.inventory.get("Sporebread", 0) <= 0:
		print("Fern has no Sporebread to eat!")
		return

	# Consume one Sporebread.
	GlobalInventory.inventory["Sporebread"] -= 1

	# Restore health without exceeding the maximum.
	var old_health = health
	health = mini(MAX_HEALTH, health + SPOREBREAD_HEAL)

	update_health_bar()

	print(
		"Fern ate Sporebread! Health: ",
		old_health, " -> ", health, "/", MAX_HEALTH
	)
	print(
		"Sporebread remaining: ",
		GlobalInventory.inventory["Sporebread"]
	)


func attack():
	attack_timer = ATTACK_COOLDOWN
	var hit_something = false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("take_damage"):
			var distance = global_position.distance_to(
				enemy.global_position
			)

			if distance <= ATTACK_RANGE:
				enemy.take_damage(ATTACK_DAMAGE)
				hit_something = true
				print("Fern hit the enemy!")

	if not hit_something:
		print("Fern swings, but hits nothing.")


func update_health_bar():
	var health_bar = get_node_or_null("HealthBar")

	if health_bar:
		health_bar.max_value = MAX_HEALTH
		health_bar.value = health


func take_damage(amount: int = 1):
	if game_over:
		return

	health = maxi(0, health - amount)
	update_health_bar()

	print("Fern took damage! Health: ", health, "/", MAX_HEALTH)

	if health <= 0:
		game_over = true
		velocity = Vector2.ZERO
		print("Fern has been defeated! Game over.")


func add_item(item_name):
	GlobalInventory.add_item(item_name)
