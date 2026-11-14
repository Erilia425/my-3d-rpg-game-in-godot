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
## Second item handed over at turn-in, for rewards that are not the quest's
## headline item (Auntie Bell's key). Granted once, with the main reward.
@export var extra_reward_item: StringName = &""
@export var extra_reward_amount: int = 1
## Extra rewards granted the first time the quest is completed. Favor raises
## this villager's market discount; XP raises the player's level.
@export var reward_favor: int = 0
@export var reward_xp: int = 0
@export var reward_coins: int = 0
## Lore discovery unlocked the first time the quest is completed. Empty means
## the quest reveals no discovery.
@export var unlock_discovery: StringName = &""

## Lines used when the quest is first offered (falls back to `greeting_lines`).
@export_multiline var offer_lines: PackedStringArray = PackedStringArray()
## Lines used while the quest is still waiting for its item.
@export_multiline var waiting_lines: PackedStringArray = PackedStringArray()
## Lines used at the moment the quest is turned in.
@export_multiline var turn_in_lines: PackedStringArray = PackedStringArray()

@export_group("One-time gift")
## Item handed over once, the first time a plain villager is spoken to. Set on
## villagers with no quest; quest-bearing villagers use `offer_gift_item`.
@export var gift_item: StringName = &""
@export var gift_amount: int = 1
## Save flag that remembers the gift was given. Leave empty to derive one from
## `npc_name`, which is stable for a placed villager.
@export var gift_flag: StringName = &""
## What the villager says as they hand the gift over.
@export_multiline var gift_lines: PackedStringArray = PackedStringArray()
## What they say on every later visit.
@export_multiline var gift_after_lines: PackedStringArray = PackedStringArray()


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
		return _respond_without_quest(inventory)

	# 1. The player brought what was asked for.
	if not deliver_item.is_empty() and QuestLog.is_active(offers_quest):
		if inventory != null and inventory.has_item(deliver_item, deliver_amount):
			inventory.remove_item(deliver_item, deliver_amount)

			if QuestLog.complete(offers_quest):
				_announce_complete()
				_give(inventory, reward_item, reward_amount)
				_give(inventory, extra_reward_item, extra_reward_amount)
				_award_bonus_rewards()
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


## Conversation for a villager who never offers a quest. The only side effect is
## the optional one-time gift, which is remembered in `QuestLog` flags so it can
## never be collected twice, even across saves.
func _respond_without_quest(inventory: InventoryComponent) -> PackedStringArray:
	if gift_item.is_empty() or gift_amount <= 0:
		return greeting_lines

	var flag := _gift_flag()
	if QuestLog.has_flag(flag):
		return _lines_or(gift_after_lines, greeting_lines)

	if not _give(inventory, gift_item, gift_amount):
		# No room for the gift: do not mark it given, so it can be collected later.
		return _lines_or(gift_after_lines, greeting_lines)

	QuestLog.set_flag(flag)
	return _lines_or(gift_lines, greeting_lines)


func _gift_flag() -> StringName:
	if not gift_flag.is_empty():
		return gift_flag
	return StringName("gift.%s" % npc_name.to_snake_case())


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


## Grants the optional favor, XP, and coin rewards exactly once, at turn-in.
## Only called after `QuestLog.complete()` returns true, so a quest can never pay
## out twice.
func _award_bonus_rewards() -> void:
	if reward_favor > 0:
		Progression.add_favor(StringName("npc.%s" % npc_name.to_snake_case()), reward_favor)
	if reward_xp > 0:
		Progression.add_xp(reward_xp)
	if reward_coins > 0:
		Progression.add_coins(reward_coins)
		Events.notification_requested.emit("%d coins received" % reward_coins)


func _announce_complete() -> void:
	Events.notification_requested.emit(
		"Quest complete: %s" % QuestLog.get_title(offers_quest)
	)

	if unlock_discovery.is_empty():
		return
	if DiscoveryLog.unlock(unlock_discovery):
		Events.notification_requested.emit(
			"Discovery: %s" % DiscoveryLog.get_title(unlock_discovery)
		)


## The player owns the inventory; the villager never reaches into player nodes
## directly, it asks for the component through the player's public API.
func _inventory_of(interactor: Node) -> InventoryComponent:
	if interactor == null:
		return null
	if interactor.has_method("get_inventory_component"):
		return interactor.call("get_inventory_component") as InventoryComponent
	return interactor.get_node_or_null("InventoryComponent") as InventoryComponent
