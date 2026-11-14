extends Node3D
## Walks a cart around a loop of waypoints while the game is playing.
##
## The cart itself stays a `StaticBody3D`; this node is just the parent that
## moves, so the existing collision, billboard art, and interaction code all keep
## working unchanged. `waypoints` are offsets from wherever this node starts, so
## the same scene can be dropped anywhere in the town and still patrol locally.
##
## Movement pauses whenever the game is not in its PLAYING state (pause menu,
## dialogue, save screen), so the cart never creeps along behind a menu.

## Offset from the start position to each stop, walked in order and looped.
@export var waypoints: PackedVector3Array = PackedVector3Array()
## Metres per second along the path.
@export var speed: float = 1.2
## Seconds spent resting at each stop before moving on.
@export var pause_at_points: float = 1.5
## How quickly the cart turns to face the direction it is walking.
@export var turn_speed: float = 4.0

## How close counts as "arrived" at a stop.
const ARRIVE_DISTANCE := 0.2

var _home := Vector3.ZERO
var _index := 0
var _rest := 0.0
var _home_ready := false


func _ready() -> void:
	_capture_home()


func _physics_process(delta: float) -> void:
	if waypoints.is_empty():
		return

	if not _home_ready:
		_capture_home()

	# Hold still behind menus and cutscenes.
	if Game.state != Game.State.PLAYING:
		return

	if _rest > 0.0:
		_rest -= delta
		return

	var target := _home + waypoints[_index]
	var to_target := target - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	if distance <= ARRIVE_DISTANCE:
		_index = (_index + 1) % waypoints.size()
		_rest = pause_at_points
		return

	var step := minf(speed * delta, distance)
	global_position += to_target / distance * step

	# Face the way we are travelling. The cart art is a billboard, so this only
	# matters for any future non-billboard model or attached child.
	var yaw := atan2(to_target.x, to_target.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _capture_home() -> void:
	_home = global_position
	_home_ready = true
