extends Control
## Full-screen storybook map of Mycelgrove Hollow, toggled with the `map` action.
##
## The screen is a child of the HUD, so every gameplay scene gets it for free.
## While it is open the player is UI-blocked and the mouse is released, exactly
## like the inventory panel. See AGENTS.md sections 6 and 7.

## The town generator maps the reference image with
## `x = (px - 656) * 0.14` and `z = (py - 600) * 0.14`, so these invert it.
const TOWN_SCENE := "res://scenes/town.tscn"
const MAP_CENTER := Vector2(656.0, 600.0)
const MAP_SCALE := 0.14

@onready var _image: TextureRect = %MapImage
@onready var _marker: Label = %YouAreHere

var _player: PlayerController


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Events.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING and not visible:
		return
	if _dialogue_is_open():
		return

	if event.is_action_pressed("map"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# Escape closes the map instead of opening the pause menu while it is up.
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
	_put_inventory_away()
	visible = true
	if is_instance_valid(_player):
		_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_marker()


func close() -> void:
	visible = false
	if is_instance_valid(_player):
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


## Marks the player on the town map. Other scenes (the room, the overworld,
## interiors) don't share this map, so the tag hides there.
func _refresh_marker() -> void:
	_marker.visible = false
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != TOWN_SCENE:
		return
	if not is_instance_valid(_player) or _image.texture == null or _image.size.x <= 0.0:
		return

	var size := _image.texture.get_size()
	var px := MAP_CENTER.x + _player.global_position.x / MAP_SCALE
	var py := MAP_CENTER.y + _player.global_position.z / MAP_SCALE
	var at := Vector2(px / size.x, py / size.y) * _image.size
	at.x = clampf(at.x, 2.0, _image.size.x - 110.0)
	at.y = clampf(at.y, 2.0, _image.size.y - 28.0)
	_marker.position = at - Vector2(0.0, 18.0)
	_marker.visible = true


func _dialogue_is_open() -> bool:
	var window := get_parent().get_node_or_null("DialogueWindow") as Control
	return window != null and window.visible


func _put_inventory_away() -> void:
	var hud := get_parent()
	if hud != null and hud.has_method("close_inventory"):
		get_parent().call("close_inventory")


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
