extends Node
## Phase 0 smoke test.
##
## Run from a terminal:
##   godot --headless --path . tests/phase0_smoke.tscn
## Or open this scene in the editor and press F6.
##
## This is a plain scene, not a test framework. It checks the foundations that
## must work before Phase 1 begins.

var _failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame

	_check_autoloads()
	_check_project_settings()
	_check_input_actions()
	_check_audio_buses()
	_check_settings_round_trip()
	_check_pause_flow()

	if _failures.is_empty():
		print("PHASE0_SMOKE_OK")
		get_tree().quit(0)
	else:
		push_error("PHASE0_SMOKE_FAILED: " + ", ".join(_failures))
		get_tree().quit(1)


func _check_autoloads() -> void:
	_check(Events != null, "Events autoload exists")
	_check(Game != null, "Game autoload exists")
	_check(SceneRouter != null, "SceneRouter autoload exists")
	_check(SaveManager != null, "SaveManager autoload exists")
	_check(Settings != null, "Settings autoload exists")
	_check(Debug != null, "Debug autoload exists")


func _check_project_settings() -> void:
	_check(
		String(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/boot.tscn",
		"main scene is boot.tscn"
	)
	_check(
		String(ProjectSettings.get_setting("layer_names/3d_physics/layer_1", "")) == "world",
		"collision layer 1 is named world"
	)
	_check(
		String(ProjectSettings.get_setting("layer_names/3d_physics/layer_9", "")) == "camera_blocker",
		"collision layer 9 is named camera_blocker"
	)


func _check_input_actions() -> void:
	for action: String in [
		"move_forward", "move_back", "move_left", "move_right",
		"jump", "sprint", "crouch", "interact", "attack", "block",
		"toggle_camera", "inventory", "journal", "map", "pause",
		"quick_save", "quick_load", "debug_toggle",
	]:
		_check(InputMap.has_action(action), "input action exists: %s" % action)

	_check_key("move_forward", KEY_W, "move_forward is bound to W")
	_check_key("toggle_camera", KEY_V, "toggle_camera is bound to V")
	_check_key("pause", KEY_ESCAPE, "pause is bound to Escape")
	_check_key("debug_toggle", KEY_F3, "debug_toggle is bound to F3")


func _check_key(action: StringName, expected_key: int, message: String) -> void:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		_check(false, message)
		return

	var key_event := events[0] as InputEventKey
	_check(key_event != null and key_event.physical_keycode == expected_key, message)


func _check_audio_buses() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "UI", "Ambience", "Voice"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "audio bus exists: %s" % bus_name)


func _check_settings_round_trip() -> void:
	var original := float(Settings.get_setting("audio/master_volume", 0.8))
	Settings.set_setting("audio/master_volume", 0.42)
	_check(Settings.save_settings(), "settings save succeeds")
	Settings.load_settings()
	_check(
		is_equal_approx(float(Settings.get_setting("audio/master_volume", 0.0)), 0.42),
		"settings value survives save/load"
	)

	Settings.set_setting("audio/master_volume", original)
	Settings.save_settings()


func _check_pause_flow() -> void:
	Game.set_state(Game.State.PLAYING)
	Game.pause_game()
	_check(Game.state == Game.State.PAUSED, "pause enters PAUSED")
	_check(get_tree().paused, "pause freezes the scene tree")

	Game.resume_game()
	_check(Game.state == Game.State.PLAYING, "resume returns to PLAYING")
	_check(not get_tree().paused, "resume unfreezes the scene tree")

	Game.set_state(Game.State.MAIN_MENU)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures.append(message)
		push_error("  FAIL: " + message)
