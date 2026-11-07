extends CharacterBody2D

const SPEED = 200.0
const JUMP_HEIGHT = 20.0
const JUMP_TIME = 0.4

@onready var sprite = $Sprite2D/Sprite2D

var jumping = false
var jump_timer = 0.0
var original_position = Vector2.ZERO
var original_scale = Vector2.ONE

func _ready() -> void:
	original_position = sprite.position
	original_scale = sprite.scale

func _physics_process(delta: float) -> void:
	var direction = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO

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
			sprite.position = original_position
		else:
			sprite.position.y = original_position.y - sin(progress * PI) * JUMP_HEIGHT

	# Crouch
	if Input.is_action_pressed("crouch") and not jumping:
		sprite.scale = Vector2(
			original_scale.x,
			original_scale.y * 0.65
		)
	else:
		sprite.scale = original_scale
