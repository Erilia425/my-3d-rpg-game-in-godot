class_name ToolBelt
extends HBoxContainer
## Three HUD slots showing what the player is carrying in hand: the weapon, the
## gathering tool, and the body armour.
##
## The inventory and vitals were text-only, which made "do I still have my axe?"
## a memory test. This is a display component: it reads
## `EquipmentComponent` and never equips anything. Slots are built in code so
## the scene stays one node and the three looks cannot drift apart.

## Order matches `_slots`: weapon, tool, armour.
const SLOT_TITLES: Array[String] = ["Weapon", "Tool", "Armour"]

var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _captions: Array[Label] = []
var _equipment: EquipmentComponent


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	_build_slots()
	_bind()


func _bind() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_equipment_component"):
		# The HUD can be readied before the player joins the group; try once
		# more after the scene has finished entering the tree.
		call_deferred("_bind")
		return

	_equipment = player.call("get_equipment_component") as EquipmentComponent
	if _equipment == null:
		return

	_equipment.equipment_changed.connect(_refresh)
	_refresh()


func _build_slots() -> void:
	for i in SLOT_TITLES.size():
		var panel := PanelContainer.new()
		panel.name = "%sSlot" % SLOT_TITLES[i]
		panel.custom_minimum_size = Vector2(64.0, 64.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _slot_style())
		add_child(panel)
		_slots.append(panel)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		_icons.append(icon)

		var caption := Label.new()
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color(0.82, 0.78, 0.68, 1))
		caption.text = SLOT_TITLES[i]
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(caption)
		_captions.append(caption)


## Refreshes all three slots from the equipment component. Called on `_ready`
## and on every `equipment_changed`, never per frame.
func _refresh() -> void:
	if _equipment == null:
		return
	_set_slot(
		0,
		_equipment.get_weapon(),
		"Unarmed"
	)
	_set_slot(
		1,
		_equipment.get_equipped(ItemData.EquipSlot.TOOL),
		"None"
	)
	_set_slot(
		2,
		_equipment.get_body_armor(),
		"None"
	)


func _set_slot(index: int, data: ItemData, empty_caption: String) -> void:
	if index < 0 or index >= _slots.size():
		return

	var icon := _icons[index]
	var caption := _captions[index]
	var filled := data != null

	icon.texture = data.icon if filled else null
	icon.modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.0)
	caption.text = data.display_name if filled else empty_caption
	caption.add_theme_color_override(
		"font_color",
		Color(0.86, 0.82, 0.7, 1) if filled else Color(0.62, 0.63, 0.6, 1)
	)
	_slots[index].tooltip_text = (
		"%s: %s" % [SLOT_TITLES[index], data.display_name] if filled
		else "%s: %s" % [SLOT_TITLES[index], empty_caption]
	)


func _slot_style() -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.bg_color = Color(0.04, 0.045, 0.05, 0.82)
	made.border_color = Color(0.42, 0.36, 0.24, 0.85)
	made.set_border_width_all(1)
	made.set_corner_radius_all(5)
	made.content_margin_left = 4.0
	made.content_margin_right = 4.0
	made.content_margin_top = 4.0
	made.content_margin_bottom = 2.0
	return made
