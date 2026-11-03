extends StaticBody3D
## A chest that opens once and hands its loot to whoever opened it.
##
## The chest owns *which* item it holds (`loot_id`) and how many; the quantity
## the player owns lives in `InventoryComponent`. See AGENTS.md section 6.3.

@export var save_id: StringName = &""
@export var loot_id: StringName = &"item.iron_sword"
@export var amount: int = 1
@export var open_time: float = 0.4

## Final lid angle once the chest is open. Shared by the tween and by loading a
## save, so a restored chest lands in exactly the same pose.
const LID_OPEN_DEGREES := -105.0

var is_open := false
var _tween: Tween

@onready var _lid_pivot: Node3D = %LidPivot


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")


func get_interaction_text() -> String:
	return "" if is_open else "Open chest"


## Loot is granted before the lid moves, so a full inventory leaves the chest
## closed and lootable later instead of swallowing the item.
func interact(interactor: Node) -> void:
	if is_open:
		return

	var data := ItemDatabase.get_item(loot_id)
	if data == null:
		push_warning("Chest %s has unknown loot id %s" % [name, loot_id])
		Events.notification_requested.emit("The chest is empty")
		return

	var granted := amount
	if interactor != null and interactor.has_method("add_item"):
		granted = int(interactor.call("add_item", data, amount))
	if granted <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return

	is_open = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(LID_OPEN_DEGREES), open_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	Events.notification_requested.emit("%s acquired" % data.display_name)


# --- persistence -----------------------------------------------------------
#
# Only "is it open" is saved. The loot itself already lives in the player's
# inventory, so restoring the lid must not grant it a second time.


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"open": is_open}


func load_data(data: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	is_open = bool(data.get("open", false))
	_lid_pivot.rotation.x = deg_to_rad(LID_OPEN_DEGREES) if is_open else 0.0
