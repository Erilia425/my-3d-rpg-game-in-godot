extends Node
## Scene transition service with a fade overlay.
##
## Scene loading is still synchronous in Phase 1. Threaded loading and a
## progress screen are planned for Phase 3, when regions become large.

signal scene_change_started(path: String)
signal scene_changed(path: String)

const MAIN_MENU := "res://scenes/main_menu.tscn"
const FADE_OUT_TIME := 0.22
const FADE_IN_TIME := 0.3

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "FadeLayer"
	_fade_layer.layer = 200
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)


func goto_scene(path: String, fade: bool = true) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene not found: %s" % path)
		return
	if _transitioning:
		push_warning("SceneRouter: ignoring scene change while another transition is running.")
		return

	_transitioning = true
	scene_change_started.emit(path)

	if fade:
		await _fade_to_black()

	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneRouter: failed to change scene (error %d): %s" % [error, path])
		if fade:
			await _fade_from_black()
		_transitioning = false
		return

	# change_scene_to_file() is deferred, so wait for the new scene to exist.
	await get_tree().process_frame

	if fade:
		await _fade_from_black()

	_transitioning = false
	scene_changed.emit(path)


func reload_current() -> void:
	var current := get_tree().current_scene
	if current == null:
		return

	var path := current.scene_file_path
	if path.is_empty():
		return

	goto_scene(path, true)


## True while a fade/loading transition is in flight. Gates use this so two
## triggers in the same frame cannot start two scene changes.
func is_transitioning() -> bool:
	return _transitioning


func goto_main_menu() -> void:
	goto_scene(MAIN_MENU, true)


func _fade_to_black() -> void:
	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.color = Color(0, 0, 0, 0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_TIME)
	await tween.finished


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_TIME)
	await tween.finished

	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
