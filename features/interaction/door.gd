extends StaticBody3D
## A simple hinged door. Place the node origin at the hinge.
##
## The door blocks the player and the third-person camera, and is detected by
## the interaction ray because its collision layer includes `interactable`.

@export var open_angle_degrees: float = -100.0
@export var open_time: float = 0.35

var is_open := false
var _closed_rotation := 0.0
var _tween: Tween


func _ready() -> void:
	_closed_rotation = rotation.y


func get_interaction_text() -> String:
	return "Close door" if is_open else "Open door"


func interact(_interactor: Node) -> void:
	is_open = not is_open

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_rotation := _closed_rotation
	if is_open:
		target_rotation += deg_to_rad(open_angle_degrees)

	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", target_rotation, open_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
