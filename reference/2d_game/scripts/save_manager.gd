extends Node
## Simple JSON save/load for the 2D game.
##
## Saves the current scene, Fern's position and health, and the global
## inventory/favors/discoveries. F5 saves, F9 loads. The save lives at
## `user://savegame.json`.

const SAVE_PATH := "user://savegame.json"
const VERSION := 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game()
		get_viewport().set_input_as_handled()


func save_game(path: String = SAVE_PATH) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("SaveManager: no node in the 'player' group.")
		return false

	var data := {
		"version": VERSION,
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
		"player": {
			"position": [player.global_position.x, player.global_position.y],
			"health": int(player.health),
		},
		"inventory": GlobalInventory.inventory.duplicate(true),
		"favors": GlobalInventory.favors.duplicate(true),
		"discoveries": GlobalInventory.discoveries.duplicate(true),
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write %s" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("SaveManager: saved to ", path)
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		print("SaveManager: no save at ", path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not read %s" % path)
		return false

	var text := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: save is not valid JSON.")
		return false
	if int(data.get("version", 0)) != VERSION:
		push_error("SaveManager: unsupported save version.")
		return false

	var scene_path := String(data.get("scene", ""))
	if scene_path != "" and get_tree().current_scene != null \
			and scene_path != get_tree().current_scene.scene_file_path:
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var player_data: Dictionary = data.get("player", {})
		var position: Array = player_data.get("position", [])
		if position.size() == 2:
			player.global_position = Vector2(float(position[0]), float(position[1]))
		player.health = int(player_data.get("health", player.health))
		if player.has_method("update_health_bar"):
			player.update_health_bar()

	GlobalInventory.inventory = (data.get("inventory", GlobalInventory.inventory) as Dictionary).duplicate(true)
	GlobalInventory.favors = (data.get("favors", GlobalInventory.favors) as Dictionary).duplicate(true)
	GlobalInventory.discoveries = (data.get("discoveries", GlobalInventory.discoveries) as Dictionary).duplicate(true)

	print("SaveManager: loaded from ", path)
	return true
