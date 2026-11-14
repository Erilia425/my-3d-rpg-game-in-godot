class_name RiverWade
extends Area3D
## A stretch of river deep enough to wade through.
##
## The realm's rivers are translucent sheets over walkable ground, so nothing
## physically stops the player. This area makes the water *felt*: inside it the
## player moves at `speed_scale` and the first step in says so once. Bridges and
## fords stay the dry, fast way across.
##
## The area owns no player state. It asks the player to slow down and lets go on
## exit; overlapping stretches are counted so two rivers cannot leave the player
## permanently slowed.

## Fraction of normal speed while wading.
@export var speed_scale: float = 0.55
## Shown the first time the player steps in.
@export var entry_message: String = "The current pulls at your knees."

var _bodies: Dictionary = {}
var _announced := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player only
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("set_environment_speed"):
		return
	_bodies[body] = int(_bodies.get(body, 0)) + 1
	body.call("set_environment_speed", speed_scale)
	if not _announced:
		_announced = true
		Events.notification_requested.emit(entry_message)


func _on_body_exited(body: Node) -> void:
	if body == null or not _bodies.has(body):
		return
	var remaining := int(_bodies[body]) - 1
	if remaining > 0:
		_bodies[body] = remaining
		return
	_bodies.erase(body)
	if body.has_method("set_environment_speed"):
		body.call("set_environment_speed", 1.0)


## True while at least one body is wading. Used by tests.
func is_occupied() -> bool:
	return not _bodies.is_empty()
