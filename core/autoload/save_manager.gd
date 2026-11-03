extends Node
## Save/load service.
##
## Version 1 format: one readable JSON file per slot at
## `user://saves/slot_<n>/save.json`, written atomically through a temp file.
##
## Structure:
## {
##   "version": 1,
##   "saved_at": "2026-11-01T12:00:00",
##   "scene": "res://scenes/test_room.tscn",
##   "world": { "time": { "day": 1, "hour": 8.0, ... } },
##   "saveables": { "chest.test_room.sword": { "open": true }, ... }
## }
##
## Persistent nodes join the `saveable` group and implement
## `get_save_id() -> StringName`, `save_data() -> Dictionary`, and
## `load_data(data: Dictionary) -> void`. See AGENTS.md section 8.

const SAVE_ROOT := "user://saves"
const SAVE_VERSION := 1

## How many saveable nodes the last load touched. Useful for tests and logs.
var last_applied_count: int = 0

var _last_error := ""


# --- public API ------------------------------------------------------------


func has_slot(slot: int) -> bool:
	return slot >= 0 and FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(_temp_path(slot)):
		DirAccess.remove_absolute(_temp_path(slot))

	var folder := _slot_folder(slot)
	if DirAccess.dir_exists_absolute(folder):
		DirAccess.remove_absolute(folder)
	return not FileAccess.file_exists(path)


## Collects the current scene and writes it. Returns false on any file error.
func save_slot(slot: int) -> bool:
	if slot < 0:
		_fail("save slot %d is invalid" % slot)
		return false

	var data := build_save_dict()
	return write_save_dict(slot, data)


## Builds the dictionary without touching the disk. Kept public so tests and
## tools can inspect a save before writing it.
##
## `saveables` may be passed in when the caller keeps a session-wide world state
## that spans more than the current scene (see `Game`). When null, only the
## objects in the running scene are collected.
func build_save_dict(saveables: Variant = null) -> Dictionary:
	var entries: Dictionary = (
		collect_saveables() if saveables == null else (saveables as Dictionary).duplicate(true)
	)
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"scene": _current_scene_path(),
		"world": {"time": WorldClock.save_data()},
		"saveables": entries,
	}


## Timestamp of a slot, or an empty string when it cannot be read. Used to pick
## the newest save without parsing every slot twice.
func get_saved_at(slot: int) -> String:
	if not has_slot(slot):
		return ""
	var data := read_slot(slot)
	return String(data.get("saved_at", ""))


## Parses one slot. Returns an empty dictionary when the file is missing,
## unreadable, corrupt, or from a newer build.
func read_slot(slot: int) -> Dictionary:
	if slot < 0:
		return {}

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		_fail("no save in slot %d" % slot)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_fail("save in slot %d is not valid JSON (%s at line %d)" % [
			slot, json.get_error_message(), json.get_error_line()
		])
		return {}

	if not json.data is Dictionary:
		_fail("save in slot %d is not a dictionary" % slot)
		return {}

	var data: Dictionary = json.data
	var version := int(data.get("version", 0))
	if version <= 0:
		_fail("save in slot %d has no version" % slot)
		return {}
	if version > SAVE_VERSION:
		_fail("save in slot %d is version %d; this build reads up to %d" % [
			slot, version, SAVE_VERSION
		])
		return {}
	if version < SAVE_VERSION:
		data = _migrate(data, version)

	return data


## Reads a slot and applies it to the scene that is already loaded.
func load_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	return apply_save(data)


## Applies an already parsed save. Every saveable object that has a matching
## id is restored; objects missing from the save keep their current state.
func apply_save(data: Dictionary) -> bool:
	last_applied_count = 0
	if data.is_empty():
		_fail("nothing to apply")
		return false

	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		_fail("cannot apply save version %d" % version)
		return false

	var world: Dictionary = data.get("world", {})
	if world.has("time"):
		WorldClock.load_data(world["time"])

	var entries: Dictionary = data.get("saveables", {})
	for node in get_tree().get_nodes_in_group("saveable"):
		if not _is_saveable(node):
			continue

		var id := String(node.call("get_save_id"))
		if id.is_empty() or not entries.has(id):
			continue

		var payload = entries[id]
		if not payload is Dictionary:
			push_warning("SaveManager: save data for %s is not a dictionary" % id)
			continue

		node.call("load_data", payload)
		last_applied_count += 1

	_last_error = ""
	return true


func get_last_error() -> String:
	return _last_error


func write_save_dict(slot: int, data: Dictionary) -> bool:
	if slot < 0:
		_fail("save slot %d is invalid" % slot)
		return false

	var folder := _slot_folder(slot)
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_fail("could not create %s (error %d)" % [folder, error])
		return false

	var temp_path := _temp_path(slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_fail("could not write %s (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Replace the old file only once the new one is complete, so a crash
	# mid-write cannot destroy the previous save.
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		DirAccess.remove_absolute(temp_path)
		_fail("could not move the save into place (error %d)" % error)
		return false

	_last_error = ""
	return true


# --- internals -------------------------------------------------------------


func _is_saveable(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
		and node.has_method("get_save_id")
		and node.has_method("save_data")
		and node.has_method("load_data")
	)


func collect_saveables() -> Dictionary:
	var entries := {}
	for node in get_tree().get_nodes_in_group("saveable"):
		if not _is_saveable(node):
			continue

		var id := String(node.call("get_save_id"))
		if id.is_empty():
			push_warning("SaveManager: %s is saveable but has no save id" % node.name)
			continue
		if entries.has(id):
			push_warning("SaveManager: duplicate save id %s (from %s)" % [id, node.name])
			continue

		entries[id] = node.call("save_data")
	return entries


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path


## Version 1 is the first format, so there is nothing to migrate yet. Keep the
## hook: every future format change adds a branch here plus a round-trip test.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	push_warning("SaveManager: migrating a version %d save" % from_version)
	data["version"] = SAVE_VERSION
	return data


func _fail(message: String) -> void:
	_last_error = message
	push_warning("SaveManager: " + message)


func _slot_folder(slot: int) -> String:
	return "%s/slot_%d" % [SAVE_ROOT, slot]


func _slot_path(slot: int) -> String:
	return "%s/save.json" % _slot_folder(slot)


func _temp_path(slot: int) -> String:
	return "%s/save.json.tmp" % _slot_folder(slot)
