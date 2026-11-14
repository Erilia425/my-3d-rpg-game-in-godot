extends Control
## Full-screen quest journal of Mycelgrove Hollow, toggled with the `journal`
## action.
##
## The screen is a child of the HUD, so every gameplay scene gets it for free.
## While it is open the player is UI-blocked and the mouse is released, exactly
## like the inventory panel and the map. It only reads `QuestLog` and
## `DiscoveryLog`; it never changes quest progress. See AGENTS.md sections 4.6
## and 6.

@onready var _active_list: VBoxContainer = %ActiveList
@onready var _completed_list: VBoxContainer = %CompletedList
@onready var _discovery_list: VBoxContainer = %DiscoveryList
@onready var _empty_label: Label = %EmptyLabel

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

	if event.is_action_pressed("journal"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# Escape closes the journal instead of opening the pause menu while it is up.
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


## Rebuilds the three lists from the current quest and discovery state. Called
## only when the panel opens, never every frame.
func _refresh() -> void:
	_clear(_active_list)
	_clear(_completed_list)
	_clear(_discovery_list)

	var active := QuestLog.get_active_ids()
	var completed := QuestLog.get_completed_ids()
	var discoveries := DiscoveryLog.get_unlocked()

	for id in active:
		_add_entry(_active_list, QuestLog.get_title(id), QuestLog.get_summary(id))
	for id in completed:
		_add_entry(_completed_list, QuestLog.get_title(id), QuestLog.get_summary(id))
	for id in discoveries:
		_add_entry(
			_discovery_list,
			DiscoveryLog.get_title(StringName(id)),
			DiscoveryLog.get_description(StringName(id))
		)

	_empty_label.visible = active.is_empty() and completed.is_empty() and discoveries.is_empty()


func _add_entry(parent: VBoxContainer, title: String, body: String) -> void:
	if title.is_empty():
		return

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1))
	parent.add_child(title_label)

	if body.is_empty():
		return

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color(0.32, 0.25, 0.16, 1))
	parent.add_child(body_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	parent.add_child(spacer)


func _clear(parent: VBoxContainer) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _dialogue_is_open() -> bool:
	var window := get_parent().get_node_or_null("DialogueWindow") as Control
	return window != null and window.visible


func _put_other_panels_away() -> void:
	var hud := get_parent()
	if hud == null:
		return
	if hud.has_method("close_inventory"):
		hud.call("close_inventory")
	var map := hud.get_node_or_null("MapScreen")
	if map != null and map.has_method("close") and map.visible:
		map.call("close")


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
