extends Control
## Field Notes: the places Rowan has walked, and what the boots have done.
##
## A child of the HUD, opened with **C**. It reads `ExplorationLog` and
## `MovementStats` and changes neither. Built in code so the panel needs no
## fragile scene layout; the parchment style matches the quest journal.
##
## Blocks the player and releases the mouse while open, exactly like the
## inventory, journal, and map.

const C_PAPER := Color(0.84, 0.76, 0.58, 1)
const C_INK := Color(0.24, 0.16, 0.09, 1)
const C_SOFT := Color(0.42, 0.34, 0.22, 1)
const C_FAINT := Color(0.55, 0.47, 0.34, 1)

var _places: VBoxContainer
var _count: Label
var _stride: VBoxContainer
var _player: PlayerController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Events.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING and not visible:
		return
	if _dialogue_is_open() and not visible:
		return

	if event.is_action_pressed("field_notes"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _dialogue_is_open():
		return
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_put_other_panels_away()
	visible = true
	if is_instance_valid(_player):
		_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	if is_instance_valid(_player):
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


# --- layout ----------------------------------------------------------------


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.035, 0.025, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 470)
	panel.add_theme_stylebox_override("panel", _paper_style())
	centre.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := Label.new()
	title.text = "Field Notes"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", C_INK)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 15)
	_count.add_theme_color_override("font_color", C_SOFT)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(_count)

	var subtitle := Label.new()
	subtitle.text = (
		"What Rowan has walked, and what the boots have done on the way."
	)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", C_SOFT)
	layout.add_child(subtitle)

	var rule := HSeparator.new()
	layout.add_child(rule)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)

	# Left: places.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	left.add_child(_heading("Places"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_places = VBoxContainer.new()
	_places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_places.add_theme_constant_override("separation", 3)
	scroll.add_child(_places)

	# Right: stride.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	right.add_child(_heading("Stride"))

	_stride = VBoxContainer.new()
	_stride.add_theme_constant_override("separation", 7)
	right.add_child(_stride)

	var hint := Label.new()
	hint.text = "The record grows quietly. Nothing here is a target."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", C_FAINT)
	right.add_child(hint)

	var footer := Label.new()
	footer.text = "C  closes these notes"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", C_FAINT)
	layout.add_child(footer)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", C_INK)
	return label


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PAPER
	style.border_color = Color(0.3, 0.22, 0.13, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.02, 0.015, 0.01, 0.7)
	style.shadow_size = 16
	return style


# --- content ---------------------------------------------------------------


func _refresh() -> void:
	_clear(_places)
	_clear(_stride)

	var region := ""
	for area in ExplorationLog.AREAS:
		var area_region := String(area["region"])
		if area_region != region:
			region = area_region
			var header := Label.new()
			header.text = region
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", C_FAINT)
			_places.add_child(header)

		var id: StringName = area["id"]
		var found := ExplorationLog.has(id)
		var row := Label.new()
		row.text = ("%s  %s" % ["✓" if found else "·", area["title"]])
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override(
			"font_color", C_INK if found else C_FAINT
		)
		_places.add_child(row)

		if found:
			var note := Label.new()
			note.text = "     " + String(area["note"])
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.add_theme_font_size_override("font_size", 12)
			note.add_theme_color_override("font_color", C_SOFT)
			_places.add_child(note)

	_count.text = "%d of %d places" % [
		ExplorationLog.get_seen_count(), ExplorationLog.get_total()
	]

	# Rooms are counted by scene, so they are listed as entered rather than out
	# of a fixed total: the Hollow has more doors than anyone has counted.
	var rooms := ExplorationLog.get_rooms()
	var room_rule := HSeparator.new()
	_places.add_child(room_rule)
	var room_header := Label.new()
	room_header.text = "Rooms entered  (%d)" % rooms.size()
	room_header.add_theme_font_size_override("font_size", 13)
	room_header.add_theme_color_override("font_color", C_FAINT)
	_places.add_child(room_header)
	if rooms.is_empty():
		var none := Label.new()
		none.text = "·  none yet"
		none.add_theme_font_size_override("font_size", 15)
		none.add_theme_color_override("font_color", C_FAINT)
		_places.add_child(none)
	for title in rooms:
		var room_row := Label.new()
		room_row.text = "✓  " + String(title)
		room_row.add_theme_font_size_override("font_size", 14)
		room_row.add_theme_color_override("font_color", C_SOFT)
		_places.add_child(room_row)

	_stride_row("Jumps taken", "%d" % MovementStats.get_jumps())
	_stride_row("Highest jump", "%.1f m" % MovementStats.get_best_jump())
	_stride_row("Longest drop", "%.1f m" % MovementStats.get_best_drop())
	_stride_row("Longest airtime", "%.1f s" % MovementStats.get_best_airtime())
	_stride_row("Highest point", "%.1f m" % MovementStats.get_highest())
	# Magic is learned in conversations, so it belongs in the record beside the
	# stride. The total is every named teacher's curriculum.
	_stride_row(
		"Lessons learned",
		"%d of %d" % [MagicLessons.get_taught_total(), MagicLessons.get_total()]
	)


func _stride_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", C_SOFT)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", C_INK)
	row.add_child(value)

	_stride.add_child(row)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


# --- helpers ---------------------------------------------------------------


func _dialogue_is_open() -> bool:
	var window := get_parent().get_node_or_null("DialogueWindow") as Control
	return window != null and window.visible


func _put_other_panels_away() -> void:
	var hud := get_parent()
	if hud == null:
		return
	if hud.has_method("close_inventory"):
		hud.call("close_inventory")
	for panel_name in ["MapScreen", "QuestJournal", "LedgerShopPanel"]:
		var panel := hud.get_node_or_null(panel_name)
		if panel != null and panel.has_method("close") and panel.visible:
			panel.call("close")


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
