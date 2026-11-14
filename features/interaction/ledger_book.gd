extends StaticBody3D
## Rowan's ledger: an interactable book that can now be picked up and carried.
##
## On the first interaction it grants `item.ledger`, marks the Ledger as found in
## `Progression`, unlocks its first lore pages, finishes the "read the ledger"
## quest, and shows the two opening pages in the dialogue window. Afterwards the
## book is hidden, and the Ledger can be opened from the HUD at any time.
##
## The node is saveable: a collected ledger never reappears in Rowan's house.

## Stable id for the save file. Empty makes the book non-persistent.
@export var save_id: StringName = &"interaction.rowans_house.ledger"
## Quest finished by picking the ledger up. Empty disables the quest hook.
@export var quest_id: StringName = &"quest.rowan_ledger"
## Item granted when collected.
@export var item_id: StringName = &"item.ledger"
@export var amount: int = 1
## Lore pages unlocked together with the book.
@export var lore_page_ids: Array[StringName] = [
	&"page.hollow_root",
	&"page.thimble",
]
@export var speaker_name: String = "Rowan's Ledger"
@export var role: String = "Keeper of Records"
@export_multiline var pages: PackedStringArray = PackedStringArray(
	[
		"ROWAN'S LEDGER\n\nNames. Exchanges. Debts.\n\nThe handwriting changes halfway through the page.",
		"ENTRY 47\n\nName: Thimble\nPayment: Hearth-Silk\nDebt: UNPAID\n\nThe name has been crossed out.\n\nUnderneath, in a different hand:\n\nThey were never supposed to be counted.",
	]
)

var collected := false

@onready var _sprite: Sprite3D = get_node_or_null("Sprite") as Sprite3D
@onready var _collision: CollisionShape3D = get_node_or_null("Collision") as CollisionShape3D


func _ready() -> void:
	add_to_group(&"interactable")
	if not save_id.is_empty():
		add_to_group(&"saveable")


func get_interaction_text() -> String:
	if collected:
		return ""
	return "Take the ledger"


func interact(interactor: Node) -> void:
	if collected:
		return

	var data := ItemDatabase.get_item(item_id)
	if data == null:
		push_warning("Ledger book has unknown item id %s" % item_id)
		return

	var granted := amount
	if interactor != null and interactor.has_method("add_item"):
		granted = int(interactor.call("add_item", data, amount))
	if granted <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return

	collected = true
	_apply_collected()
	Progression.set_ledger_found(true)
	for page_id in lore_page_ids:
		Progression.add_ledger_page(page_id)

	Events.notification_requested.emit("Rowan's Ledger acquired — open it from your inventory")

	if not quest_id.is_empty() and QuestLog.is_active(quest_id):
		if QuestLog.complete(quest_id):
			Events.notification_requested.emit(
				"Quest complete: %s" % QuestLog.get_title(quest_id)
			)

	Events.dialogue_requested.emit(speaker_name, role, pages)


func _apply_collected() -> void:
	if _sprite != null:
		_sprite.visible = false
	if _collision != null:
		_collision.set_deferred("disabled", true)


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"collected": collected}


func load_data(data: Dictionary) -> void:
	collected = bool(data.get("collected", false))
	if collected:
		_apply_collected()
