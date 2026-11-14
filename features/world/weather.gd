class_name Weather
extends Node3D
## Rain and heavy mist, decided by the calendar rather than by a dice roll.
##
## The point of deriving the weather from `WorldClock.day` is that it needs no
## save state at all: load an old save, walk outside, and the weather for that
## day is the weather that day always had. A new day rolls over on its own.
##
## This node owns one rain emitter and one number (the calm fog density handed to
## `FogSurge`). It never touches the sun: `FogSurge` already dims it for mist, and
## two systems fighting over `light_energy` is how a sunny day ends up black.
##
## Rain is atmosphere only. It does not slow the player, wet anything, or pool.

## Weather kinds. Ordinary integers so a save never has to know about them.
const CLEAR := 0
const RAIN := 1
const FOG := 2

## Fog density while the air is clear. Matches `FogSurge.normal_density`.
@export var clear_density: float = 0.0022
## Fog density in rain: thicker than clear, much thinner than a mist day.
@export var rain_density: float = 0.0042
## Fog density on a mist day. Deliberately heavy, but still below a fog surge.
@export var fog_density: float = 0.0085

@export var rain_amount: int = 400
@export var rain_area: float = 15.0
@export var rain_height: float = 9.0

var _kind := CLEAR
var _day := -1
var _rain: CPUParticles3D
var _fog: Node
var _player: Node3D
var _tick := 0.0


func _ready() -> void:
	add_to_group(&"weather")
	_fog = get_node_or_null("../FogSurge")
	_build_rain()
	_apply(WorldClock.get_day())


func is_raining() -> bool:
	return _kind == RAIN


func is_misty() -> bool:
	return _kind == FOG


## What kind of weather a given day has. Exposed so a test can assert the
## calendar rule without waiting for a day to pass.
static func kind_for_day(day: int) -> int:
	var roll := posmod(day, 7)
	if roll == 0 or roll == 4:
		return RAIN
	if roll == 2:
		return FOG
	return CLEAR


## Re-reads the clock and applies the weather for today. Used by tests.
func refresh_now() -> void:
	_apply(WorldClock.get_day())


func _process(delta: float) -> void:
	# Rain follows the player, but only twice a second: a full reset every frame
	# would restart the emitter and the rain would stutter.
	if _rain != null and _rain.emitting:
		_tick += delta
		if _tick >= 0.5:
			_tick = 0.0
			_follow_player()

	var day := WorldClock.get_day()
	if day != _day:
		_apply(day)


func _apply(day: int) -> void:
	_day = day
	_kind = kind_for_day(day)

	if _rain != null:
		_rain.emitting = _kind == RAIN
		if _rain.emitting:
			_follow_player()

	var density := clear_density
	if _kind == RAIN:
		density = rain_density
	elif _kind == FOG:
		density = fog_density
	if _fog != null and _fog.has_method("set_base_density"):
		_fog.call("set_base_density", density)


func _follow_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null or _rain == null:
		return
	_rain.global_position = _player.global_position + Vector3(0, rain_height, 0)


func _build_rain() -> void:
	if _rain != null:
		return

	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = rain_amount
	_rain.lifetime = 1.1
	_rain.local_coords = false
	_rain.emitting = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(rain_area, 0.5, rain_area)
	_rain.direction = Vector3(0, -1, 0)
	_rain.spread = 3.0
	_rain.gravity = Vector3(0, -26, 0)
	_rain.initial_velocity_min = 2.0
	_rain.initial_velocity_max = 4.0
	_rain.scale_amount_min = 0.7
	_rain.scale_amount_max = 1.2

	var drop := QuadMesh.new()
	drop.size = Vector2(0.02, 0.42)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.78, 0.86, 0.55)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = material
	_rain.mesh = drop

	add_child(_rain)
