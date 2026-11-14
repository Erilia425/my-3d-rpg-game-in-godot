extends Node3D
## A decorative forest wisp: a soft 2D light that bobs and drifts in place.
##
## The 2D game used the wisp sprite only as scenery, so this node has no
## interaction, collision, or gameplay. It keeps the original art visible at the
## forest edge while staying cheap: one billboard sprite moved in `_process`.

@export var bob_height: float = 0.25
@export var bob_speed: float = 2.0
@export var drift_radius: float = 2.5
@export var drift_speed: float = 0.35

var _origin: Vector3
var _phase: float = 0.0

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	_origin = position
	_phase = randf() * TAU

	if _sprite == null or _sprite.sprite_frames == null:
		return
	var names := _sprite.sprite_frames.get_animation_names()
	if names.is_empty():
		return
	var animation := StringName(names[0])
	if _sprite.sprite_frames.get_frame_count(animation) > 0:
		_sprite.play(animation)


func _process(delta: float) -> void:
	_phase += delta * drift_speed
	position.x = _origin.x + sin(_phase) * drift_radius
	position.z = _origin.z + cos(_phase * 0.8) * drift_radius
	position.y = _origin.y + sin(_phase * bob_speed) * bob_height
