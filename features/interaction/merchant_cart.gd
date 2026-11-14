extends StaticBody3D
## The rare-ingredient cart that walks the market square.
##
## A sibling of `cart_storage.gd`: same panel-in-code approach and the same
## "one thing per button press" rule, but this cart sells instead of storing.
## Coins come from `Progression`, prices are the item's `value` with any favour
## discount applied, and each item has a limited stock that is saved with the
## cart. See AGENTS.md sections 4.6 and 8.
##
## The cart itself is a `StaticBody3D`; `moving_merchant_cart.tscn` moves its
## parent so the collision, billboard art and interaction stay untouched.

## Stable id for the save file. Leave empty for a cart that should not persist.
@export var save_id: StringName = &""
## Rare goods on the shelf, in the order the rows are drawn.
@export var stock: Array[StringName] = [
	&"item.spore_saffron",
	&"item.ghost_cap",
	&"item.mirror_thread",
	&"item.hollow_honey",
]
## How many of each item the cart starts with.
@export var stock_amount: int = 3

const TITLE := "Rare Ingredient Cart"
const INSTRUCTIONS := "Rare finds from the deep wood. One purchase at a time."
const DEFAULT_STATUS := "Everything here was gathered by hand."

## Item id (as String) -> count left on the cart.
var _remaining: Dictionary = {}
var _open := false
var _player: Node = null
var _opened_frame := -1

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _coins: Label
var _status: Label


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")

	_ensure_stock()
	_build_ui()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	return "" if _open else "Browse the merchant cart"


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_cart(interactor)


func _open_cart(interactor: Node) -> void:
	_ensure_stock()
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


func close_cart() -> void:
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
		close_cart()
		get_viewport().set_input_as_handled()


## Pausing (Escape) owns the screen; the cart must not stay open behind it.
func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_cart()


# --- buying ----------------------------------------------------------------


func _buy(id: StringName) -> void:
	_ensure_stock()

	var key := String(id)
	var left := int(_remaining.get(key, 0))
	if left <= 0:
		_status.text = "The cart is out of %s." % _item_name(id)
		return

	var data := ItemDatabase.get_item(id)
	var inventory := _inventory()
	if data == null or inventory == null:
		return

	var price := _price(id)
	if not Progression.spend_coins(price):
		_status.text = "You need %d coins for that." % price
		return

	# Give the item first; if the bag is full, put the coins back.
	if inventory.add_item(data, 1) <= 0:
		Progression.add_coins(price)
		_status.text = "Your inventory is full."
		return

	left -= 1
	_remaining[key] = left
	_status.text = "Bought 1 %s for %d coins." % [data.display_name, price]
	_refresh()


func _price(id: StringName) -> int:
	var data := ItemDatabase.get_item(id)
	if data == null:
		return 0
	return Progression.get_discounted_price(data.value)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	_coins.text = "Coins: %d" % Progression.get_coins()

	for id in stock:
		var data := ItemDatabase.get_item(id)
		if data == null:
			continue

		var left := int(_remaining.get(String(id), 0))
		var price := _price(id)
		var sold_out := left <= 0
		var can_afford := Progression.get_coins() >= price

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)

		var text := Label.new()
		text.text = "%s  —  %d coins  (left: %d)" % [data.display_name, price, left]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

		var buy := Button.new()
		buy.text = "Sold out" if sold_out else "Buy 1"
		buy.disabled = sold_out or not can_afford
		buy.pressed.connect(_buy.bind(id))
		row.add_child(buy)

	if Progression.get_best_discount() > 0.0:
		var note := Label.new()
		note.text = "A friendly face gets you %d%% off." % roundi(
			Progression.get_best_discount() * 100.0
		)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(note)


# --- helpers ---------------------------------------------------------------


func _ensure_stock() -> void:
	for id in stock:
		var key := String(id)
		if not _remaining.has(key):
			_remaining[key] = stock_amount


func _inventory() -> InventoryComponent:
	if _player == null or not _player.has_method("get_inventory_component"):
		return null
	return _player.call("get_inventory_component") as InventoryComponent


func _item_name(id: StringName) -> String:
	var data := ItemDatabase.get_item(id)
	return String(id) if data == null else data.display_name


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "MerchantCartUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 340)
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
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instructions)

	_coins = Label.new()
	_coins.text = "Coins: 0"
	layout.add_child(_coins)

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
	close_button.pressed.connect(close_cart)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"remaining": _remaining.duplicate()}


func load_data(data: Dictionary) -> void:
	_ensure_stock()

	var saved: Dictionary = data.get("remaining", {})
	for raw_id in saved:
		var key := String(raw_id)
		var amount := int(saved[raw_id])
		if not _remaining.has(key):
			continue
		if ItemDatabase.get_item(StringName(key)) == null:
			continue
		_remaining[key] = maxi(amount, 0)

	if _open:
		_refresh()
