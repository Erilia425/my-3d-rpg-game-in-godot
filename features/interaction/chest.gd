extends StaticBody3D
## A chest that opens once.
##
## Phase 1 placeholder: opening the chest shows a HUD notification. The real
## inventory handoff arrives in Phase 2, where this call becomes
## `inventory.add_item(loot_id, amount)`.

@export var loot_id: StringName = &"item.iron_sword"
@export var loot_name: String = "Iron Sword"
@export var amount: int = 1
@export var open_time: float = 0.4

var is_open := false
var _tween: Tween

@onready var _lid_pivot: Node3D = %LidPivot


func get_interaction_text() -> String:
	return "" if is_open else "Open chest"


func interact(_interactor: Node) -> void:
	if is_open:
		return

	is_open = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-105.0), open_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	Events.notification_requested.emit("%s acquired" % loot_name)
	print("Chest: granted %s x%d (%s). Inventory arrives in Phase 2." % [
		loot_name,
		amount,
		loot_id,
	])
