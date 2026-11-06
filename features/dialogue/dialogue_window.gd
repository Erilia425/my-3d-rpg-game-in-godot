extends Control
## Storybook dialogue window for villagers.
##
## Lives in the HUD, so every gameplay scene has it. A villager asks for a
## conversation through `Events.dialogue_requested`; this window shows one line
## at a time and blocks the player while it is open, like the inventory.
##
## E or Space advances; E/Space on the last line, or Esc at any time, closes.
## See AGENTS.md sections 6 and 7.

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _role_label: Label = %RoleLabel
@onready var _line_label: Label = %LineLabel
@onready var _hint_label: Label = %HintLabel

var _lines: PackedStringArray = PackedStringArray()
var _index := 0
var _player: PlayerController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Events.dialogue_requested.connect(_on_dialogue_requested)
	Events.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func open_dialogue(speaker: String, role: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return

	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_lines = lines
	_index = 0
	_speaker_label.text = speaker
	_role_label.text = role
	_role_label.visible = not role.is_empty()
	_show_line()
	visible = true
	if is_instance_valid(_player):
		_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func advance() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
		return
	_show_line()


func close() -> void:
	visible = false
	if is_instance_valid(_player):
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func _show_line() -> void:
	_line_label.text = _lines[_index]

	var action := "close" if _index >= _lines.size() - 1 else "continue"
	_hint_label.text = "%d / %d      E or Space  %s      Esc  close" % [
		_index + 1, _lines.size(), action
	]


func _on_dialogue_requested(speaker: String, role: String, lines: PackedStringArray) -> void:
	open_dialogue(speaker, role, lines)


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
