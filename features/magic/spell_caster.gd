class_name SpellCaster
extends Node
## The player's two spells: Recall and Anchor.
##
## A spell in the Hollow is borrowed, contained, and recorded. Recall spends
## **memory charge** (from prepared honey) and one dose of memory-honey to show
## a stored memory. Silk does not pay the cost; it decides whether the memory
## stays contained. If the player's silk is thinner than the spell, the leftover
## memory leaks and the Ledger records imbalance.
##
## Anchor spends one **tooth** and a little memory to hold the caster steady.
## While it holds, `StatsComponent.can_contain()` is true, so a Recall that the
## silk could not hold does not leak. A tooth is never an ordinary spell cost;
## Anchor is the deliberate way to spend one.
##
## Lives beside `player_controller.gd`, like `player_combat.gd`, so the
## controller stays about movement and cameras. See AGENTS.md sections 4.1, 14
## and the mana decision in section 15.

## Memory charge spent by one Recall.
const RECALL_MEMORY_COST := 20.0
## Silk below this cannot contain a Recall; the difference leaks.
const RECALL_SILK_REQUIRED := 20.0
## Imbalance recorded when a Recall leaks.
const RECALL_LEAK_IMBALANCE := 10.0
## How far away a memory stone can be recalled from.
const RECALL_RANGE := 12.0
## Teeth and memory spent by one Anchor.
const ANCHOR_TOOTH_COST := 1
const ANCHOR_MEMORY_COST := 10.0
## Small incidental objects are not worth a prepared dose; Recall is deliberate.
const MEMORY_HONEY := &"item.memory_honey"
const MEMORY_GROUP := &"memory"

@onready var _player: PlayerController = get_parent() as PlayerController
@onready var _health: HealthComponent = get_parent().get_node("%HealthComponent")
@onready var _stats: StatsComponent = get_parent().get_node("%StatsComponent")
@onready var _inventory: InventoryComponent = get_parent().get_node("%InventoryComponent")


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if _player.is_ui_blocked() or _health.is_dead():
		return

	if event.is_action_pressed("cast_spell"):
		if try_recall():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("cast_anchor"):
		if try_anchor():
			get_viewport().set_input_as_handled()


## Casts Recall on `target`, or on the nearest memory within range when none is
## named. Returns true only when the spell actually fired.
func try_recall(target: Node = null) -> bool:
	if _health.is_dead():
		return false

	var memory := target if _is_memory(target) else _nearest_memory()
	if memory == null:
		Events.notification_requested.emit("No memory answers here.")
		return false

	if _stats.get_memory() < RECALL_MEMORY_COST:
		Events.notification_requested.emit(
			"Recall needs %d memory. Eat memory-honey first."
			% roundi(RECALL_MEMORY_COST)
		)
		return false

	if not _inventory.has_item(MEMORY_HONEY):
		Events.notification_requested.emit(
			"Recall needs a dose of memory-honey."
		)
		return false

	# Pay only once every requirement is met, so a failed cast never eats a dose.
	_stats.spend_memory(RECALL_MEMORY_COST)
	_inventory.remove_item(MEMORY_HONEY, 1)

	var leaked := not _stats.can_contain(RECALL_SILK_REQUIRED)
	if leaked:
		Ledger.add_imbalance(RECALL_LEAK_IMBALANCE)

	var lines := PackedStringArray()
	lines.append(String(memory.call("get_memory_text")))
	if leaked:
		lines.append(
			"The memory slips at the edges. Your silk is too thin to hold it."
			+ "\n\nThe Ledger records %d imbalance."
			% roundi(RECALL_LEAK_IMBALANCE)
		)
		Events.notification_requested.emit("The Ledger noticed")

	Events.dialogue_requested.emit(
		String(memory.call("get_memory_title")), "Recalled Memory", lines
	)
	return true


## Holds the caster steady for one tooth. While the anchor holds, `can_contain()`
## is true, so a spell the silk cannot hold will not leak into the Ledger.
## Returns true only when the anchor actually started.
func try_anchor() -> bool:
	if _health.is_dead():
		return false

	if _stats.is_anchored():
		Events.notification_requested.emit(
			"The anchor still holds. Let it lapse before spending another tooth."
		)
		return false

	if _stats.get_anchoring() < ANCHOR_TOOTH_COST:
		Events.notification_requested.emit(
			"Anchor needs a tooth. Corin Vale keeps them in the square."
		)
		return false

	if _stats.get_memory() < ANCHOR_MEMORY_COST:
		Events.notification_requested.emit(
			"Anchor needs %d memory." % roundi(ANCHOR_MEMORY_COST)
		)
		return false

	# Both costs are known to be payable, so one is never spent without the other.
	_stats.spend_memory(ANCHOR_MEMORY_COST)
	_stats.spend_anchoring(ANCHOR_TOOTH_COST)
	_stats.hold_anchor()

	Events.notification_requested.emit(
		"Anchored. Your silk cannot leak for %d seconds."
		% roundi(_stats.get_anchor_guard_time())
	)
	return true


## True when a node can be recalled, so a stone can ask the caster to read it.
func _is_memory(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.is_in_group(MEMORY_GROUP):
		return false
	return node.has_method("get_memory_text") and node.has_method("get_memory_title")


## Nearest memory stone in range. A deliberate key press may scan the group;
## this never runs in `_process`. See AGENTS.md 10.2.
func _nearest_memory() -> Node:
	var origin := _player.global_position
	var best: Node = null
	var best_distance := RECALL_RANGE

	for node in get_tree().get_nodes_in_group(MEMORY_GROUP):
		var spatial := node as Node3D
		if spatial == null:
			continue
		var distance := origin.distance_to(spatial.global_position)
		if distance <= best_distance:
			best = node
			best_distance = distance

	return best
