class_name CraftingStation
extends StaticBody3D
## A small workbench where the player turns foraged goods into crafted items.
##
## Recipes come from `RecipeDatabase`, so adding a `.tres` and one line in the
## database is enough to offer a new item. The station never owns inventory:
## ingredients are removed from and the result added to the player's
## `InventoryComponent`, exactly like the chest and the cart.
##
## The panel is built in code after the pattern of `cart_storage.gd`: it blocks
## the player while open, closes on E or Escape, and restores the mouse.

## Stable id for the save file. Leave empty for a station that should not persist.
@export var save_id: StringName = &""
## Recipes offered here, in draw order.
@export var recipe_ids: Array[StringName] = [
	&"recipe.sporebread",
	&"recipe.hearth_silk_thread",
	&"recipe.memory_honey",
	&"recipe.axe",
	&"recipe.pickaxe",
	&"recipe.iron_sword",
]
## Panel heading. A forge, a loom, or a kitchen can share one station scene and
## still name itself correctly.
@export var title: String = "Hearthside Crafting"
@export_multiline var instructions: String = "Turn foraged things into something useful."
## Prompt shown by the interaction ray. The forge names itself.
@export var interaction_text: String = "Use crafting bench"
## What kind of bench this is dressed as: `market`, `forge` or `loom`. The top
## stays the same so a player recognises a workbench anywhere; the tools and the
## clutter change, so three benches do not read as three copies.
@export var station_kind: StringName = &"market"

const TITLE := "Hearthside Crafting"
const INSTRUCTIONS := "Turn foraged things into something useful."

var _open := false
var _player: Node = null
var _opened_frame := -1

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	_build_visual()
	_build_ui()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	return "" if _open else interaction_text


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_station(interactor)


func _open_station(interactor: Node) -> void:
	_open = true
	_player = interactor
	# The E press that opened the panel can still reach this node this frame.
	_opened_frame = Engine.get_process_frames()

	_status.text = instructions
	_panel.visible = true
	_layer.visible = true
	_refresh()

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_station() -> void:
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
		close_station()
		get_viewport().set_input_as_handled()


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_station()


# --- crafting --------------------------------------------------------------


func _craft(recipe: RecipeData) -> void:
	var inventory := _inventory()
	if inventory == null or recipe == null:
		return

	# Check the whole recipe before removing anything, so a failed craft never
	# eats part of the player's supplies.
	for i in recipe.ingredient_ids.size():
		var need: int = recipe.ingredient_amounts[i]
		var tag := recipe.tag_for(i)
		if tag.is_empty():
			var id: StringName = recipe.ingredient_ids[i]
			if inventory.get_amount(id) < need:
				_status.text = "You need %d %s." % [need, _item_name(id)]
				return
		elif inventory.get_amount_with_tag(tag) < need:
			_status.text = "You need %d any %s." % [need, String(tag).capitalize()]
			return

	var output := ItemDatabase.get_item(recipe.output_id)
	if output == null:
		push_warning("Recipe %s has unknown output %s" % [recipe.id, recipe.output_id])
		return
	if inventory.add_item(output, recipe.output_amount) <= 0:
		_status.text = "Your inventory is full."
		return

	for i in recipe.ingredient_ids.size():
		var tag := recipe.tag_for(i)
		if tag.is_empty():
			inventory.remove_item(recipe.ingredient_ids[i], recipe.ingredient_amounts[i])
		else:
			inventory.remove_by_tag(tag, recipe.ingredient_amounts[i])

	_status.text = "Crafted %d %s." % [recipe.output_amount, output.display_name]
	Events.notification_requested.emit("%s crafted" % output.display_name)
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	for id in recipe_ids:
		var recipe := RecipeDatabase.get_recipe(id)
		if recipe == null:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)

		var label := Label.new()
		label.text = "%s  (%s)" % [recipe.display_name, recipe.ingredient_summary()]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)

		var button := Button.new()
		button.text = "Craft"
		button.pressed.connect(_craft.bind(recipe))
		row.add_child(button)


# --- helpers ---------------------------------------------------------------


func _inventory() -> InventoryComponent:
	if _player == null or not _player.has_method("get_inventory_component"):
		return null
	return _player.call("get_inventory_component") as InventoryComponent


func _item_name(id: StringName) -> String:
	var data := ItemDatabase.get_item(id)
	return String(id) if data == null else data.display_name


# --- look ------------------------------------------------------------------
# The scene ships a plain box so it always has something to stand on. The bench
# is dressed in code beside it, and the box is hidden, so every station (market,
# forge, loom) gets the same readable workbench without an art import.


func _build_visual() -> void:
	if get_node_or_null("Bench") != null:
		return

	var plain := get_node_or_null("Mesh") as MeshInstance3D
	if plain != null:
		plain.visible = false

	var timber := _mat(Color(0.46, 0.33, 0.2, 1), 0.88)
	var pale := _mat(Color(0.58, 0.44, 0.28, 1), 0.9)
	var dark := _mat(Color(0.25, 0.17, 0.11, 1), 0.95)
	var iron := _mat(Color(0.34, 0.35, 0.36, 1), 0.5, 0.15)
	var steel := _mat(Color(0.62, 0.64, 0.66, 1), 0.32, 0.1)
	var cloth := _mat(Color(0.62, 0.53, 0.4, 1), 0.95)
	var leaf := _mat(Color(0.34, 0.48, 0.28, 1), 0.9)
	var brass := _mat(Color(0.66, 0.5, 0.22, 1), 0.45, 0.1)
	var ember := _mat(Color(1.0, 0.72, 0.34, 1), 0.6, 2.4)

	var holder := Node3D.new()
	holder.name = "Bench"
	add_child(holder)

	# Three planks with visible gaps instead of one slab.
	for i in 3:
		_box(
			holder,
			"TopPlank",
			Vector3(0, 0.93, -0.31 + i * 0.31),
			Vector3(1.96, 0.1, 0.27),
			timber if i != 1 else pale
		)
	# End caps and a back apron.
	for sx in [-1.0, 1.0]:
		_box(holder, "EndCap", Vector3(sx * 0.97, 0.87, 0), Vector3(0.08, 0.2, 1.0), dark)
	_box(holder, "Apron", Vector3(0, 0.83, -0.46), Vector3(1.82, 0.12, 0.06), pale)

	# Splayed legs and stretchers.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_placed_box(
				holder,
				"Leg",
				Vector3(sx * 0.79, 0.44, sz * 0.36),
				Vector3(0.11, 0.9, 0.11),
				dark,
				Vector3(0, 0, sx * 4.0)
			)
	for sz in [-1.0, 1.0]:
		_box(holder, "Stretcher", Vector3(0, 0.3, sz * 0.35), Vector3(1.5, 0.07, 0.07), dark)
	for sx in [-1.0, 1.0]:
		_box(holder, "StretcherSide", Vector3(sx * 0.75, 0.3, 0), Vector3(0.07, 0.07, 0.7), dark)
	_box(holder, "Shelf", Vector3(0, 0.36, 0), Vector3(1.62, 0.06, 0.68), pale)

	# The frame is shared, so a player recognises a workbench anywhere. Only the
	# working clutter changes with `station_kind`.
	_dress(holder, {
		"timber": timber,
		"pale": pale,
		"dark": dark,
		"iron": iron,
		"steel": steel,
		"cloth": cloth,
		"leaf": leaf,
		"brass": brass,
		"ember": ember,
	})


func _dress(holder: Node3D, mats: Dictionary) -> void:
	match station_kind:
		&"forge":
			_dress_forge(holder, mats)
		&"loom":
			_dress_loom(holder, mats)
		_:
			_dress_market(holder, mats)


## The market bench: a general bench for bread, thread, honey and the odd tool.
func _dress_market(holder: Node3D, mats: Dictionary) -> void:
	var timber: Material = mats["timber"]
	var pale: Material = mats["pale"]
	var dark: Material = mats["dark"]
	var iron: Material = mats["iron"]
	var steel: Material = mats["steel"]
	var cloth: Material = mats["cloth"]
	var leaf: Material = mats["leaf"]
	var brass: Material = mats["brass"]

	# Stock: a basket, a crate, and a tied bundle.
	_box(holder, "Basket", Vector3(-0.48, 0.54, 0.1), Vector3(0.42, 0.3, 0.34), cloth)
	_box(holder, "Crate", Vector3(0.52, 0.52, 0.04), Vector3(0.44, 0.26, 0.36), timber)
	_box(holder, "Bundle", Vector3(0.02, 0.46, 0.12), Vector3(0.3, 0.16, 0.24), dark)

	# Vice: body, jaws, screw, and the handle that sticks out.
	_box(holder, "Vice", Vector3(0.7, 1.02, 0.31), Vector3(0.26, 0.15, 0.22), iron)
	_box(holder, "ViceJaw", Vector3(0.7, 1.11, 0.2), Vector3(0.26, 0.07, 0.06), steel)
	_cyl(holder, "ViceScrew", Vector3(0.7, 1.02, 0.45), 0.035, 0.3, steel, Vector3(90, 0, 0))
	_box(holder, "ViceHandle", Vector3(0.7, 1.02, 0.58), Vector3(0.42, 0.035, 0.035), iron)

	# Tool rail and hanging tools.
	_box(holder, "Rail", Vector3(0, 1.58, -0.36), Vector3(1.6, 0.07, 0.07), dark)
	for sx in [-1.0, 1.0]:
		_box(holder, "RailPost", Vector3(sx * 0.76, 1.34, -0.36), Vector3(0.06, 0.5, 0.06), dark)
	for i in 3:
		var x := -0.45 + i * 0.45
		_box(holder, "ToolHandle", Vector3(x, 1.34, -0.34), Vector3(0.055, 0.36, 0.055), timber)
		_box(holder, "ToolHead", Vector3(x, 1.14, -0.34), Vector3(0.14, 0.09, 0.07), steel)
	# A saw leans at the far end.
	_placed_box(
		holder, "Saw", Vector3(0.86, 1.24, -0.3), Vector3(0.03, 0.5, 0.22), steel, Vector3(0, 0, 12)
	)
	_box(holder, "SawHandle", Vector3(0.83, 1.0, -0.3), Vector3(0.07, 0.16, 0.1), timber)

	# A small lantern with a warm core. The only light on the bench, so it reads
	# as a working corner at dusk.
	_bench_lamp(holder, Vector3(-0.78, 1.03, 0.28), mats)

	# A stool tucked under the near end.
	_cyl(holder, "StoolSeat", Vector3(-0.62, 0.45, 0.72), 0.19, 0.05, pale, Vector3.ZERO)
	for i in 3:
		var a := i / 3.0 * TAU
		_cyl(
			holder,
			"StoolLeg",
			Vector3(-0.62 + cos(a) * 0.11, 0.22, 0.72 + sin(a) * 0.11),
			0.025,
			0.44,
			dark,
			Vector3.ZERO
		)

	# Foraged things waiting to be used, so the bench looks worked-in.
	for i in 3:
		var sprig := MeshInstance3D.new()
		sprig.name = "Sprig"
		var mesh := SphereMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.12
		sprig.mesh = mesh
		sprig.material_override = leaf
		sprig.position = Vector3(-0.14 + i * 0.13, 1.03, -0.18)
		holder.add_child(sprig)
	# Shavings on the floor.
	for i in 6:
		_placed_box(
			holder,
			"Shaving",
			Vector3(-0.4 + i * 0.17, 0.03, 0.55 + sin(i * 1.7) * 0.12),
			Vector3(0.14, 0.015, 0.04),
			pale,
			Vector3(0, i * 37.0, 0)
		)
	# A brass plaque, so the bench feels owned.
	_box(holder, "Plaque", Vector3(0, 0.79, 0.48), Vector3(0.26, 0.07, 0.015), brass)


## The forge: an anvil, tongs in the vice, a quench bucket, and coal.
## Deliberately darker and heavier than the market bench.
func _dress_forge(holder: Node3D, mats: Dictionary) -> void:
	var timber: Material = mats["timber"]
	var dark: Material = mats["dark"]
	var iron: Material = mats["iron"]
	var steel: Material = mats["steel"]
	var ember: Material = mats["ember"]
	var coal := _mat(Color(0.13, 0.12, 0.12, 1), 0.95)

	# Anvil: a squat body, a horn, and a bright worked top.
	_box(holder, "AnvilBody", Vector3(-0.42, 1.12, -0.06), Vector3(0.34, 0.28, 0.3), iron)
	_box(holder, "AnvilFace", Vector3(-0.42, 1.29, -0.06), Vector3(0.4, 0.06, 0.34), steel)
	_cyl(holder, "AnvilHorn", Vector3(-0.66, 1.2, -0.06), 0.07, 0.24, steel, Vector3(0, 0, 90))
	_box(holder, "AnvilFoot", Vector3(-0.42, 0.98, -0.06), Vector3(0.42, 0.06, 0.36), dark)

	# A hammer resting across the anvil, and tongs in the vice.
	_placed_box(
		holder, "HammerHandle", Vector3(-0.3, 1.34, 0.06), Vector3(0.4, 0.035, 0.035), timber, Vector3(0, 22, 0)
	)
	_box(holder, "HammerHead", Vector3(-0.09, 1.34, 0.14), Vector3(0.1, 0.09, 0.09), steel)
	_box(holder, "Vice", Vector3(0.7, 1.02, 0.31), Vector3(0.26, 0.15, 0.22), iron)
	_placed_box(
		holder, "Tongs", Vector3(0.62, 1.16, 0.22), Vector3(0.34, 0.03, 0.05), iron, Vector3(0, 0, 14)
	)

	# A quench barrel on the floor, cold and dripping.
	_cyl(holder, "QuenchBarrel", Vector3(0.74, 0.32, 0.76), 0.19, 0.6, timber, Vector3.ZERO)
	_cyl(holder, "QuenchWater", Vector3(0.74, 0.61, 0.76), 0.16, 0.03, coal, Vector3.ZERO)

	# Coal heap beside the barrel, and a bucket of it.
	_box(holder, "CoalHeap", Vector3(-0.88, 0.1, 0.62), Vector3(0.34, 0.18, 0.3), coal)
	_box(holder, "CoalBucket", Vector3(0.28, 0.14, 0.78), Vector3(0.22, 0.28, 0.22), iron)

	# The forge fire itself, low and red, so the bench reads warm at night.
	_box(holder, "ForgeBed", Vector3(0.28, 1.0, -0.24), Vector3(0.3, 0.1, 0.26), coal)
	_box(holder, "ForgeEmbers", Vector3(0.28, 1.06, -0.24), Vector3(0.22, 0.05, 0.18), ember)
	_bench_lamp(holder, Vector3(0.28, 1.14, -0.24), mats, Color(1.0, 0.5, 0.24, 1), 0.75, 3.6)


## The loom tower: warp threads, spools, folded cloth, and scissors.
func _dress_loom(holder: Node3D, mats: Dictionary) -> void:
	var timber: Material = mats["timber"]
	var pale: Material = mats["pale"]
	var dark: Material = mats["dark"]
	var steel: Material = mats["steel"]
	var cloth: Material = mats["cloth"]

	# An upright frame standing on the bench, with warp threads strung down it.
	for sx in [-1.0, 1.0]:
		_box(holder, "LoomPost", Vector3(sx * 0.55, 1.38, -0.3), Vector3(0.07, 0.9, 0.07), dark)
	_box(holder, "LoomBeam", Vector3(0, 1.8, -0.3), Vector3(1.2, 0.08, 0.09), timber)
	_box(holder, "LoomHeddle", Vector3(0, 1.34, -0.3), Vector3(1.06, 0.05, 0.06), pale)
	for i in 9:
		_cyl(
			holder,
			"Warp",
			Vector3(-0.44 + i * 0.11, 1.56, -0.3),
			0.008,
			0.46,
			cloth,
			Vector3.ZERO
		)
	# The half-woven cloth hanging off the beam.
	_box(holder, "Cloth", Vector3(0, 1.2, -0.24), Vector3(1.0, 0.34, 0.03), cloth)

	# Spools on the shelf, each a different thread.
	for i in 4:
		_cyl(
			holder,
			"Spool",
			Vector3(-0.6 + i * 0.34, 0.47, 0.1),
			0.06,
			0.16,
			cloth if i % 2 == 0 else pale,
			Vector3.ZERO
		)

	# A folded bolt of finished cloth and a pair of scissors.
	_box(holder, "Bolt", Vector3(0.56, 1.02, 0.22), Vector3(0.3, 0.12, 0.24), cloth)
	_placed_box(
		holder, "ScissorBlade", Vector3(0.18, 1.01, 0.3), Vector3(0.2, 0.015, 0.03), steel, Vector3(0, 24, 0)
	)
	_placed_box(
		holder, "ScissorBlade", Vector3(0.18, 1.01, 0.3), Vector3(0.2, 0.015, 0.03), steel, Vector3(0, -24, 0)
	)
	_cyl(holder, "ScissorRing", Vector3(0.06, 1.01, 0.3), 0.025, 0.01, steel, Vector3(90, 0, 0))

	# One small lamp, cooler than the market's, because cloth and flame disagree.
	_bench_lamp(holder, Vector3(-0.8, 1.03, 0.3), mats, Color(1.0, 0.86, 0.62, 1), 0.4, 2.8)


## The little lantern every bench carries. Colour and strength vary by bench so
## the three kinds of work are distinguishable at dusk.
func _bench_lamp(
	holder: Node3D,
	at: Vector3,
	mats: Dictionary,
	color: Color = Color(1.0, 0.76, 0.42, 1),
	energy: float = 0.55,
	reach: float = 3.2
) -> void:
	var iron: Material = mats["iron"]
	var ember: Material = mats["ember"]
	_box(holder, "LanternBase", at, Vector3(0.14, 0.05, 0.14), iron)
	_box(holder, "LanternCore", at + Vector3(0, 0.09, 0), Vector3(0.1, 0.14, 0.1), ember)
	_box(holder, "LanternCap", at + Vector3(0, 0.19, 0), Vector3(0.16, 0.04, 0.16), iron)
	var lamp := OmniLight3D.new()
	lamp.name = "BenchLight"
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.position = at + Vector3(0, 0.15, 0)
	holder.add_child(lamp)


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


## A box that is also turned, for splayed legs, a leaning saw, or floor shavings.
func _placed_box(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	size: Vector3,
	mat: Material,
	rotation_degrees: Vector3
) -> MeshInstance3D:
	var instance := _box(parent, node_name, at, size, mat)
	instance.rotation_degrees = rotation_degrees
	return instance


## A cylinder for handles, stool parts, and the vice screw.
func _cyl(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	radius: float,
	height: float,
	mat: Material,
	rotation_degrees: Vector3
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	instance.rotation_degrees = rotation_degrees
	parent.add_child(instance)
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


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CraftingUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 260)
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
	heading.text = title
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	var instructions_label := Label.new()
	instructions_label.text = instructions
	layout.add_child(instructions_label)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = instructions
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_station)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false