extends Node
## Temporary end-to-end check for the interior door loop. Deleted with tools/.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/interior_check.tscn
##
## It loads the real town, walks a phantom player into the bakery door, confirms
## the bakery loaded, walks them into its exit, and confirms the town came back
## with the player on the doorstep and without bouncing straight in again.
## Save slots 0 and 1 are backed up and restored, because scene travel autosaves.

const TOWN := "res://scenes/town.tscn"
const BAKERY := "res://features/world/interiors/bakery_interior.tscn"
const GATE_PATH := "Gates/AuntieBellsBakeryDoor"

var _is_runner := false
var _failed := false


func _ready() -> void:
	if _is_runner:
		_run()
		return

	var runner := Node.new()
	runner.name = "InteriorCheckRunner"
	runner.set_script(get_script())
	runner.set("_is_runner", true)
	get_tree().root.add_child.call_deferred(runner)
	get_tree().change_scene_to_file.call_deferred(TOWN)


func _run() -> void:
	var backup := _backup_slots()

	print("interior check: loading town")
	_check(await _wait_scene(TOWN, 300), "town loaded")

	var gate := get_tree().current_scene.get_node_or_null(GATE_PATH) as Area3D
	_check(gate != null, "bakery door gate exists")
	if gate == null:
		_finish(backup)
		return
	_check(bool(gate.get("interior")), "bakery gate is an interior gate")
	_check(ResourceLoader.exists(String(gate.get("target_scene"))), "bakery interior file exists")

	var player := _player()
	_check(player != null, "player exists")
	if player == null:
		_finish(backup)
		return

	# Approach the door from outside the building, the way a player would. The
	# gate's return point is the opposite direction, so the test must not stand
	# at the gate's exact centre (that made the "away" direction undefined).
	var building := get_tree().current_scene.get_node_or_null("Buildings/AuntieBellsBakery") as Node3D
	_check(building != null, "bakery building exists")
	if building == null:
		_finish(backup)
		return
	var facing := building.rotation.y
	var outward := Vector3(-sin(facing), 0.0, -cos(facing))

	player.global_position = gate.global_position + outward * 1.6 + Vector3(0, -1.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(gate.is_armed(), "the door arms while the player stands outside")

	# Step just inside the trigger volume (0.9 m deep, so 0.2 m is inside).
	player.global_position = gate.global_position + outward * 0.2 + Vector3(0, -1.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(await _wait_scene(BAKERY, 400), "walking into the bakery door loaded the interior")
	var recorded := Game.get_door_return()
	_check(String(recorded.get("scene", "")) == TOWN, "the doorstep scene was recorded")
	_check((recorded.get("position", []) as Array).size() == 3, "the doorstep position was recorded")
	_check(recorded.has("yaw"), "the doorstep facing was recorded")

	var exit := get_tree().current_scene.get_node_or_null("ExitDoor") as Area3D
	_check(exit != null, "the interior has an exit door")
	if exit == null:
		_finish(backup)
		return

	# A save made indoors must still know the doorstep, otherwise loading it
	# would leave the player with no way back out.
	_check(Game.save_game(9), "a save made indoors writes")
	var indoor := SaveManager.read_slot(9)
	var indoor_world: Dictionary = indoor.get("world", {})
	_check(indoor_world.has("door_return"), "the indoor save remembers the doorstep")
	SaveManager.delete_slot(9)

	# The spawn must not already be inside the exit trigger.
	player = _player()
	var spawn_distance := player.global_position.distance_to(exit.global_position)
	_check(spawn_distance > 1.0, "the player spawns clear of the exit (%.2f m)" % spawn_distance)

	player.global_position = exit.global_position + Vector3(0, -1.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check(await _wait_scene(TOWN, 400), "walking into the exit returned to town")
	# The destination scene exists one frame before Game has placed the player;
	# wait out the fade so the return point is measurable.
	_check(await _wait_transition(), "the return transition finished")
	_check(Game.get_door_return().is_empty(), "the doorstep was cleared after leaving")

	var back_gate := get_tree().current_scene.get_node_or_null(GATE_PATH) as Node3D
	player = _player()
	if back_gate != null and player != null:
		var away := player.global_position.distance_to(back_gate.global_position)
		_check(away > 1.0 and away < 3.0, "the player returned to the doorstep (%.2f m)" % away)
		var forward := -player.global_transform.basis.z
		forward.y = 0.0
		_check(forward.normalized().dot(outward) > 0.5, "the player faces away from the door on return")

	# A return that lands inside the gate would bounce back into the bakery.
	for i in 90:
		await get_tree().process_frame
	var path := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	_check(path == TOWN, "the player did not bounce back inside (%s)" % path)

	_finish(backup)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _wait_scene(suffix: String, frames: int) -> bool:
	for i in frames:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return true
	return false


func _wait_transition(frames: int = 400) -> bool:
	for i in frames:
		await get_tree().process_frame
		if not SceneRouter.is_transitioning():
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failed = true
		print("  FAIL: " + message)


func _finish(backup: Dictionary) -> void:
	_restore_slots(backup)
	print("INTERIOR_CHECK_OK" if not _failed else "INTERIOR_CHECK_FAIL")
	get_tree().quit(1 if _failed else 0)


func _backup_slots() -> Dictionary:
	var made := {}
	for slot in [0, 1]:
		var path := "user://saves/slot_%d/save.json" % slot
		if FileAccess.file_exists(path):
			made[path] = FileAccess.get_file_as_bytes(path)
	return made


func _restore_slots(backup: Dictionary) -> void:
	for slot in [0, 1]:
		var path := "user://saves/slot_%d/save.json" % slot
		if backup.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(backup[path])
				file.close()
		elif FileAccess.file_exists(path):
			SaveManager.delete_slot(slot)
