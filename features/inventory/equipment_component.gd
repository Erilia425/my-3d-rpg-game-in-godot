class_name EquipmentComponent
extends Node
## Owns what the actor has equipped, and derives combat values from it.
##
## Equipped items are owned here, not by the inventory: equipping moves one item
## out of `InventoryComponent` and unequipping moves it back.

signal equipment_changed()

@export var unarmed_damage: float = 6.0

var _inventory: InventoryComponent
## EquipSlot (int) -> ItemData
var _equipped: Dictionary = {}


## The owner wires this up in _ready(). Components never reach for siblings.
func setup(inventory: InventoryComponent) -> void:
	_inventory = inventory


## Moves one item from the inventory into its slot, swapping out anything there.
func equip(id: StringName) -> bool:
	var data := ItemDatabase.get_item(id)
	if data == null or not data.is_equipment():
		return false
	if _inventory == null or not _inventory.has_item(id):
		return false

	var previous: ItemData = _equipped.get(data.equip_slot)
	if not _inventory.remove_item(id, 1):
		return false

	if previous != null and _inventory.add_item(previous, 1) == 0:
		# No room to return the old item: put the new one back and give up.
		_inventory.add_item(data, 1)
		return false

	_equipped[data.equip_slot] = data
	equipment_changed.emit()
	return true


## Returns the equipped item of `slot` to the inventory.
func unequip(slot: int) -> bool:
	var data: ItemData = _equipped.get(slot)
	if data == null:
		return false
	if _inventory != null and _inventory.add_item(data, 1) == 0:
		return false

	_equipped.erase(slot)
	equipment_changed.emit()
	return true


func get_equipped(slot: int) -> ItemData:
	return _equipped.get(slot) as ItemData


func get_weapon() -> ItemData:
	return get_equipped(ItemData.EquipSlot.MAIN_HAND)


func get_body_armor() -> ItemData:
	return get_equipped(ItemData.EquipSlot.BODY)


func get_attack_damage() -> float:
	var weapon := get_weapon()
	if weapon == null:
		return unarmed_damage
	return unarmed_damage + weapon.damage


func get_armor_value() -> float:
	var armor := get_body_armor()
	return 0.0 if armor == null else armor.armor


# --- persistence -----------------------------------------------------------
#
# Equipped items are saved by id and slot; the definitions come back from
# `ItemDatabase`, so a renamed id is reported and skipped instead of crashing.


func save_data() -> Dictionary:
	var slots: Array = []
	for slot in _equipped.keys():
		var item: ItemData = _equipped[slot]
		if item == null:
			continue
		slots.append({"slot": int(slot), "id": String(item.id)})
	return {"slots": slots}


func load_data(data: Dictionary) -> void:
	_equipped.clear()

	var slots: Array = data.get("slots", [])
	for entry in slots:
		if not entry is Dictionary:
			continue

		var id := StringName(str(entry.get("id", "")))
		var item := ItemDatabase.get_item(id)
		var slot := int(entry.get("slot", ItemData.EquipSlot.NONE))
		if item == null or not item.is_equipment():
			push_warning("EquipmentComponent: skipping unknown equipment '%s'" % id)
			continue

		_equipped[slot] = item

	equipment_changed.emit()
