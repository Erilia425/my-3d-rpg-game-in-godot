extends CanvasLayer
## Pause overlay. Visible only while Game.state is PAUSED.
##
## Saving and loading live here because pausing is the safe moment to touch the
## disk: no physics tick is mid-flight and the player has already stopped.

@onready var _root: Control = %PauseRoot
@onready var _status: Label = %StatusLabel


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

	_refresh_load_state()


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	_root.visible = current_state == Game.State.PAUSED
	if not _root.visible:
		return

	_status.text = ""
	_refresh_load_state()
	%ResumeButton.grab_focus()


## A slot that was never saved has nothing to load.
func _refresh_load_state() -> void:
	%LoadButton.disabled = not SaveManager.has_slot(Game.MANUAL_SLOT)
	%AutosaveButton.disabled = not SaveManager.has_slot(Game.AUTOSAVE_SLOT)


func _on_resume_pressed() -> void:
	Game.resume_game()


func _on_save_pressed() -> void:
	if Game.save_game(Game.MANUAL_SLOT):
		_status.text = "Saved to slot %d." % Game.MANUAL_SLOT
	else:
		_status.text = "Save failed: %s" % SaveManager.get_last_error()
	_refresh_load_state()


func _on_load_pressed() -> void:
	_load_slot(Game.MANUAL_SLOT)


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
