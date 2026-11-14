class_name AmbientAudio
extends Node
## The Hollow's weather, made of two hand-synthesised loops.
##
## Day is a low wind; night is a drone with sparse crickets. A distant bell
## rings now and then after dark. The node lives in `scenes/town.tscn` only, so
## interiors keep their own quiet.
##
## No new autoload was added: this is a plain node that reads `WorldClock`. The
## loops live in `assets/audio/ambience/` and are original synthesis, not
## recordings. Volume is deliberately low; ambience should be noticed only when
## it stops.

const DAY_LOOP: AudioStream = preload("res://assets/audio/ambience/wind_soft.wav")
const NIGHT_LOOP: AudioStream = preload("res://assets/audio/ambience/night_hum.wav")
const BELL_ONE_SHOT: AudioStream = preload("res://assets/audio/ambience/bell_distant.wav")
const RIVER_LOOP: AudioStream = preload("res://assets/audio/ambience/river_flow.wav")
## Regional beds. One plays quietly under the day/night loop when the player
## stands in that part of the world, so the north does not sound like the south.
const MARSH_LOOP: AudioStream = preload("res://assets/audio/ambience/marsh_insects.wav")
const SNOW_LOOP: AudioStream = preload("res://assets/audio/ambience/snow_hush.wav")
const CAVE_LOOP: AudioStream = preload("res://assets/audio/ambience/cave_drips.wav")

@export var day_volume_db: float = -21.0
@export var night_volume_db: float = -23.0
@export var bell_volume_db: float = -20.0
## Trims the base loop while it rains, so the weather is heard through the wind.
@export var rain_trim_db: float = -6.0
## Bells wait at least this long between rings, and at most twice this long.
@export var bell_interval: float = 90.0

## Region bands in metres, matching the realm's floors. North of `NORTH` is the
## arctic shelf, south of `SOUTH` the marsh, east of `EAST` the desert.
const NORTH := -170.0
const SOUTH := 170.0
const EAST := 170.0

var _weather: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _region: AudioStreamPlayer
var _night := false
var _region_kind := &""
var _raining := false
var _tick := 0.0
var _bell_wait := 0.0
var _player: Node3D


func _ready() -> void:
	_weather = AudioStreamPlayer.new()
	_weather.name = "Weather"
	_weather.bus = &"Ambience"
	add_child(_weather)

	_bell = AudioStreamPlayer.new()
	_bell.name = "DistantBell"
	_bell.bus = &"Ambience"
	_bell.stream = BELL_ONE_SHOT
	_bell.volume_db = bell_volume_db
	add_child(_bell)

	_region = AudioStreamPlayer.new()
	_region.name = "Region"
	_region.bus = &"Ambience"
	_region.volume_db = -25.0
	add_child(_region)

	_bell_wait = bell_interval
	refresh_now()


## Re-reads the clock immediately. Used on ready and by tests.
func refresh_now() -> void:
	_set_night(_is_night())


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0

	_set_night(_is_night())
	_set_region(_region_for_player())
	refresh_weather()
	if not _night:
		return
	_bell_wait -= 1.0
	if _bell_wait <= 0.0:
		_bell_wait = randf_range(bell_interval, bell_interval * 2.0)
		_bell.play()


## Which regional bed the player is standing in, as a short tag. Empty means the
## town's own ground, where the base loop is enough.
func _region_for_player() -> StringName:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return &""
	var at := _player.global_position
	if at.z < NORTH:
		return &"snow"
	if at.z > SOUTH:
		return &"marsh"
	if at.x > EAST:
		return &"desert"
	return &""


func _set_region(kind: StringName) -> void:
	if kind == _region_kind:
		return
	_region_kind = kind
	var stream: AudioStream = null
	match kind:
		&"marsh":
			stream = MARSH_LOOP
		&"snow":
			stream = SNOW_LOOP
		_:
			stream = null
	if stream == null:
		_region.stop()
		return
	_region.stream = looped_wav(stream)
	_region.play()


## True while a regional bed is playing. Used by tests.
func get_region() -> StringName:
	return _region_kind


## Reads the rain flag from the scene's `Weather` node. A missing weather node
## simply means it never rains.
func refresh_weather() -> void:
	var weather := get_tree().get_first_node_in_group(&"weather")
	var raining: bool = (
		weather != null
		and weather.has_method("is_raining")
		and bool(weather.call("is_raining"))
	)
	if raining == _raining:
		return
	_raining = raining
	_weather.volume_db = (night_volume_db if _night else day_volume_db) + (rain_trim_db if _raining else 0.0)


func _is_night() -> bool:
	var hour := WorldClock.get_hour()
	return hour < 6.0 or hour >= 20.0


func _set_night(night: bool) -> void:
	if night == _night and _weather.playing:
		return
	_night = night
	_weather.stream = looped_wav(NIGHT_LOOP if night else DAY_LOOP)
	_weather.volume_db = (night_volume_db if night else day_volume_db) + (
		rain_trim_db if _raining else 0.0
	)
	_weather.play()


## True while the night loop is selected. Used by tests.
func is_night_playing() -> bool:
	return _night


## A WAV imported by Godot does not loop unless the importer was told to. Rather
## than depend on import settings, duplicate the stream and set the loop here.
static func looped_wav(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	var copy := wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	# The shipped loops are 16-bit mono, so two bytes per frame.
	copy.loop_end = int(copy.data.size() / 2)
	return copy


## One positional river loop for a polyline, owned by its `RiverWade` area.
static func make_river_loop(at: Vector3) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = "RiverSound"
	player.bus = &"Ambience"
	player.stream = looped_wav(RIVER_LOOP)
	player.position = at
	player.volume_db = -19.0
	player.max_distance = 85.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.autoplay = true
	return player
