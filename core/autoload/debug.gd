extends CanvasLayer
## Minimal F3 debug overlay.
##
## Shows FPS, game state, camera mode, and player position. Refreshes four
## times per second instead of every frame. Disabled in release builds.

const REFRESH_INTERVAL := 0.25

var _panel: PanelContainer
var _label: Label
var _overlay_visible := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_overlay()

	var refresh_timer := Timer.new()
	refresh_timer.wait_time = REFRESH_INTERVAL
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_refresh)
	add_child(refresh_timer)

	Events.game_state_changed.connect(_on_game_state_changed)
	Events.camera_mode_changed.connect(_on_camera_mode_changed)

	if not OS.is_debug_build():
		_overlay_visible = false
		_panel.visible = false
	else:
		_refresh()


func _build_overlay() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.78)
	style.border_color = Color(0.72, 0.62, 0.4, 0.85)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.85))
	_label.text = "Debug"

	margin.add_child(_label)
	_panel.add_child(margin)
	add_child(_panel)


func _refresh() -> void:
	if not _overlay_visible:
		return

	var player := get_tree().get_first_node_in_group("player")
	var player_name := "none"
	var position_text := "n/a"
	var camera_text := "n/a"

	if player is Node3D:
		var player_3d := player as Node3D
		player_name = String(player_3d.name)
		position_text = "(%.1f, %.1f, %.1f)" % [
			player_3d.global_position.x,
			player_3d.global_position.y,
			player_3d.global_position.z,
		]
		if player.has_method("get_camera_mode_name"):
			camera_text = String(player.get_camera_mode_name())

	_label.text = "\n".join([
		"FPS: %d" % Engine.get_frames_per_second(),
		"State: %s" % Game.get_state_name(),
		"Player: %s" % player_name,
		"Camera: %s" % camera_text,
		"Position: %s" % position_text,
		"F3 toggles this overlay",
	])


func _on_game_state_changed(_previous_state: int, _current_state: int) -> void:
	_refresh()


func _on_camera_mode_changed(_is_first_person: bool) -> void:
	_refresh()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_toggle"):
		return
	if not OS.is_debug_build():
		return

	_overlay_visible = not _overlay_visible
	_panel.visible = _overlay_visible
	if _overlay_visible:
		_refresh()
	get_viewport().set_input_as_handled()
