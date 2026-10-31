extends CanvasLayer
## Gameplay HUD: crosshair, interaction prompt, and notification toasts.
##
## The HUD only listens to events and displays them. It never changes gameplay
## state. See AGENTS.md section 6.

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _toast_label: Label = %ToastLabel

var _interact_key := "E"
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_interact_key = _get_action_key_label("interact")

	Events.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_state_changed.connect(_on_game_state_changed)
	Events.camera_mode_changed.connect(_on_camera_mode_changed)

	_prompt_panel.visible = false
	_toast_label.modulate.a = 0.0


func _get_action_key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"

	var key_event := events[0] as InputEventKey
	if key_event == null:
		return "?"

	var code := key_event.physical_keycode
	if code == 0:
		code = key_event.keycode
	return OS.get_keycode_string(code)


func _on_interaction_prompt_changed(text: String) -> void:
	if text.is_empty():
		_prompt_panel.visible = false
		return

	_prompt_label.text = "[%s] %s" % [_interact_key, text]
	_prompt_panel.visible = true


func _on_notification_requested(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		_prompt_panel.visible = false


func _on_camera_mode_changed(is_first_person: bool) -> void:
	# In third person the player's body sits between the camera and the
	# crosshair, so the crosshair is hidden. The interaction prompt still shows
	# what you are looking at.
	_crosshair.visible = is_first_person
