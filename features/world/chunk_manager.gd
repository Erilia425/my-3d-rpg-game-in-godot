class_name ChunkManager
extends Node3D
## Streams world chunks in and out around a tracked node.
##
## A chunk is one scene at `<chunk_directory>/chunk_<x>_<z>.tscn`. Exactly the
## chunks inside `load_radius` of the tracked node stay loaded; anything further
## away is freed. Files are loaded with `ResourceLoader.load_threaded_request()`
## so a chunk swap never blocks a frame. See AGENTS.md sections 7 and 10.
##
## The manager is inert until there is world content behind it: a missing chunk
## file is remembered and skipped instead of being retried every tick.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

@export var chunk_directory: String = "res://features/world/chunks"
@export var chunk_size: float = 64.0
@export_range(0, 4) var load_radius: int = 1
## Seconds between streaming decisions. Chunks do not need per-frame attention.
@export var update_interval: float = 0.25
@export var auto_track_player: bool = true
@export var enabled: bool = true

## Vector2i -> instantiated chunk scene
var _loaded: Dictionary = {}
## Vector2i -> resource path, while a threaded load is in flight
var _pending: Dictionary = {}
## Vector2i -> true, for coordinates with no chunk file
var _missing: Dictionary = {}

var _track_node: Node3D
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "ChunkTimer"
	_timer.wait_time = maxf(update_interval, 0.05)
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)


func set_track_node(node: Node3D) -> void:
	_track_node = node


func get_track_node() -> Node3D:
	return _resolve_target()


func world_to_chunk(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size)
	)


func chunk_path(coord: Vector2i) -> String:
	return "%s/chunk_%d_%d.tscn" % [chunk_directory, coord.x, coord.y]


func is_chunk_loaded(coord: Vector2i) -> bool:
	return _loaded.has(coord)


func get_loaded_chunks() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord in _loaded.keys():
		coords.append(coord)
	return coords


func get_loaded_chunk_count() -> int:
	return _loaded.size()


## Runs one streaming pass immediately instead of waiting for the timer. Tests
## and teleports use this; normal play relies on the timer.
func refresh_now() -> void:
	_refresh()


func unload_all() -> void:
	for coord in _loaded.keys():
		_unload(coord)
	_pending.clear()


func _refresh() -> void:
	if not enabled:
		return
	if Game.state != Game.State.PLAYING:
		return

	var target := _resolve_target()
	if target == null:
		return

	_poll_pending()

	var center := world_to_chunk(target.global_position)
	var wanted: Dictionary = {}

	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var coord := Vector2i(center.x + dx, center.y + dz)
			wanted[coord] = true
			if _loaded.has(coord) or _pending.has(coord) or _missing.has(coord):
				continue
			_request(coord)

	for coord in _loaded.keys():
		if not wanted.has(coord):
			_unload(coord)


func _resolve_target() -> Node3D:
	if is_instance_valid(_track_node):
		return _track_node
	if auto_track_player:
		return get_tree().get_first_node_in_group("player") as Node3D
	return null


func _request(coord: Vector2i) -> void:
	var path := chunk_path(coord)
	if not ResourceLoader.exists(path):
		_missing[coord] = true
		return

	var error := ResourceLoader.load_threaded_request(path)
	if error != OK:
		push_warning("ChunkManager: could not start loading %s (error %d)" % [path, error])
		_missing[coord] = true
		return

	_pending[coord] = path


func _poll_pending() -> void:
	# keys() returns a copy, so erasing inside the loop is safe.
	for coord in _pending.keys():
		var path: String = _pending[coord]
		var status := ResourceLoader.load_threaded_get_status(path)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				_pending.erase(coord)
				_attach(coord, ResourceLoader.load_threaded_get(path))
			_:
				_pending.erase(coord)
				_missing[coord] = true
				push_warning("ChunkManager: failed to load %s" % path)


func _attach(coord: Vector2i, resource: Resource) -> void:
	var packed := resource as PackedScene
	if packed == null:
		_missing[coord] = true
		push_warning("ChunkManager: %s is not a packed scene" % chunk_path(coord))
		return

	var instance := packed.instantiate() as Node3D
	if instance == null:
		_missing[coord] = true
		push_warning("ChunkManager: %s has a non-3D root" % chunk_path(coord))
		return

	# Chunk files are authored around the origin; the manager places them.
	instance.position = Vector3(coord.x * chunk_size, 0.0, coord.y * chunk_size)
	add_child(instance)
	_loaded[coord] = instance
	chunk_loaded.emit(coord)


func _unload(coord: Vector2i) -> void:
	var instance: Node3D = _loaded.get(coord)
	_loaded.erase(coord)

	if is_instance_valid(instance):
		instance.queue_free()

	chunk_unloaded.emit(coord)
