extends Control
## The boss bar: a name and a long amber line, shown only while a boss is live.
##
## Built in code and added by the HUD, so `hud.tscn` keeps its shipped layout and
## every `%UniqueName` stays untouched. It listens to the `Events.boss_*`
## signals and owns no fight state of its own: the boss says what is true, this
## draws it.

var _title: Label
var _bar: ProgressBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 96.0
	offset_bottom = 164.0

	_build()
	visible = false

	Events.boss_engaged.connect(_on_engaged)
	Events.boss_health_changed.connect(_on_health_changed)
	Events.boss_phase_changed.connect(_on_phase_changed)
	Events.boss_disengaged.connect(_on_disengaged)


func _build() -> void:
	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.045, 0.055, 0.76)
	style.border_color = Color(0.74, 0.58, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	_title = Label.new()
	_title.name = "BossName"
	_title.text = "The Spider Mother"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.97, 0.91, 0.79, 1))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(_title)

	_bar = ProgressBar.new()
	_bar.name = "BossBar"
	_bar.custom_minimum_size = Vector2(0.0, 15.0)
	_bar.show_percentage = false
	_bar.max_value = 100.0
	_bar.value = 100.0

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.08, 0.1, 0.95)
	background.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.56, 0.16, 1.0)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)

	column.add_child(_bar)


func _on_engaged(title: String, max_health: float) -> void:
	_title.text = title
	_bar.max_value = maxf(max_health, 1.0)
	_bar.value = maxf(max_health, 0.0)
	visible = true


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maxf(maximum, 1.0)
	_bar.value = clampf(current, 0.0, _bar.max_value)


## The three phases speak their own name, so the bar also tells the story.
func _on_phase_changed(title: String) -> void:
	if visible:
		_title.text = title


func _on_disengaged() -> void:
	visible = false


## Used by tests: what the bar is holding right now.
func get_shown_title() -> String:
	return _title.text if _title != null else ""


func get_shown_fraction() -> float:
	if _bar == null or _bar.max_value <= 0.0:
		return 0.0
	return clampf(_bar.value / _bar.max_value, 0.0, 1.0)
