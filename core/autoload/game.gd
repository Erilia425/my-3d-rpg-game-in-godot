extends Node
## Owns the high-level game state, pause behavior, saving, and scene travel.
##
## States: BOOT -> MAIN_MENU -> PLAYING <-> PAUSED.
## See AGENTS.md sections 4.4, 4.6, and 8.

enum State {
	BOOT,
	MAIN_MENU,
	PLAYING,
	PAUSED,
}

const TEST_ROOM := "res://scenes/test_room.tscn"
const OVERWORLD := "res://scenes/overworld.tscn"

## Slot 0 is the player's manual/quicksave slot. Slot 1 is reserved for the
## autosave, so autosaving can never overwrite a deliberate save.
const MANUAL_SLOT := 0
const AUTOSAVE_SLOT := 1
const SAVE_SLOTS: Array[int] = [MANUAL_SLOT, AUTOSAVE_SLOT]

## Must match `PlayerController.SAVE_ID`. Kept here so core code does not have
## to reach into a feature class.
const PLAYER_ENTRY_ID := "player"

var state: State = State.BOOT
## Slot the running session was loaded from. -1 after a brand-new game.
var current_slot: int = -1

## Saveable state that outlives a single scene: doors and chests you opened in
## the room must still be open when you come back from the overworld. Scene
## loads merge into this dictionary, and every save is a snapshot of it.
var world_state: Dictionary = {}

var _suppress_autosave := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SceneRouter.scene_changed.connect(_on_scene_changed)
	set_state(State.BOOT)


## Game time only moves while the player is actually playing. `Game` runs with
## PROCESS_MODE_ALWAYS so it can handle the pause key, which is why the state
## check is here rather than relying on the pause tree.
func _process(delta: float) -> void:
	if state == State.PLAYING:
		WorldClock.advance(delta)


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


# --- sessions --------------------------------------------------------------


func new_game(slot: int = MANUAL_SLOT) -> void:
	current_slot = slot
	WorldClock.reset()
	world_state.clear()
	set_state(State.PLAYING)
	SceneRouter.goto_scene(TEST_ROOM, true)


## Picks the newest readable save across the known slots. Stamps are ISO 8601,
## so comparing them as strings is enough.
func newest_slot(slots: Array = SAVE_SLOTS) -> int:
	var best := -1
	var best_stamp := ""

	for slot in slots:
		var index := int(slot)
		var stamp := SaveManager.get_saved_at(index)
		if stamp.is_empty():
			continue
		if best < 0 or stamp > best_stamp:
			best = index
			best_stamp = stamp

	return best


func has_any_save(slots: Array = SAVE_SLOTS) -> bool:
	return newest_slot(slots) >= 0


## Loads whichever slot changed most recently (manual or autosave).
func continue_game() -> bool:
	var slot := newest_slot()
	if slot < 0:
		return false
	load_game(slot)
	return true


# --- saving ----------------------------------------------------------------


## Snapshots the live scene into `world_state`, then writes that dictionary.
func save_game(slot: int = MANUAL_SLOT) -> bool:
	world_state.merge(SaveManager.collect_saveables(), true)
	return SaveManager.write_save_dict(slot, SaveManager.build_save_dict(world_state))


func autosave() -> bool:
	if state != State.PLAYING:
		return false
	var ok := save_game(AUTOSAVE_SLOT)
	if ok:
		Events.notification_requested.emit("Autosaved")
	return ok


func quick_save() -> bool:
	if state != State.PLAYING:
		return false
	var ok := save_game(MANUAL_SLOT)
	Events.notification_requested.emit("Quicksaved" if ok else "Quicksave failed")
	return ok


## Starts loading the newest save. Returns false when there is nothing to load;
## the load itself continues asynchronously on this autoload.
func quick_load() -> bool:
	if state != State.PLAYING:
		return false
	var slot := newest_slot()
	if slot < 0:
		Events.notification_requested.emit("No save to load")
		return false
	load_game(slot)
	return true


## Reads the slot, swaps to the scene it was saved in, and then applies the
## data. Returns false only when the slot cannot be read; the scene change is
## asynchronous, so callers that need to act afterwards should `await` it.
func load_game(slot: int = MANUAL_SLOT) -> bool:
	var data := SaveManager.read_slot(slot)
	if data.is_empty():
		return false

	var scene_path := String(data.get("scene", TEST_ROOM))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Game: save in slot %d points at a missing scene; using the test room." % slot)
		scene_path = TEST_ROOM

	current_slot = slot
	world_state = (data.get("saveables", {}) as Dictionary).duplicate(true)

	set_state(State.PLAYING)
	_suppress_autosave = true
	await SceneRouter.goto_scene(scene_path, true)
	SaveManager.apply_save(data)
	_suppress_autosave = false
	return true


# --- travel ----------------------------------------------------------------


## Moves the player to another scene, carrying health, inventory, equipment,
## world time, and the state of every object seen so far.
##
## `spawn_position` is where the player appears in the destination; the position
## they left is deliberately not carried over. Callers should not `await` this
## from the scene that is about to be replaced.
func travel_to(scene_path: String, spawn_position: Variant = null) -> bool:
	if state != State.PLAYING:
		return false
	if SceneRouter.is_transitioning():
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("Game: travel target not found: %s" % scene_path)
		return false

	world_state.merge(SaveManager.collect_saveables(), true)
	var player_entry: Dictionary = world_state.get(PLAYER_ENTRY_ID, {})
	player_entry.erase("position")
	player_entry.erase("yaw")
	player_entry.erase("pitch")
	world_state[PLAYER_ENTRY_ID] = player_entry

	_suppress_autosave = true
	await SceneRouter.goto_scene(scene_path, true)

	if spawn_position is Vector3:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null:
			player.global_position = spawn_position

	# Record the arrival point, otherwise the autosave written just below would
	# remember the *previous* scene's coordinates (they were erased above) and a
	# quick load would drop the player at the scene default. Only the player
	# entry is refreshed; chest and door state from earlier scenes is kept.
	var arrival := SaveManager.collect_saveables()
	if arrival.has(PLAYER_ENTRY_ID):
		world_state[PLAYER_ENTRY_ID] = arrival[PLAYER_ENTRY_ID]

	SaveManager.apply_save(_transient_save())
	_suppress_autosave = false
	autosave()
	return true


func _transient_save() -> Dictionary:
	return {
		"version": SaveManager.SAVE_VERSION,
		"world": {"time": WorldClock.save_data()},
		"saveables": world_state,
	}


## Autosave on every finished gameplay scene change: starting a new game and
## walking through a load door both count as major transitions.
func _on_scene_changed(_path: String) -> void:
	if _suppress_autosave or state != State.PLAYING:
		return
	autosave()


# --- pause and quit --------------------------------------------------------


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
	autosave()
	world_state.clear()
	set_state(State.MAIN_MENU)
	SceneRouter.goto_main_menu()


func quit_to_desktop() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause_game()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()
		return

	if state != State.PLAYING:
		return

	if event.is_action_pressed("quick_save"):
		quick_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		quick_load()
		get_viewport().set_input_as_handled()
