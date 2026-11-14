extends CanvasLayer
## Pause overlay. Visible only while Game.state is PAUSED.
##
## Saving and loading live here because pausing is the safe moment to touch the
## disk: no physics tick is mid-flight and the player has already stopped.

@onready var _root: Control = %PauseRoot
@onready var _status: Label = %StatusLabel
@onready var _slot_option: OptionButton = %SlotOption

var _selected_slot: int = Game.MANUAL_SLOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false

	Events.game_state_changed.connect(_on_game_state_changed)
	%ResumeButton.pressed.connect(_on_resume_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	%AutosaveButton.pressed.connect(_on_autosave_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_slot_option.item_selected.connect(_on_slot_selected)

	_fill_slots()
	_refresh_load_state()
	_build_sound_rows()


## Sound lives in the pause menu rather than a separate screen: it is the one
## place a player already pauses, and turning ambience down is the most likely
## reason to open a settings page in a game this quiet.
##
## The rows are built in code and inserted above Resume, so the shipped scene
## layout (and every `%UniqueName` in it) is untouched.
func _build_sound_rows() -> void:
	var vbox := %ResumeButton.get_parent() as VBoxContainer
	if vbox == null:
		return

	var index := %ResumeButton.get_index()
	var heading := Label.new()
	heading.name = "SoundHeading"
	heading.text = "Sound"
	heading.add_theme_font_size_override("font_size", 15)
	vbox.add_child(heading)
	vbox.move_child(heading, index)
	index += 1

	for row in [
		{"key": &"audio/music_volume", "label": "Music"},
		{"key": &"audio/ambience_volume", "label": "Ambience"},
		{"key": &"audio/sfx_volume", "label": "Effects"},
	]:
		var holder := HBoxContainer.new()
		holder.name = "%sRow" % String(row["label"])
		holder.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = String(row["label"])
		label.custom_minimum_size = Vector2(110, 0)
		label.add_theme_font_size_override("font_size", 14)
		holder.add_child(label)

		var slider := HSlider.new()
		slider.name = "%sSlider" % String(row["label"])
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = float(Settings.get_setting(row["key"], 0.8)) * 100.0
		slider.custom_minimum_size = Vector2(210, 24)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(slider)

		var value := Label.new()
		value.text = "%d%%" % int(round(slider.value))
		value.custom_minimum_size = Vector2(52, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 14)
		holder.add_child(value)

		var key: StringName = row["key"]
		slider.value_changed.connect(
			func(raw: float) -> void:
				value.text = "%d%%" % int(round(raw))
				Settings.set_setting(key, raw / 100.0)
				Settings.save_settings()
				Settings.apply_all()
		)

		vbox.add_child(holder)
		vbox.move_child(holder, index)
		index += 1

	# Put a rule between the sound rows and the buttons, and a heading above them.
	var rule := HSeparator.new()
	rule.name = "SoundRule"
	vbox.add_child(rule)
	vbox.move_child(rule, %ResumeButton.get_index())


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	_root.visible = current_state == Game.State.PAUSED
	if not _root.visible:
		return

	_status.text = ""
	_fill_slots()
	_refresh_load_state()
	%ResumeButton.grab_focus()


## One row per manual slot, with the real save timestamp so two slots are easy
## to tell apart. Slot 1 stays out of the list because it belongs to autosave.
func _fill_slots() -> void:
	_slot_option.clear()
	var index := 0
	for slot in Game.MANUAL_SLOTS:
		_slot_option.add_item(_slot_label(slot), slot)
		if slot == _selected_slot:
			_slot_option.select(index)
		index += 1


func _slot_label(slot: int) -> String:
	var label := "Slot %d" % slot
	if slot == Game.MANUAL_SLOT:
		label += " — quick"
	var stamp := SaveManager.get_saved_at(slot)
	if stamp.is_empty():
		return "%s (empty)" % label
	return "%s — %s" % [label, stamp.substr(0, 16).replace("T", " ")]


func _on_slot_selected(index: int) -> void:
	_selected_slot = _slot_option.get_item_id(index)
	_refresh_load_state()


## A slot that was never saved has nothing to load.
func _refresh_load_state() -> void:
	%LoadButton.disabled = not SaveManager.has_slot(_selected_slot)
	%AutosaveButton.disabled = not SaveManager.has_slot(Game.AUTOSAVE_SLOT)


func _on_resume_pressed() -> void:
	Game.resume_game()


func _on_save_pressed() -> void:
	if Game.save_game(_selected_slot):
		_status.text = "Saved to slot %d." % _selected_slot
	else:
		_status.text = "Save failed: %s" % SaveManager.get_last_error()
	_fill_slots()
	_refresh_load_state()


func _on_load_pressed() -> void:
	_load_slot(_selected_slot)


func _on_autosave_pressed() -> void:
	_load_slot(Game.AUTOSAVE_SLOT)


func _load_slot(slot: int) -> void:
	if not SaveManager.has_slot(slot):
		_status.text = "No save in slot %d." % slot
		return

	_status.text = "Loading..."
	# Fire and forget on purpose: the coroutine belongs to the `Game` autoload,
	# so it finishes safely even though this menu is replaced by the loaded
	# scene halfway through.
	Game.load_game(slot)


func _on_main_menu_pressed() -> void:
	Game.quit_to_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
