extends StaticBody3D
## A hinged door that only opens for someone carrying `required_item`.
##
## Same behaviour as `door.gd` — place the node origin at the hinge, the leaf
## swings to `open_angle_degrees` — with one extra rule: while locked, the door
## refuses to move until the interactor's inventory holds the key. Once it has
## been unlocked the door stays unlocked, and the save remembers that.
##
## The script never grants or consumes the key. It asks the inventory a question
## and the quest hands the key over in the first place, so ownership stays with
## the systems that already own it. See AGENTS.md sections 4.6 and 6.

@export var save_id: StringName = &""
@export var open_angle_degrees: float = 90.0
@export var open_time: float = 0.35

@export_group("Lock")
## Item id the player must be carrying. Empty makes the door behave like a
## normal door.
@export var required_item: StringName = &"item.bakery_key"
## Shown when the door is tried without the key.
@export var locked_message: String = "Locked. Someone keeps the key."
## Shown the first time the key is used.
@export var unlock_message: String = "The key turns. The door is unlocked."

var is_open := false
var is_unlocked := false
var _closed_rotation := 0.0
var _tween: Tween

@onready var _lock: Node3D = get_node_or_null("%Lock") as Node3D


func _ready() -> void:
	_closed_rotation = rotation.y
	if not save_id.is_empty():
		add_to_group(&"saveable")
	# A door with no key is never locked, so mappers can reuse this scene.
	if required_item.is_empty():
		_apply_unlocked()


func get_interaction_text() -> String:
	if is_open:
		return "Close door"
	if is_locked():
		return "Locked door"
	return "Open door"


func is_locked() -> bool:
	return not required_item.is_empty() and not is_unlocked


func interact(interactor: Node) -> void:
	if is_open:
		_set_open(false)
		return

	if is_locked():
		if not _carries_key(interactor):
			Events.notification_requested.emit(locked_message)
			_knock()
			return
		is_unlocked = true
		_apply_unlocked()
		Events.notification_requested.emit(unlock_message)

	_set_open(true)


func _carries_key(interactor: Node) -> bool:
	if interactor == null:
		return false
	if not interactor.has_method("get_inventory_component"):
		return false
	var inventory := interactor.call("get_inventory_component") as InventoryComponent
	if inventory == null:
		return false
	return inventory.has_item(required_item)


func _apply_unlocked() -> void:
	is_unlocked = true
	if _lock != null:
		_lock.visible = false


func _set_open(open: bool) -> void:
	is_open = open

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_rotation := _closed_rotation
	if is_open:
		target_rotation += deg_to_rad(open_angle_degrees)

	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", target_rotation, open_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


## A small rattle on the handle, so a locked door answers the attempt.
func _knock() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var rest := rotation.y
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", rest + deg_to_rad(2.5), 0.06)
	_tween.tween_property(self, "rotation:y", rest - deg_to_rad(2.0), 0.08)
	_tween.tween_property(self, "rotation:y", rest, 0.06)


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"open": is_open, "unlocked": is_unlocked}


func load_data(data: Dictionary) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	is_open = bool(data.get("open", false))
	is_unlocked = bool(data.get("unlocked", false))
	if is_unlocked:
		_apply_unlocked()

	rotation.y = _closed_rotation + (deg_to_rad(open_angle_degrees) if is_open else 0.0)
