extends Node
## Owns the high-level game state and pause behavior.
##
## States: BOOT -> MAIN_MENU -> PLAYING <-> PAUSED.
## See AGENTS.md sections 4.4 and 4.6.

enum State {
	BOOT,
	MAIN_MENU,
	PLAYING,
	PAUSED,
}

const TEST_ROOM := "res://scenes/test_room.tscn"

var state: State = State.BOOT
var current_slot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_state(State.BOOT)


func set_state(new_state: State) -> void:
	if new_state == state:
		return

	var previous := state
	state = new_state

	match state:
		State.PLAYING:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		State.PAUSED:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		State.MAIN_MENU, State.BOOT:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	Events.game_state_changed.emit(int(previous), int(state))


func get_state_name() -> StringName:
	match state:
		State.BOOT:
			return &"BOOT"
		State.MAIN_MENU:
			return &"MAIN_MENU"
		State.PLAYING:
			return &"PLAYING"
		State.PAUSED:
			return &"PAUSED"
	return &"UNKNOWN"


func new_game(slot: int = 0) -> void:
	current_slot = maxi(slot, 0)
	set_state(State.PLAYING)
	SceneRouter.goto_scene(TEST_ROOM, true)


func save_game(slot: int = -1) -> bool:
	var target_slot := current_slot if slot < 0 else slot
	return SaveManager.save_slot(target_slot)


func load_game(slot: int = 0) -> bool:
	if not SaveManager.has_slot(slot):
		return false
	return SaveManager.load_slot(slot)


func pause_game() -> void:
	if state == State.PLAYING:
		set_state(State.PAUSED)


func resume_game() -> void:
	if state == State.PAUSED:
		set_state(State.PLAYING)


func toggle_pause() -> void:
	if state == State.PLAYING:
		pause_game()
	elif state == State.PAUSED:
		resume_game()


func quit_to_menu() -> void:
	set_state(State.MAIN_MENU)
	SceneRouter.goto_main_menu()


func quit_to_desktop() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	if state == State.PLAYING:
		pause_game()
		get_viewport().set_input_as_handled()
	elif state == State.PAUSED:
		resume_game()
		get_viewport().set_input_as_handled()
