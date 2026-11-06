extends Node
## Throwaway: proves every enterable door in the town leads to a working room.
## Deleted with tools/.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/interior_audit.tscn
##
## Instantiates the town, collects its interior gates, then instantiates every
## target room once and checks its shell, exit door, HUD, and spawn clearance.
## Rooms are freed between checks so only one player exists at a time.

const TOWN := "res://scenes/town.tscn"

var _failed := false
var _rooms := 0


func _ready() -> void:
	_run()


func _run() -> void:
	var packed := load(TOWN) as PackedScene
	_check(packed != null, "the town scene loads")
	if packed == null:
		_finish()
		return

	var town := packed.instantiate() as Node3D
	add_child(town)
	for i in 3:
		await get_tree().physics_frame

	var gates := town.get_node_or_null("Gates")
	_check(gates != null, "the town has a Gates node")
	if gates == null:
		_finish()
		return

	var doors: Array[Area3D] = []
	for child in gates.get_children():
		var gate := child as Area3D
		if gate != null and bool(gate.get("interior")):
			doors.append(gate)
	_check(doors.size() == 39, "the town opens 39 interior doors (%d)" % doors.size())

	var targets := {}
	for gate in doors:
		var target := String(gate.get("target_scene"))
		_check(not target.is_empty(), "%s has a target scene" % gate.name)
		_check(ResourceLoader.exists(target), "%s leads to an existing scene" % gate.name)
		targets[target] = true
	_check(targets.size() == 39, "every door has its own interior (%d)" % targets.size())

	town.queue_free()
	for i in 2:
		await get_tree().process_frame

	for target in targets:
		await _check_room(String(target))

	print("interior audit: %d rooms checked" % _rooms)
	_finish()


func _check_room(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_check(false, "%s loads" % path)
		return

	var room := packed.instantiate() as Node3D
	add_child(room)
	await get_tree().physics_frame
	await get_tree().process_frame

	var label := path.get_file()
	_check(room.get_node_or_null("InteriorEnvironment") is WorldEnvironment, "%s has its own environment" % label)
	_check(room.get_node_or_null("ExitDoor") is Area3D, "%s has an exit door" % label)
	_check(room.get_node_or_null("Player") is Node3D, "%s has a player" % label)
	_check(room.get_node_or_null("HUD") != null, "%s has the HUD" % label)

	var player := room.get_node_or_null("Player") as Node3D
	var exit := room.get_node_or_null("ExitDoor") as Node3D
	if player != null and exit != null:
		var distance := player.global_position.distance_to(exit.global_position)
		_check(distance > 1.0, "%s spawns clear of its door (%.2f m)" % [label, distance])

	var batches := 0
	for child in room.get_children():
		if String(child.name).begins_with("Batch"):
			batches += 1
	_check(batches > 0, "%s builds furniture (%d batches)" % [label, batches])

	_rooms += 1
	room.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failed = true
		print("  FAIL: " + message)


func _finish() -> void:
	print("INTERIOR_AUDIT_OK" if not _failed else "INTERIOR_AUDIT_FAIL")
	get_tree().quit(1 if _failed else 0)
