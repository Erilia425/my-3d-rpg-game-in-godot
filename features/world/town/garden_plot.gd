class_name GardenPlot
extends StaticBody3D
## A raised garden bed in the communal garden.
##
## Everything the market machine sells that had no purpose now has one here:
##
## - **Mushroom to Plant** and a **Tiny Sack of Dirt** go into the soil and come
##   back as a small crop of mushrooms after two days.
## - **Moss-Covered Rock** and a **Gnome Statue** stay where they are put, and the
##   bed remembers them.
##
## The plot owns only its own state (what is planted, what is placed). The goods
## and the harvest live in the player's `InventoryComponent`; the day comes from
## `WorldClock`. See AGENTS.md 4.6 and 6.3.

## Stable id for the save file. Leave empty for a bed that should not persist.
@export var save_id: StringName = &"garden.communal_plot"
## In-game days a planting takes to be ready.
@export var grow_days: int = 2

const TITLE := "The Communal Garden"
const NOTE := (
	"The bed is turned and waiting. Anything the machine sells can be put in"
	+ " the ground here, and the ground will keep it."
)

## Item ids this bed understands.
const SEED := &"item.planting_mushroom"
const SOIL := &"item.dirt_sack"
const MOSS := &"item.moss_rock"
const GNOME := &"item.gnome_statue"

var _open := false
var _player: Node = null
var _opened_frame := -1

## -1 means empty. Otherwise the day the planting went in.
var _planted_day := -1
var _moss_placed := 0
var _gnomes_placed := 0
var _harvests := 0

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label
var _sign: Label3D
var _crop: MeshInstance3D


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")
	_build_visual()
	_build_ui()
	_refresh_sign()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	return "" if _open else "Tend the garden bed"


func is_open() -> bool:
	return _open


# --- state queries ---------------------------------------------------------


func is_planted() -> bool:
	return _planted_day >= 0


func is_ready() -> bool:
	return is_planted() and WorldClock.get_day() >= _planted_day + grow_days


func get_moss_placed() -> int:
	return _moss_placed


func get_gnomes_placed() -> int:
	return _gnomes_placed


func get_harvests() -> int:
	return _harvests


# --- actions ---------------------------------------------------------------


## Plants a mushroom in a sack of soil. Both are consumed at once, so a failed
## planting never eats one of them.
func plant(interactor: Node) -> bool:
	var inventory := _inventory(interactor)
	if inventory == null:
		return false
	if is_planted():
		_status.text = "Something is already growing."
		return false
	if inventory.get_amount(SEED) < 1 or inventory.get_amount(SOIL) < 1:
		_status.text = "You need a mushroom to plant and a sack of dirt."
		return false

	inventory.remove_item(SEED, 1)
	inventory.remove_item(SOIL, 1)
	_planted_day = WorldClock.get_day()
	_status.text = "Planted. Give it %d days." % grow_days
	Events.notification_requested.emit("Planted in the garden")
	_refresh_sign()
	_refresh()
	return true


## Harvests a grown crop. Yields mushrooms and a fresh planting mushroom.
func harvest(interactor: Node) -> bool:
	var inventory := _inventory(interactor)
	if inventory == null:
		return false
	if not is_ready():
		_status.text = "Nothing is ready yet."
		return false

	var mushroom := ItemDatabase.get_item(&"item.mushroom")
	var seed := ItemDatabase.get_item(SEED)
	if mushroom == null:
		return false

	if inventory.add_item(mushroom, 3) <= 0:
		_status.text = "Your bag is full."
		return false
	if seed != null:
		inventory.add_item(seed, 1)

	_planted_day = -1
	_harvests += 1
	_status.text = "Three mushrooms and one left for next time."
	Events.notification_requested.emit("Harvested the garden bed")
	_refresh_sign()
	_refresh()
	return true


## Places one decorative item in the bed. Returns true when it was consumed.
func place(index: int, interactor: Node) -> bool:
	var inventory := _inventory(interactor)
	if inventory == null:
		return false

	var item: StringName = MOSS if index == 0 else GNOME
	if inventory.get_amount(item) < 1:
		_status.text = "You have none to place."
		return false
	if not inventory.remove_item(item, 1):
		return false

	if index == 0:
		_moss_placed += 1
		_status.text = "The moss settles into the soil."
	else:
		_gnomes_placed += 1
		_status.text = "The gnome keeps its own counsel."
		DiscoveryLog.unlock(&"discovery.garden_gnome")

	_build_placed()
	_refresh_sign()
	_refresh()
	return true


# --- panel -----------------------------------------------------------------


func _open_panel(interactor: Node) -> void:
	_open = true
	_player = interactor
	_opened_frame = Engine.get_process_frames()
	_status.text = NOTE
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


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_panel(interactor)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_panel()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var inventory := _inventory(_player)
	var mushroom := 0 if inventory == null else inventory.get_amount(SEED)
	var soil := 0 if inventory == null else inventory.get_amount(SOIL)

	if is_planted():
		var ready := "ready to harvest" if is_ready() else (
			"growing (%d/%d days)" % [
				WorldClock.get_day() - _planted_day, grow_days
			]
		)
		_add_row(
			"Planted bed — %s" % ready,
			"Harvest" if is_ready() else "",
			_on_harvest if is_ready() else Callable()
		)
	else:
		_add_row(
			"Empty bed (you have %d mushroom to plant, %d dirt)" % [mushroom, soil],
			"Plant",
			_on_plant,
			mushroom < 1 or soil < 1
		)

	_add_row(
		"Moss-covered rocks placed: %d" % _moss_placed,
		"Place rock",
		_on_place_moss,
		inventory == null or inventory.get_amount(MOSS) < 1
	)
	_add_row(
		"Gnome statues placed: %d" % _gnomes_placed,
		"Place gnome",
		_on_place_gnome,
		inventory == null or inventory.get_amount(GNOME) < 1
	)


func _add_row(text: String, button_text: String, action: Callable, disabled := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	if button_text.is_empty():
		return
	var button := Button.new()
	button.text = button_text
	button.disabled = disabled
	button.pressed.connect(action)
	row.add_child(button)


func _on_plant() -> void:
	plant(_player)


func _on_harvest() -> void:
	harvest(_player)


func _on_place_moss() -> void:
	place(0, _player)


func _on_place_gnome() -> void:
	place(1, _player)


# --- helpers ---------------------------------------------------------------


func _inventory(interactor: Node) -> InventoryComponent:
	if interactor == null or not interactor.has_method("get_inventory_component"):
		return null
	return interactor.call("get_inventory_component") as InventoryComponent


func _refresh_sign() -> void:
	if _sign == null:
		return
	if is_ready():
		_sign.text = "Ready"
	elif is_planted():
		_sign.text = "Growing"
	else:
		_sign.text = "Garden"
	if _crop != null:
		_crop.visible = is_planted()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "GardenUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 320)
	centre.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = TITLE
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = NOTE
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_panel)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false


# --- look ------------------------------------------------------------------


func _build_visual() -> void:
	if get_node_or_null("Soil") != null:
		return

	var soil := _mat(Color(0.3, 0.22, 0.15, 1), 0.95)
	var timber := _mat(Color(0.42, 0.31, 0.19, 1), 0.9)
	var leaf := _mat(Color(0.35, 0.5, 0.28, 1), 0.85)

	_box("Soil", Vector3(0, 0.12, 0), Vector3(2.6, 0.24, 1.6), soil)
	for side in [-1.0, 1.0]:
		_box("Side", Vector3(side * 1.36, 0.24, 0), Vector3(0.12, 0.48, 1.8), timber)
		_box("End", Vector3(0, 0.24, side * 0.86), Vector3(2.85, 0.48, 0.12), timber)

	# A small crop clump, hidden until something is planted.
	_crop = _box("Crop", Vector3(0, 0.42, 0), Vector3(0.5, 0.34, 0.5), leaf)
	_crop.visible = false

	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "Garden"
	_sign.font_size = 40
	_sign.pixel_size = 0.0032
	_sign.outline_size = 10
	_sign.modulate = Color(0.95, 0.9, 0.76, 1)
	_sign.outline_modulate = Color(0.1, 0.09, 0.07, 1)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0, 1.15, 0)
	add_child(_sign)


## Rebuilds the little placed decorations. Cheap: at most a handful of boxes,
## and only when the player actually places something.
func _build_placed() -> void:
	var holder := get_node_or_null("Placed") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Placed"
		add_child(holder)
	for child in holder.get_children():
		child.queue_free()

	var moss := _mat(Color(0.42, 0.52, 0.34, 1), 0.9)
	var stone := _mat(Color(0.56, 0.55, 0.5, 1), 0.95)
	var gnome := _mat(Color(0.62, 0.66, 0.72, 1), 0.8)
	var cap := _mat(Color(0.72, 0.28, 0.24, 1), 0.8)

	for i in _moss_placed:
		var rock := MeshInstance3D.new()
		rock.name = "Moss"
		var mesh := SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.28
		rock.mesh = mesh
		rock.material_override = moss
		rock.position = Vector3(-1.0 + i * 0.32, 0.3, -0.35 + (i % 2) * 0.2)
		holder.add_child(rock)

	for i in _gnomes_placed:
		var body := MeshInstance3D.new()
		body.name = "Gnome"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.2, 0.34, 0.2)
		body.mesh = mesh
		body.material_override = gnome
		body.position = Vector3(0.7 + i * 0.4, 0.42, 0.34)
		holder.add_child(body)

		var hat := MeshInstance3D.new()
		hat.name = "Hat"
		var hat_mesh := BoxMesh.new()
		hat_mesh.size = Vector3(0.24, 0.16, 0.24)
		hat.mesh = hat_mesh
		hat.material_override = cap
		hat.position = body.position + Vector3(0, 0.25, 0)
		holder.add_child(hat)

	# The stones at the bed's edge keep the placement from floating.
	if _moss_placed > 0:
		var edging := MeshInstance3D.new()
		edging.name = "Edging"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 0.12, 1.4)
		edging.mesh = mesh
		edging.material_override = stone
		edging.position = Vector3(-1.1, 0.2, 0)
		holder.add_child(edging)


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


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {
		"planted_day": _planted_day,
		"moss": _moss_placed,
		"gnomes": _gnomes_placed,
		"harvests": _harvests,
	}


func load_data(data: Dictionary) -> void:
	_planted_day = int(data.get("planted_day", -1))
	_moss_placed = maxi(int(data.get("moss", 0)), 0)
	_gnomes_placed = maxi(int(data.get("gnomes", 0)), 0)
	_harvests = maxi(int(data.get("harvests", 0)), 0)
	_build_placed()
	_refresh_sign()
	if _open:
		_refresh()
