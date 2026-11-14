class_name MemoryStone
extends StaticBody3D
## A standing stone that keeps someone's memory.
##
## Walking up and pressing **E** asks the player's `SpellCaster` to cast Recall
## on it, so the stone and the R key share one cost and one rule. The stone can
## be recalled again later: the memory is a place, not loot.
##
## The visual is built in code so a stone is data (a title and a paragraph), not
## a new mesh or texture for every roadside memory. See AGENTS.md 4.5.

## Heading shown by the dialogue window.
@export var memory_title: String = "A Memory in Stone"
## The remembered text. One page; keep it a scene, not a lore dump.
@export_multiline var memory_text: String = (
	"Someone stood here long enough for the stone to keep them."
)
## Optional one-time payment for finding this stone. Leave everything empty for
## a stone that only holds a memory.
@export var reward_item: StringName = &""
@export var reward_amount: int = 1
@export var reward_silk: float = 0.0
@export var reward_anchoring: int = 0
## Stable flag id for the one-time payment.
@export var reward_flag: StringName = &""
## Stable id for the save file. Leave empty for a stone that never persists
## anything beyond the flag above.
@export var save_id: StringName = &""

var _built := false
var _paid := false


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"memory")
	_build_visual()
	_paid = not reward_flag.is_empty() and QuestLog.has_flag(reward_flag)


func get_interaction_text() -> String:
	return "Recall this memory"


func get_memory_title() -> String:
	return memory_title


func get_memory_text() -> String:
	return memory_text


func interact(interactor: Node) -> void:
	var caster := _caster_for(interactor)
	if caster == null:
		Events.notification_requested.emit(
			"The stone waits for someone who can hold a memory."
		)
		return

	if caster.try_recall(self):
		_grant_reward(interactor)


## Pays the stone's one-time reward. Placed after the recall so a stone that a
## player cannot yet afford still keeps its memory for later.
func _grant_reward(interactor: Node) -> void:
	if _paid or reward_flag.is_empty():
		return

	var granted := PackedStringArray()
	var inventory := _inventory(interactor)
	if reward_item != &"" and inventory != null:
		var data := ItemDatabase.get_item(reward_item)
		if data != null and inventory.add_item(data, reward_amount) > 0:
			granted.append("%d %s" % [reward_amount, data.display_name])

	var stats := _stats(interactor)
	if stats != null and reward_silk > 0.0:
		var repaired: float = stats.repair_silk(reward_silk)
		if repaired > 0.0:
			granted.append("%d silk" % roundi(repaired))
	if stats != null and reward_anchoring > 0:
		var slots: int = stats.grant_anchoring(reward_anchoring)
		if slots > 0:
			granted.append("%d anchor" % slots)

	if granted.is_empty():
		return

	_paid = true
	QuestLog.set_flag(reward_flag)
	Events.notification_requested.emit(
		"The memory leaves something behind: %s" % ", ".join(granted)
	)


func _inventory(interactor: Node) -> InventoryComponent:
	if interactor == null or not interactor.has_method("get_inventory_component"):
		return null
	return interactor.call("get_inventory_component") as InventoryComponent


func _stats(interactor: Node) -> StatsComponent:
	if interactor == null or not interactor.has_method("get_stats_component"):
		return null
	return interactor.call("get_stats_component") as StatsComponent


## The interaction component passes the player root. Keep the lookup in one
## place so a stone never assumes a scene path.
func _caster_for(interactor: Node) -> SpellCaster:
	if interactor == null or not interactor.has_method("get_spell_caster"):
		return null
	return interactor.call("get_spell_caster") as SpellCaster


func _build_visual() -> void:
	if _built:
		return
	_built = true

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.35, 0.33, 0.3, 1)
	stone.roughness = 0.95

	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.97, 0.8, 0.4, 1)
	glow.emission_enabled = true
	glow.emission = Color(0.93, 0.68, 0.24, 1)
	glow.emission_energy_multiplier = 1.8

	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	plinth.mesh = _cylinder_mesh(0.34, 0.42, 0.95)
	plinth.material_override = stone
	plinth.position = Vector3(0, 0.48, 0)
	add_child(plinth)

	var band := MeshInstance3D.new()
	band.name = "Band"
	band.mesh = _cylinder_mesh(0.36, 0.36, 0.08)
	band.material_override = glow
	band.position = Vector3(0, 0.86, 0)
	add_child(band)

	var knot := MeshInstance3D.new()
	knot.name = "Knot"
	knot.mesh = _sphere_mesh(0.2, 0.4)
	knot.material_override = glow
	knot.position = Vector3(0, 1.09, 0)
	add_child(knot)

	var label := Label3D.new()
	label.name = "Sign"
	label.text = "Memory"
	label.font_size = 40
	label.pixel_size = 0.0032
	label.outline_size = 10
	label.modulate = Color(0.95, 0.85, 0.62, 1)
	label.outline_modulate = Color(0.09, 0.08, 0.06, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.52, 0)
	add_child(label)

	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.82, 0.48, 1)
	light.light_energy = 0.7
	light.omni_range = 3.4
	light.position = Vector3(0, 1.05, 0)
	add_child(light)


func _cylinder_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


func _sphere_mesh(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh
