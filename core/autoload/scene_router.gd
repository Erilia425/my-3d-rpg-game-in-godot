extends Node
## Scene transition service.
##
## Phase 0 uses Godot's built-in scene change. The fade/loading overlay and
## threaded loading arrive in Phase 1. See AGENTS.md section 4.4.

signal scene_change_started(path: String)
signal scene_changed(path: String)

const MAIN_MENU := "res://scenes/main_menu.tscn"


func goto_scene(path: String, fade: bool = true) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return

	scene_change_started.emit(path)

	# Reserved for the Phase 1 fade/loading overlay.
	if fade:
		pass

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneRouter: failed to change scene (error %d): %s" % [error, path])
		return

	# change_scene_to_file() is deferred, so announce after the new scene exists.
	await get_tree().process_frame
	scene_changed.emit(path)


func reload_current() -> void:
	var current := get_tree().current_scene
	if current == null:
		return

	var path := current.scene_file_path
	if path.is_empty():
		return

	goto_scene(path, false)


func goto_main_menu() -> void:
	goto_scene(MAIN_MENU, false)
