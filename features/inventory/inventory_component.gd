class_name InventoryComponent
extends Node
## Stores how many of each item the owner owns.
##
## `ItemData` owns the definition; this component owns the count. See
## AGENTS.md sections 4.5 and 4.6.

signal item_added(data: ItemData, amount: int)
signal item_removed(data: ItemData, amount: int)
signal inventory_changed()

@export var capacity: int = 24

## One entry per stack: {"id": StringName, "data": ItemData, "amount": int}
var _stacks: Array[Dictionary] = []


## Adds up to `amount` items and returns how many actually fit.
func add_item(data: ItemData, amount: int = 1) -> int:
	if data == null or amount <= 0:
		return 0

	var per_stack := maxi(data.stack_size, 1)
	var remaining := amount

	# Top up stacks that already hold this item.
	for stack in _stacks:
		if remaining <= 0:
			break
		if stack["id"] != data.id:
			continue
		var room := per_stack - int(stack["amount"])
		if room <= 0:
			continue
		var moved := mini(room, remaining)
		stack["amount"] = int(stack["amount"]) + moved
		remaining -= moved

	# Then open new stacks while slots remain.
	while remaining > 0 and _stacks.size() < capacity:
		var moved := mini(per_stack, remaining)
		_stacks.append({"id": data.id, "data": data, "amount": moved})
		remaining -= moved

	var added := amount - remaining
	if added > 0:
		item_added.emit(data, added)
		inventory_changed.emit()
	return added


## Removes `amount` items. Returns false and changes nothing if there are too few.
func remove_item(id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or get_amount(id) < amount:
		return false

	var remaining := amount
	var index := _stacks.size() - 1
	while remaining > 0 and index >= 0:
		var stack := _stacks[index]
		if stack["id"] == id:
			var taken := mini(int(stack["amount"]), remaining)
			stack["amount"] = int(stack["amount"]) - taken
			remaining -= taken
			if int(stack["amount"]) <= 0:
				_stacks.remove_at(index)
		index -= 1

	inventory_changed.emit()
	var data := ItemDatabase.get_item(id)
	if data != null:
		item_removed.emit(data, amount)
	return true


func get_amount(id: StringName) -> int:
	var total := 0
	for stack in _stacks:
		if stack["id"] == id:
			total += int(stack["amount"])
	return total


func has_item(id: StringName, minimum: int = 1) -> bool:
	return get_amount(id) >= minimum


## Copy of the stacks, safe for UI code to read.
func get_slots() -> Array[Dictionary]:
	return _stacks.duplicate(true)


func get_used_slots() -> int:
	return _stacks.size()


func is_full() -> bool:
	return _stacks.size() >= capacity


func clear() -> void:
	if _stacks.is_empty():
		return
	_stacks.clear()
	inventory_changed.emit()


# --- persistence -----------------------------------------------------------
#
# The owning actor decides *when* to save; this component only knows the shape
# of its own data. See AGENTS.md section 8.


func save_data() -> Dictionary:
	var stacks: Array = []
	for stack in _stacks:
		stacks.append({
			"id": String(stack["id"]),
			"amount": int(stack["amount"]),
		})
	return {"capacity": capacity, "stacks": stacks}


func load_data(data: Dictionary) -> void:
	_stacks.clear()
	capacity = maxi(int(data.get("capacity", capacity)), 1)

	var stacks: Array = data.get("stacks", [])
	for entry in stacks:
		if not entry is Dictionary:
			continue

		var id := StringName(str(entry.get("id", "")))
		var data_item := ItemDatabase.get_item(id)
		var amount := int(entry.get("amount", 0))
		if data_item == null or amount <= 0:
			push_warning("InventoryComponent: skipping unknown item '%s'" % id)
			continue

		add_item(data_item, amount)

	inventory_changed.emit()
