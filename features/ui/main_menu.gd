extends Control
## Main menu: New Game, Continue, Settings, Quit.
##
## Continue is enabled as soon as slot 0 holds a save. Settings are applied and
## saved immediately.

@onready var continue_button: Button = %ContinueButton
@onready var settings_panel: Control = %SettingsPanel
@onready var main_buttons: Control = %MainButtons
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var fullscreen_check: CheckBox = %FullscreenCheck


func _ready() -> void:
	Game.set_state(Game.State.MAIN_MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	%NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%SettingsBackButton.pressed.connect(_on_settings_back_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	continue_button.disabled = not Game.has_any_save()
	continue_button.tooltip_text = (
		"No save found. Start a New Game and save from the pause menu (Esc)."
		if continue_button.disabled
		else "Load the most recent save or autosave."
	)

	settings_panel.visible = false
	main_buttons.visible = true
	_refresh_settings_controls()
	%NewGameButton.grab_focus()


func _refresh_settings_controls() -> void:
	var volume := float(Settings.get_setting("audio/master_volume", 0.8))
	master_slider.value = volume * 100.0
	master_value.text = "%d%%" % roundi(master_slider.value)
	fullscreen_check.button_pressed = bool(Settings.get_setting("display/fullscreen", false))


func _on_new_game_pressed() -> void:
	Game.new_game(0)


func _on_continue_pressed() -> void:
	Game.continue_game()


func _on_settings_pressed() -> void:
	main_buttons.visible = false
	settings_panel.visible = true
	master_slider.grab_focus()


func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	main_buttons.visible = true
	%SettingsButton.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_master_volume_changed(value: float) -> void:
	master_value.text = "%d%%" % roundi(value)
	Settings.set_setting("audio/master_volume", value / 100.0)
	Settings.apply_all()
	Settings.save_settings()


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	Settings.set_setting("display/fullscreen", toggled_on)
	Settings.apply_all()
	Settings.save_settings()
