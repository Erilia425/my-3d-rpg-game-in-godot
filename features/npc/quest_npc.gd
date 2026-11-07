class_name QuestNpc
extends Npc
## A villager who can also give and finish a quest.
##
## Everything about the look, schedule, and walking comes from `Npc`; this class
## only changes what happens when you talk. Progress lives in `QuestLog`, items
## live in the player's `InventoryComponent`, and this node is the bridge
## between them. See AGENTS.md sections 4.6 and 6.

@export_group("Quest")
## Quest offered on the first conversation. Empty for a plain villager.
@export var offers_quest: StringName = &""
## Optional item handed over when the quest starts (Rowan's ledger page).
@export var offer_gift_item: StringName = &""
@export var offer_gift_amount: int = 1
## Item the quest asks for. Empty means the quest is finished elsewhere, for
## example by reading something in the world.
@export var deliver_item: StringName = &""
@export var deliver_amount: int = 1
## Item handed over when the delivery is accepted.
@export var reward_item: StringName = &""
@export var reward_amount: int = 1

## Lines used when the quest is first offered (falls back to `greeting_lines`).
@export_multiline var offer_lines: PackedStringArray = PackedStringArray()
## Lines used while the quest is still waiting for its item.
@export_multiline var waiting_lines: PackedStringArray = PackedStringArray()
## Lines used at the moment the quest is turned in.
@export_multiline var turn_in_lines: PackedStringArray = PackedStringArray()


func interact(interactor: Node) -> void:
	if interactor is Node3D:
		_face(interactor as Node3D)

	var inventory := _inventory_of(interactor)
	var lines := _respond(inventory)
	if lines.is_empty():
		return

	Events.dialogue_requested.emit(npc_name, role, lines)


## Chooses the right conversation for the current quest state, applying item
## changes as a side effect. Order matters: turn-in, then waiting, then offer,
## then ordinary greeting.
func _respond(inventory: InventoryComponent) -> PackedStringArray:
	if offers_quest.is_empty():
		return greeting_lines

	# 1. The player brought what was asked for.
	if not deliver_item.is_empty() and QuestLog.is_active(offers_quest):
		if inventory != null and inventory.has_item(deliver_item, deliver_amount):
			inventory.remove_item(deliver_item, deliver_amount)

			if QuestLog.complete(offers_quest):
				_announce_complete()
				_give(inventory, reward_item, reward_amount)
			return _lines_or(turn_in_lines, greeting_lines)

		# 2. Still waiting on the item.
		return _lines_or(waiting_lines, greeting_lines)

	# 3. First conversation: start the quest, and hand over any gift with it.
	if not QuestLog.is_active(offers_quest) and not QuestLog.is_completed(offers_quest):
		if not _give(inventory, offer_gift_item, offer_gift_amount):
			# No room for the gift, so the quest waits rather than losing it.
			return _lines_or(waiting_lines, greeting_lines)

		if QuestLog.start(offers_quest):
			Events.notification_requested.emit(
				"Quest started: %s" % QuestLog.get_title(offers_quest)
			)
			return _lines_or(offer_lines, greeting_lines)

	# 4. Nothing quest-shaped to say.
	return greeting_lines


func _lines_or(lines: PackedStringArray, fallback: PackedStringArray) -> PackedStringArray:
	return lines if not lines.is_empty() else fallback


## Hands `amount` of `id` to the inventory. Returns false only when an item was
## requested but could not be added, so callers can avoid losing it.
func _give(inventory: InventoryComponent, id: StringName, amount: int) -> bool:
	if id == &"" or amount <= 0:
		return true
	if inventory == null:
		return false

	var data := ItemDatabase.get_item(id)
	if data == null:
		push_warning("QuestNpc '%s' refers to unknown item %s" % [npc_name, id])
		return true

	var granted := inventory.add_item(data, amount)
	if granted <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return false

	Events.notification_requested.emit("%s acquired" % data.display_name)
	return true


func _announce_complete() -> void:
	Events.notification_requested.emit(
		"Quest complete: %s" % QuestLog.get_title(offers_quest)
	)


## The player owns the inventory; the villager never reaches into player nodes
## directly, it asks for the component through the player's public API.
func _inventory_of(interactor: Node) -> InventoryComponent:
	if interactor == null:
		return null
	if interactor.has_method("get_inventory_component"):
		return interactor.call("get_inventory_component") as InventoryComponent
	return interactor.get_node_or_null("InventoryComponent") as InventoryComponent
