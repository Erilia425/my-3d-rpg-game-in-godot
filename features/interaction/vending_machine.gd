class_name VendingMachine
extends StaticBody3D
## The unlabelled machine in the market square.
##
## Lore: a dark cabinet appears in the centre of Mycelgrove Hollow. Nobody has
## ever broken into it and nobody has the right coin, until the strange family
## coin from Rowan's house fits the one slot that is the wrong shape for
## everything else. It vends moss-covered rocks, small opals, faux ivory
## brooches, mushrooms to plant, tiny sacks of dirt, and gnome statues.
##
## The machine owns only its own stock and whether it is awake. Payment and
## goods live in `InventoryComponent`, exactly like the chest and the cart. See
## AGENTS.md 6.3.
##
## Teeth stay out of this economy on purpose: teeth are anchors for magic, not
## pocket change. The machine takes sea glass and pale gemstones, both mined in
## the Old Adit.

## Stable id for the save file. Leave empty for a machine that should not persist.
@export var save_id: StringName = &"machine.market_square"
## The coin that wakes the machine. Consumed once.
@export var unlock_item: StringName = &"item.spider_coin"

## One row per slot, in the order the machine shows them. `pay` is the item the
## machine wants and `price` is how many of it. `stock` is how many vends the
## slot holds before it runs dry.
const OFFERS: Array[Dictionary] = [
	{"item": &"item.moss_rock", "amount": 1, "pay": &"item.seaglass", "price": 2, "stock": 4},
	{"item": &"item.small_opal", "amount": 1, "pay": &"item.seaglass", "price": 3, "stock": 2},
	{"item": &"item.planting_mushroom", "amount": 1, "pay": &"item.seaglass", "price": 1, "stock": 5},
	{"item": &"item.dirt_sack", "amount": 1, "pay": &"item.seaglass", "price": 1, "stock": 5},
	{"item": &"item.faux_ivory_brooch", "amount": 1, "pay": &"item.gemstone", "price": 1, "stock": 2},
	{"item": &"item.gnome_statue", "amount": 1, "pay": &"item.gemstone", "price": 2, "stock": 1},
]

const TITLE := "The Machine"
const LOCKED_NOTE := (
	"It is dark. The selections are unlabelled and the coin slot is the wrong"
	+ " shape for a coin. One narrow slot below it is older than the rest."
)
const UNLOCKED_NOTE := "Nothing is labelled. It still takes payment."

const C_CABINET := Color(0.11, 0.12, 0.1, 1)
const C_GLASS := Color(0.24, 0.3, 0.28, 0.55)
const C_BRASS := Color(0.62, 0.48, 0.2, 1)
const C_DARK := Color(0.05, 0.05, 0.05, 1)

var _unlocked := false
## Item id (as String) -> vends left in that slot.
var _remaining: Dictionary = {}
var _open := false
var _player: Node = null
var _opened_frame := -1

var _sign: Label3D
var _glow: OmniLight3D
var _glass: MeshInstance3D

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")

	_reset_stock()
	_build_visual()
	_build_ui()
	_apply_look()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	if _open:
		return ""
	return "Use the machine" if _unlocked else "Look at the machine"


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_panel(interactor)


func is_unlocked() -> bool:
	return _unlocked


func is_open() -> bool:
	return _open


## True when the machine has woken up and has stock in that slot.
func can_vend(index: int) -> bool:
	if not _unlocked or index < 0 or index >= OFFERS.size():
		return false
	return get_remaining(index) > 0


func get_remaining(index: int) -> int:
	if index < 0 or index >= OFFERS.size():
		return 0
	return int(_remaining.get(String(OFFERS[index]["item"]), 0))


## The slot list, so a test or a panel can read the machine without guessing.
func get_offers() -> Array[Dictionary]:
	return OFFERS.duplicate(true)


# --- the coin --------------------------------------------------------------


## Feeds the odd coin to the machine. Consumes it only on success, so a player
## who wanders up without the coin keeps nothing lost.
func unlock_with(interactor: Node) -> bool:
	if _unlocked:
		return true

	var inventory := _inventory(interactor)
	if inventory == null or not inventory.has_item(unlock_item):
		Events.notification_requested.emit("Nothing you carry fits that slot")
		return false

	if not inventory.remove_item(unlock_item, 1):
		return false

	_unlocked = true
	_apply_look()
	Events.notification_requested.emit("The machine wakes up")
	if _open:
		_refresh()
	return true


# --- vending ---------------------------------------------------------------


## Buys one item from `index`. Payment is taken only after the goods fit in the
## bag, so a full inventory never eats sea glass.
func buy(index: int, interactor: Node) -> bool:
	if index < 0 or index >= OFFERS.size():
		return false
	if not _unlocked:
		Events.notification_requested.emit("The machine is still asleep")
		return false
	if get_remaining(index) <= 0:
		Events.notification_requested.emit("That slot is empty")
		return false

	var offer: Dictionary = OFFERS[index]
	var data := ItemDatabase.get_item(offer["item"])
	var inventory := _inventory(interactor)
	if data == null or inventory == null:
		return false

	var pay := StringName(offer["pay"])
	var price := int(offer["price"])
	if inventory.get_amount(pay) < price:
		Events.notification_requested.emit(
			"It wants %d %s" % [price, _name_of(pay)]
		)
		return false

	if inventory.add_item(data, int(offer["amount"])) <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return false

	inventory.remove_item(pay, price)
	var key := String(offer["item"])
	_remaining[key] = get_remaining(index) - 1

	Events.notification_requested.emit("%s drops into the tray" % data.display_name)
	if _open:
		_refresh()
	return true


func _reset_stock() -> void:
	_remaining.clear()
	for offer in OFFERS:
		_remaining[String(offer["item"])] = int(offer["stock"])


# --- panel -----------------------------------------------------------------


func _open_panel(interactor: Node) -> void:
	_open = true
	_player = interactor
	# The same E press that opened the panel can still reach this node's
	# unhandled input. Ignore input for the rest of this frame.
	_opened_frame = Engine.get_process_frames()

	_status.text = UNLOCKED_NOTE if _unlocked else LOCKED_NOTE
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
	if event.is_action_pressed("interact"):
		close_panel()
		get_viewport().set_input_as_handled()


## Pausing (Escape) owns the screen; the machine must not stay open behind it.
func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_panel()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	if not _unlocked:
		_add_note(_list, "Selections: unlabelled.")
		var try_button := Button.new()
		try_button.text = "Try the odd coin"
		try_button.pressed.connect(_on_try_coin)
		_list.add_child(try_button)
		return

	var inventory := _inventory(_player)
	for index in OFFERS.size():
		var offer: Dictionary = OFFERS[index]
		var data := ItemDatabase.get_item(offer["item"])
		if data == null:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)

		var label := Label.new()
		label.text = "%d. %s" % [index + 1, data.display_name]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var price_label := Label.new()
		var pay := StringName(offer["pay"])
		var price := int(offer["price"])
		price_label.text = "%d %s" % [price, _name_of(pay)]
		price_label.custom_minimum_size = Vector2(150.0, 0.0)
		row.add_child(price_label)

		var left_label := Label.new()
		left_label.text = "left %d" % get_remaining(index)
		left_label.custom_minimum_size = Vector2(56.0, 0.0)
		row.add_child(left_label)

		var button := Button.new()
		button.text = "Vend"
		button.custom_minimum_size = Vector2(84.0, 0.0)
		var affordable := (
			inventory != null
			and inventory.get_amount(pay) >= price
			and get_remaining(index) > 0
		)
		button.disabled = not affordable
		button.pressed.connect(_on_vend.bind(index))
		row.add_child(button)


func _on_try_coin() -> void:
	if unlock_with(_player):
		_status.text = UNLOCKED_NOTE


func _on_vend(index: int) -> void:
	buy(index, _player)


# --- helpers ---------------------------------------------------------------


func _inventory(interactor: Node) -> InventoryComponent:
	if interactor == null or not interactor.has_method("get_inventory_component"):
		return null
	return interactor.call("get_inventory_component") as InventoryComponent


func _name_of(id: StringName) -> String:
	var data := ItemDatabase.get_item(id)
	return String(id) if data == null else data.display_name


func _add_note(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "MachineUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 380)
	centre.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = TITLE
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	var instructions := Label.new()
	instructions.text = "The coin slot is the wrong shape for coins."
	layout.add_child(instructions)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = LOCKED_NOTE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_panel)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false


# --- look ------------------------------------------------------------------
#
# The cabinet is built in code so the machine is one scene with no art
# dependency, like the memory stone. The sign and the glow both change when the
# coin goes in, which is the only feedback the player needs.


func _build_visual() -> void:
	var cabinet := _mat(C_CABINET, 0.85)
	var brass := _mat(C_BRASS, 0.45, 0.35)
	var dark := _mat(C_DARK, 0.95)

	_box("Body", Vector3(0, 1.05, 0), Vector3(1.25, 2.1, 0.72), cabinet)
	_box("Plinth", Vector3(0, 0.07, 0), Vector3(1.35, 0.14, 0.82), dark)
	_box("Crown", Vector3(0, 2.16, 0), Vector3(1.32, 0.12, 0.8), cabinet)

	_glass = _box("Glass", Vector3(0, 1.4, 0.37), Vector3(0.95, 1.32, 0.03), _mat(C_GLASS, 0.15))
	(_glass.material_override as StandardMaterial3D).transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)

	# Six unlabelled slots, two columns by three rows.
	var slot := _mat(Color(0.19, 0.19, 0.17, 1), 0.9)
	for column in 2:
		for row in 3:
			_box(
				"Slot%d%d" % [column, row],
				Vector3(-0.23 + column * 0.46, 0.95 + row * 0.42, 0.385),
				Vector3(0.34, 0.3, 0.03),
				slot
			)

	# Coin plate and the narrow older slot beneath it.
	_box("CoinPlate", Vector3(0.42, 1.06, 0.37), Vector3(0.22, 0.34, 0.03), brass)
	_box("CoinSlot", Vector3(0.42, 1.13, 0.385), Vector3(0.13, 0.02, 0.02), dark)
	_box("OldSlot", Vector3(0.42, 0.84, 0.385), Vector3(0.14, 0.03, 0.02), brass)

	# Tray at the bottom of the cabinet.
	_box("Tray", Vector3(0, 0.52, 0.4), Vector3(0.58, 0.2, 0.18), dark)
	_box("TrayLip", Vector3(0, 0.63, 0.47), Vector3(0.62, 0.04, 0.04), brass)

	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "???"
	_sign.font_size = 48
	_sign.pixel_size = 0.0034
	_sign.outline_size = 14
	_sign.modulate = Color(0.9, 0.86, 0.72, 1)
	_sign.outline_modulate = Color(0.06, 0.06, 0.05, 0.9)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0, 2.34, 0.12)
	add_child(_sign)

	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = Color(1, 0.78, 0.42, 1)
	_glow.light_energy = 0.0
	_glow.omni_range = 4.2
	_glow.position = Vector3(0, 1.3, 0.9)
	add_child(_glow)


## Applies the awake look. Called after the visual exists and again on load.
func _apply_look() -> void:
	if _sign != null:
		_sign.text = "ODDMENTS" if _unlocked else "???"
	if _glow != null:
		_glow.light_energy = 1.1 if _unlocked else 0.0
	if _glass != null and _glass.material_override is StandardMaterial3D:
		var glass := _glass.material_override as StandardMaterial3D
		glass.albedo_color = Color(0.36, 0.42, 0.34, 0.5) if _unlocked else C_GLASS


func _box(node_name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	add_child(instance)
	return instance


func _mat(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"unlocked": _unlocked, "remaining": _remaining.duplicate()}


func load_data(data: Dictionary) -> void:
	_unlocked = bool(data.get("unlocked", false))
	_reset_stock()

	var saved: Variant = data.get("remaining", {})
	if saved is Dictionary:
		for raw_key: Variant in (saved as Dictionary).keys():
			var key := String(raw_key)
			if _remaining.has(key):
				_remaining[key] = clampi(int((saved as Dictionary)[raw_key]), 0, 99)

	_apply_look()
	if _open:
		_refresh()
