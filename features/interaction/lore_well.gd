class_name LoreWell
extends StaticBody3D
## A village well that keeps a story.
##
## Press **E** and the well speaks through the dialogue window: two or three
## lines of local history, in the same panel the villagers use. A well can also
## pay out once — a little silk, a tooth, or an item — the first time it is
## listened to, so wandering the town's quiet corners has a reward that is not
## a chest.
##
## The node owns only *whether it has already paid*. The goods go to the
## player's inventory and stats, exactly like the chest. See AGENTS.md 6.3.
##
## The collision cylinder is a little wider than `TownProp`'s well ring, so the
## interaction ray meets this body first and the prompt appears.

## Heading in the dialogue window.
@export var well_title: String = "A Well in the Hollow"
## What the well remembers. Two or three short lines is the right length.
@export var lines: PackedStringArray = PackedStringArray()
## One-time payment. Leave every field empty for a well that only speaks.
@export var reward_item: StringName = &""
@export var reward_amount: int = 1
@export var reward_silk: float = 0.0
@export var reward_anchoring: int = 0
## Stable flag id for the one-time reward. Leave empty for a well that never
## pays, or for one that should pay on every visit.
@export var reward_flag: StringName = &""

## Set by the first successful payout so the panel does not promise again.
var _paid := false


func _ready() -> void:
	add_to_group(&"interactable")
	_build_glow()
	_paid = not reward_flag.is_empty() and QuestLog.has_flag(reward_flag)


func get_interaction_text() -> String:
	return "Listen to the well" if not _paid else "Remember the well"


func get_well_title() -> String:
	return well_title


func get_lines() -> PackedStringArray:
	return lines


func interact(interactor: Node) -> void:
	var spoken := lines.duplicate()
	if spoken.is_empty():
		spoken.append("The water keeps its own counsel.")

	if _paid or reward_flag.is_empty():
		Events.dialogue_requested.emit(well_title, "A Well", spoken)
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
		var granted_slots: int = stats.grant_anchoring(reward_anchoring)
		if granted_slots > 0:
			granted.append("%d anchor" % granted_slots)

	if granted.is_empty():
		# Nothing fit (a full bag, or already whole). Speak, but do not burn
		# the flag: the player can come back.
		Events.dialogue_requested.emit(well_title, "A Well", spoken)
		return

	_paid = true
	QuestLog.set_flag(reward_flag)
	spoken.append("Something is left in the bucket: %s." % ", ".join(granted))
	Events.dialogue_requested.emit(well_title, "A Well", spoken)
	Events.notification_requested.emit("The well gives: %s" % ", ".join(granted))


## A low, warm light so a well is findable at dusk. Guided by light, not an
## arrow on a screen. See the "guiding lights" note in the decision log.
func _build_glow() -> void:
	if get_node_or_null("WellLight") != null:
		return
	var light := OmniLight3D.new()
	light.name = "WellLight"
	light.light_color = Color(1.0, 0.84, 0.56, 1)
	light.light_energy = 0.55
	light.omni_range = 4.5
	light.position = Vector3(0, 1.4, 0)
	add_child(light)


func _inventory(interactor: Node) -> InventoryComponent:
	if interactor == null or not interactor.has_method("get_inventory_component"):
		return null
	return interactor.call("get_inventory_component") as InventoryComponent


func _stats(interactor: Node) -> StatsComponent:
	if interactor == null or not interactor.has_method("get_stats_component"):
		return null
	return interactor.call("get_stats_component") as StatsComponent
