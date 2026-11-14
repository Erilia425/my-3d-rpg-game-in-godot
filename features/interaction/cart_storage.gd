extends StaticBody3D
## The Hollow Cart: a place to leave crafting goods in the 3D town.
##
## Ported from the 2D `cart.gd`. The cart owns the stored counts; the bag counts
## live in `InventoryComponent`, exactly like the chest. One item moves per
## button press, and the status line keeps the 2D wording. See AGENTS.md 6.3.
##
## The panel is built in code because it is small and only the cart uses it. It
## blocks the player while open and restores the mouse mode on close.

## Stable id for the save file. Leave empty for a cart that should not persist.
@export var save_id: StringName = &""
## Items the cart accepts, in the order the rows are drawn.
@export var items: Array[StringName] = [
	&"item.mushroom",
	&"item.flower",
	&"item.hearth_silk",
]

const TITLE := "Hollow Cart Storage"
const INSTRUCTIONS := "Deposit or retrieve one item at a time."
const DEFAULT_STATUS := "Your supplies are safe here."

## Item id (as String) -> stored count.
var _storage: Dictionary = {}
var _open := false
var _player: Node = null
var _opened_frame := -1

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")

	_build_ui()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	return "" if _open else "Use cart storage"


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_storage(interactor)


func _open_storage(interactor: Node) -> void:
	_open = true
	_player = interactor
	# The same E press that opened the panel can still reach this node's
	# unhandled input. Ignore input for the rest of this frame.
	_opened_frame = Engine.get_process_frames()

	_status.text = DEFAULT_STATUS
	_panel.visible = true
	_layer.visible = true
	_refresh()

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_storage() -> void:
	if not _open:
		return

	_open = false
	_panel.visible = false
	_layer.visible = false

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", false)
	_player = null

	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact"):
		close_storage()
		get_viewport().set_input_as_handled()


## Pausing (Escape) owns the screen; the cart must not stay open behind it.
func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_storage()


# --- storage rows ----------------------------------------------------------


func _deposit(id: StringName) -> void:
	var inventory := _inventory()
	if inventory == null or inventory.get_amount(id) <= 0:
		_status.text = "You don't have any %s to deposit." % _item_name(id)
		return

	if not inventory.remove_item(id, 1):
		_status.text = "You don't have any %s to deposit." % _item_name(id)
		return

	var key := String(id)
	_storage[key] = int(_storage.get(key, 0)) + 1
	_status.text = "Deposited 1 %s." % _item_name(id)
	_refresh()


func _take(id: StringName) -> void:
	var key := String(id)
	var stored := int(_storage.get(key, 0))
	if stored <= 0:
		_status.text = "There are no %s in the cart." % _item_name(id)
		return

	var data := ItemDatabase.get_item(id)
	var inventory := _inventory()
	if data == null or inventory == null:
		return

	if inventory.add_item(data, 1) <= 0:
		_status.text = "Your inventory is full."
		return

	stored -= 1
	if stored <= 0:
		_storage.erase(key)
	else:
		_storage[key] = stored

	_status.text = "Retrieved 1 %s." % _item_name(id)
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var inventory := _inventory()
	for id in items:
		var data := ItemDatabase.get_item(id)
		if data == null:
			continue

		var bag := inventory.get_amount(id) if inventory != null else 0
		var stored := int(_storage.get(String(id), 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)

		var label := Label.new()
		label.text = "%s  Bag: %d  Cart: %d" % [data.display_name, bag, stored]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var deposit := Button.new()
		deposit.text = "Deposit 1"
		deposit.pressed.connect(_deposit.bind(id))
		row.add_child(deposit)

		var take := Button.new()
		take.text = "Take 1"
		take.pressed.connect(_take.bind(id))
		row.add_child(take)


# --- helpers ---------------------------------------------------------------


func _inventory() -> InventoryComponent:
	if _player == null or not _player.has_method("get_inventory_component"):
		return null
	return _player.call("get_inventory_component") as InventoryComponent


func _item_name(id: StringName) -> String:
	var data := ItemDatabase.get_item(id)
	return String(id) if data == null else data.display_name


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CartStorageUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(440, 300)
	centre.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = TITLE
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	var instructions := Label.new()
	instructions.text = INSTRUCTIONS
	layout.add_child(instructions)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = DEFAULT_STATUS
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_storage)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"storage": _storage.duplicate()}


func load_data(data: Dictionary) -> void:
	_storage.clear()

	var saved: Dictionary = data.get("storage", {})
	for raw_id in saved:
		var id := StringName(str(raw_id))
		var amount := int(saved[raw_id])
		if ItemDatabase.get_item(id) == null or amount <= 0:
			continue
		_storage[String(id)] = amount

	if _open:
		_refresh()
