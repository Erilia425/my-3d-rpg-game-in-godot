extends StaticBody3D
## Rowan's ledger: an interactable book that shows two pages in the dialogue
## window and finishes the "read the ledger" quest the first time it is opened.
##
## The book owns no progress of its own; `QuestLog` does. See AGENTS.md
## sections 4.6 and 6.

## Quest finished by reading. Empty disables the quest hook.
@export var quest_id: StringName = &"quest.rowan_ledger"
@export var speaker_name: String = "Rowan's Ledger"
@export var role: String = "Keeper of Records"
@export_multiline var pages: PackedStringArray = PackedStringArray(
	[
		"ROWAN'S LEDGER\n\nNames. Exchanges. Debts.\n\nThe handwriting changes halfway through the page.",
		"ENTRY 47\n\nName: Thimble\nPayment: Hearth-Silk\nDebt: UNPAID\n\nThe name has been crossed out.\n\nUnderneath, in a different hand:\n\nThey were never supposed to be counted.",
	]
)


func _ready() -> void:
	add_to_group(&"interactable")


func get_interaction_text() -> String:
	return "Read the ledger"


func interact(_interactor: Node) -> void:
	if not quest_id.is_empty() and QuestLog.is_active(quest_id):
		if QuestLog.complete(quest_id):
			Events.notification_requested.emit(
				"Quest complete: %s" % QuestLog.get_title(quest_id)
			)

	Events.dialogue_requested.emit(speaker_name, role, pages)
