class_name MusicPlayer
extends Node
## One looping music bed for the scene that owns it.
##
## Deliberately not an autoload: the six approved services stay the six approved
## services, and a track that dies with its scene is exactly what a menu theme
## and a town theme want. The WAV is looped at runtime, so Godot's import
## settings cannot silently break the loop.
##
## Volume rides the `Music` bus, which the pause menu and Settings own, so this
## node never needs to know about the audio settings screen.

@export var track: AudioStream
## Quiet by default. Music should be under the ambience, not over it.
@export var volume_db: float = -17.0
@export var autoplay: bool = true
## Seconds of fade-in. A hard start on a scene change sounds like a mistake.
@export var fade_in: float = 2.5

var _player: AudioStreamPlayer
var _fade_left := 0.0


func _ready() -> void:
	if track == null:
		return

	_player = AudioStreamPlayer.new()
	_player.name = "Track"
	_player.bus = &"Music"
	_player.stream = AmbientAudio.looped_wav(track)
	_player.volume_db = volume_db
	add_child(_player)

	if autoplay:
		play()


func play() -> void:
	if _player == null:
		return
	_player.play()
	if fade_in > 0.0:
		_fade_left = fade_in
		_player.volume_db = -60.0


func stop() -> void:
	if _player != null:
		_player.stop()


func is_playing() -> bool:
	return _player != null and _player.playing


## True once the fade-in has finished and the track sits at its real volume.
func is_settled() -> bool:
	return is_playing() and _fade_left <= 0.0


func _process(delta: float) -> void:
	if _fade_left <= 0.0 or _player == null:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	var t := 1.0 - (_fade_left / maxf(fade_in, 0.001))
	_player.volume_db = lerpf(-60.0, volume_db, t)
