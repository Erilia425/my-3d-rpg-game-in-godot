extends Node
## Persistent user settings stored in user://settings.cfg.
##
## Keys use the form "section/name", for example "audio/master_volume".
## See AGENTS.md section 4.4 for the service contract.

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULTS := {
	"audio/master_volume": 0.8,
	"audio/music_volume": 0.8,
	"audio/sfx_volume": 1.0,
	"display/fullscreen": false,
}

var _config := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	var error := _config.load(SETTINGS_PATH)
	if error != OK:
		_config = ConfigFile.new()
		for key: String in DEFAULTS:
			_set_value(key, DEFAULTS[key])
		save_settings()
	else:
		for key: String in DEFAULTS:
			if not _has_value(key):
				_set_value(key, DEFAULTS[key])
	apply_all()


func save_settings() -> bool:
	var error := _config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Settings: could not save %s (error %d)." % [SETTINGS_PATH, error])
		return false
	return true


func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	return _config.get_value(_section_of(String(key)), _name_of(String(key)), default_value)


func set_setting(key: StringName, value: Variant) -> void:
	_set_value(String(key), value)
	Events.setting_changed.emit(key, value)


func apply_all() -> void:
	_apply_bus_volume("Master", float(get_setting("audio/master_volume", 0.8)))
	_apply_bus_volume("Music", float(get_setting("audio/music_volume", 0.8)))
	_apply_bus_volume("SFX", float(get_setting("audio/sfx_volume", 1.0)))

	if DisplayServer.get_name() == "headless":
		return

	var want_fullscreen := bool(get_setting("display/fullscreen", false))
	var current_mode := DisplayServer.window_get_mode()
	var is_fullscreen := (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if want_fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)


func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	var clamped := clampf(volume, 0.0, 1.0)
	if clamped <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))


func _set_value(key: String, value: Variant) -> void:
	_config.set_value(_section_of(key), _name_of(key), value)


func _has_value(key: String) -> bool:
	return _config.has_section_key(_section_of(key), _name_of(key))


func _section_of(key: String) -> String:
	var separator := key.find("/")
	return "settings" if separator < 0 else key.substr(0, separator)


func _name_of(key: String) -> String:
	var separator := key.find("/")
	return key if separator < 0 else key.substr(separator + 1)
