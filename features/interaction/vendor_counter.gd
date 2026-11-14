class_name VendorCounter
extends StaticBody3D
## A small counter where a villager sells their own goods for coins.
##
## Deliberately separate from the market's `LedgerShopPanel`: that panel is a
## general store for upgrades and random stock, while this is *someone's* counter
## with a fixed list and a face behind it. Prices use the vendor's own favor
## discount, and every purchase nudges that favor up, so a regular customer is
## slowly charged less. Nothing here is randomised and nothing needs saving:
## the stock is what the villager makes, not a limited crate.
##
## Coins live in `Progression`; goods live in `InventoryComponent`. This node owns
## neither. See AGENTS.md 6.3.

## One counter per table. `item` is what is sold, `price` is coins before the
## vendor's discount, and `note` is the line under the name.
const TABLES: Dictionary = {
	&"bell": [
		{
			"item": &"item.sporebread",
			"amount": 1,
			"price": 6,
			"note": "Baked this morning, still warm.",
		},
		{
			"item": &"item.honey",
			"amount": 1,
			"price": 5,
			"note": "Thatch's, from the Hive Tower.",
		},
		{
			"item": &"item.memory_honey",
			"amount": 1,
			"price": 14,
			"note": "Prepared. One jar is enough for a spell.",
		},
		{
			"item": &"item.cabbage",
			"amount": 2,
			"price": 3,
			"note": "From the communal beds.",
		},
	],
}

## Which table this counter sells. `bell` is the only one so far.
@export var table_id: StringName = &"bell"
## Who is selling. Favor is tracked per villager, so this must match the NPC id.
@export var vendor_id: StringName = &"npc.auntie_bell"
## Panel heading.
@export var title: String = "Auntie Bell's Counter"
## One line above the goods.
@export var greeting: String = (
	"Take what you need, dear. I'll write it down."
)

const C_PAPER := Color(0.86, 0.79, 0.63, 1)
const C_INK := Color(0.24, 0.16, 0.09, 1)
const C_SOFT := Color(0.44, 0.36, 0.24, 1)

var _open := false
var _player: Node = null
var _opened_frame := -1

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label
var _coins: Label


func _ready() -> void:
	add_to_group(&"interactable")
	_build_visual()
	_build_ui()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	if _open:
		return ""
	return "Look at the counter" if get_offers().is_empty() else "Buy something"


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_panel(interactor)


func is_open() -> bool:
	return _open


## The stock rows, so a panel or a test can read the counter without guessing.
func get_offers() -> Array:
	return TABLES.get(table_id, [])


## Coins this counter charges for one row, after the vendor's own discount.
func get_price(index: int) -> int:
	var offers := get_offers()
	if index < 0 or index >= offers.size():
		return 0
	var base := int(offers[index]["price"])
	var discount := Progression.get_discount(vendor_id)
	return maxi(int(round(float(base) * (1.0 - discount))), 1)


# --- buying ----------------------------------------------------------------


## Buys one row. Coins are taken only after the goods fit in the bag, so a full
## inventory never eats a customer's money.
func buy(index: int, interactor: Node) -> bool:
	var offers := get_offers()
	if index < 0 or index >= offers.size():
		return false

	var offer: Dictionary = offers[index]
	var data := ItemDatabase.get_item(offer["item"])
	var inventory := _inventory(interactor)
	if data == null or inventory == null:
		return false

	var price := get_price(index)
	if Progression.get_coins() < price:
		Events.notification_requested.emit(
			"That is %d coins. You have %d" % [price, Progression.get_coins()]
		)
		return false

	if inventory.add_item(data, int(offer["amount"])) <= 0:
		Events.notification_requested.emit("Your bag is full")
		return false

	Progression.spend_coins(price)
	# Buying from the same person repeatedly is how the Hollow measures trust.
	Progression.add_favor(vendor_id, 1)

	Events.notification_requested.emit(
		"%s  (-%d coins)" % [data.display_name, price]
	)
	if _open:
		_refresh()
	return true


# --- panel -----------------------------------------------------------------


func _open_panel(interactor: Node) -> void:
	_open = true
	_player = interactor
	# The E press that opened the panel can still reach this node's input.
	_opened_frame = Engine.get_process_frames()

	_status.text = greeting
	_panel.visible = true
	_layer.visible = true
	_refresh()

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
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
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


## Pausing owns the screen; the counter must not stay open behind it.
func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_panel()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	_coins.text = "%d coins" % Progression.get_coins()
	var discount := Progression.get_discount(vendor_id)
	if discount > 0.0:
		_coins.text += "   (friends' price, %d%% off)" % int(round(discount * 100.0))

	var offers := get_offers()
	if offers.is_empty():
		_add_note(_list, "Nothing on the counter today.")
		return

	for index in offers.size():
		var offer: Dictionary = offers[index]
		var data := ItemDatabase.get_item(offer["item"])
		if data == null:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_list.add_child(row)

		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 0)
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)

		var name_label := Label.new()
		var amount := int(offer["amount"])
		name_label.text = data.display_name if amount <= 1 else "%s x%d" % [data.display_name, amount]
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", C_INK)
		text_box.add_child(name_label)

		var note_label := Label.new()
		note_label.text = String(offer["note"])
		note_label.add_theme_font_size_override("font_size", 12)
		note_label.add_theme_color_override("font_color", C_SOFT)
		text_box.add_child(note_label)

		var price := get_price(index)
		var price_label := Label.new()
		price_label.text = "%d coins" % price
		price_label.custom_minimum_size = Vector2(96, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.add_theme_font_size_override("font_size", 14)
		price_label.add_theme_color_override("font_color", C_INK)
		row.add_child(price_label)

		var button := Button.new()
		button.text = "Buy"
		button.custom_minimum_size = Vector2(78, 0)
		button.disabled = Progression.get_coins() < price
		button.pressed.connect(_on_buy.bind(index))
		row.add_child(button)


func _add_note(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", C_SOFT)
	parent.add_child(label)


func _on_buy(index: int) -> void:
	buy(index, _player)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "VendorLayer"
	_layer.layer = 6
	_layer.visible = false
	add_child(_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.025, 0.02, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PAPER
	style.border_color = Color(0.3, 0.22, 0.13, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.02, 0.015, 0.01, 0.7)
	style.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", style)
	centre.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_INK)
	header.add_child(heading)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_coins = Label.new()
	_coins.add_theme_font_size_override("font_size", 14)
	_coins.add_theme_color_override("font_color", C_SOFT)
	header.add_child(_coins)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", C_SOFT)
	layout.add_child(_status)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	layout.add_child(_list)

	var footer := Label.new()
	footer.text = "E or Esc closes the counter"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", C_SOFT)
	layout.add_child(footer)


# --- look ------------------------------------------------------------------


## A small standing counter: wood, a slate board, a brass bell and a tray. Built
## in code so the interior needs no new art.
func _build_visual() -> void:
	if get_node_or_null("Stand") != null:
		return

	var plain := get_node_or_null("Mesh") as MeshInstance3D
	if plain != null:
		plain.visible = false

	var timber := _mat(Color(0.44, 0.31, 0.19, 1), 0.9)
	var plank := _mat(Color(0.58, 0.44, 0.28, 1), 0.9)
	var slate := _mat(Color(0.16, 0.17, 0.18, 1), 0.7)
	var brass := _mat(Color(0.7, 0.55, 0.24, 1), 0.4, 0.2)
	var linen := _mat(Color(0.86, 0.82, 0.72, 1), 0.95)

	var stand := Node3D.new()
	stand.name = "Stand"
	add_child(stand)

	_box(stand, "Body", Vector3(0, 0.44, 0), Vector3(1.3, 0.88, 0.5), timber)
	_box(stand, "Top", Vector3(0, 0.91, 0), Vector3(1.42, 0.08, 0.6), plank)
	_box(stand, "Foot", Vector3(0, 0.04, 0), Vector3(1.36, 0.08, 0.54), timber)
	for i in 2:
		_box(stand, "Panel", Vector3(-0.3 + i * 0.6, 0.5, 0.26), Vector3(0.5, 0.6, 0.03), plank)

	# A slate board leaning on the counter, with the day's list chalked on it.
	_box(stand, "Board", Vector3(0, 1.16, -0.16), Vector3(0.6, 0.4, 0.03), slate)
	_box(stand, "BoardFrame", Vector3(0, 1.16, -0.15), Vector3(0.66, 0.46, 0.02), timber)
	_box(stand, "Chalk", Vector3(-0.06, 1.2, -0.13), Vector3(0.36, 0.02, 0.01), linen)
	_box(stand, "Chalk", Vector3(-0.02, 1.12, -0.13), Vector3(0.44, 0.02, 0.01), linen)

	# The bell you ring to be served.
	_box(stand, "BellBase", Vector3(0.42, 0.96, 0.05), Vector3(0.16, 0.03, 0.16), brass)
	var dome := MeshInstance3D.new()
	dome.name = "Bell"
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.14
	sphere.is_hemisphere = true
	dome.mesh = sphere
	dome.material_override = brass
	dome.position = Vector3(0.42, 1.02, 0.05)
	stand.add_child(dome)

	# A tray of the morning's baking.
	_box(stand, "Tray", Vector3(-0.4, 0.96, 0.04), Vector3(0.5, 0.04, 0.38), slate)
	for i in 3:
		var bun := MeshInstance3D.new()
		bun.name = "Bun"
		var mesh := SphereMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.08
		bun.mesh = mesh
		bun.material_override = plank
		bun.position = Vector3(-0.56 + i * 0.16, 1.03, 0.04)
		stand.add_child(bun)


func _box(
	parent: Node3D, node_name: String, at: Vector3, size: Vector3, mat: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _inventory(node: Node) -> InventoryComponent:
	if node != null and node.has_method("get_inventory_component"):
		return node.call("get_inventory_component") as InventoryComponent
	if node != null:
		return node.get_node_or_null("InventoryComponent") as InventoryComponent
	return null
