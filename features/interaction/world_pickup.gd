extends StaticBody3D
## A single item lying in the world, collected by interacting with it.
##
## Ported from the 2D `pickup_area.gd` (which collected on the interact key when
## the player was close). The pickup owns *which* item it holds and how many; the
## quantity the player owns lives in `InventoryComponent`, exactly like the chest.
## See AGENTS.md section 6.3.
##
## A collected pickup stays collected across saves. If the bag is full the
## pickup is left in the world so it can be collected later.

## Stable id for the save file. Leave empty for a pickup that should not persist.
@export var save_id: StringName = &""
## Item granted when collected.
@export var item_id: StringName = &"item.mushroom"
@export var amount: int = 1
## Optional 2D art for the pickup. When set it replaces the placeholder mesh.
@export var sprite_texture: Texture2D = null
## Optional lore page this pickup unlocks in the Ledger (see `Progression.LORE_DEFS`).
@export var lore_page_id: StringName = &""

var collected := false

@onready var _sprite: Sprite3D = get_node_or_null("Sprite") as Sprite3D
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
@onready var _collision: CollisionShape3D = get_node_or_null("Collision") as CollisionShape3D


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")

	if _sprite != null:
		if sprite_texture != null:
			_sprite.texture = sprite_texture
			_sprite.visible = true
		else:
			_sprite.visible = false

	if _mesh != null:
		_mesh.visible = _sprite == null or not _sprite.visible


func get_interaction_text() -> String:
	if collected:
		return ""
	var data := ItemDatabase.get_item(item_id)
	if data == null:
		return "Collect"
	return "Collect %s" % data.display_name


## Loot is granted before the pickup disappears, so a full inventory leaves it
## in the world instead of swallowing the item.
func interact(interactor: Node) -> void:
	if collected:
		return

	var data := ItemDatabase.get_item(item_id)
	if data == null:
		push_warning("Pickup %s has unknown item id %s" % [name, item_id])
		return

	var granted := amount
	if interactor != null and interactor.has_method("add_item"):
		granted = int(interactor.call("add_item", data, amount))
	if granted <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return

	collected = true
	_apply_collected()
	Events.notification_requested.emit("%s acquired" % data.display_name)
	if not lore_page_id.is_empty():
		if Progression.add_ledger_page(lore_page_id):
			Events.notification_requested.emit(
				"Ledger page recovered: %s" % Progression.get_lore_title(lore_page_id)
			)
		elif not Progression.has_ledger():
			Events.notification_requested.emit("Read your ledger to keep this page safe")


func _apply_collected() -> void:
	if _sprite != null:
		_sprite.visible = false
	if _mesh != null:
		_mesh.visible = false
	if _collision != null:
		_collision.set_deferred("disabled", true)


# --- persistence -----------------------------------------------------------
#
# Only "is it collected" is saved. The item itself already lives in the player's
# inventory, so restoring the pickup must not grant it a second time.


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"collected": collected}


func load_data(data: Dictionary) -> void:
	collected = bool(data.get("collected", false))
	if collected:
		_apply_collected()
