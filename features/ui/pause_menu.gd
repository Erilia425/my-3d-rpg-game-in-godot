extends CanvasLayer
## Pause overlay. Visible only while Game.state is PAUSED.

@onready var _root: Control = %PauseRoot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false

	Events.game_state_changed.connect(_on_game_state_changed)
	%ResumeButton.pressed.connect(_on_resume_pressed)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	_root.visible = current_state == Game.State.PAUSED
	if _root.visible:
		%ResumeButton.grab_focus()


func _on_resume_pressed() -> void:
	Game.resume_game()


func _on_main_menu_pressed() -> void:
	Game.quit_to_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
