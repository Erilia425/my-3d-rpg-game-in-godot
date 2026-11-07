
extends Area2D

var player: Node2D = null
var dialogue_ui: Node = null
var interaction_was_pressed: bool = false


func _ready() -> void:
	# Find the player and dialogue UI in the village scene.
	player = get_tree().root.get_node_or_null("village/player")
	dialogue_ui = get_tree().root.get_node_or_null("village/DialogueUI")

	# Fallback searches in case the scene paths differ.
	if player == null:
		player = get_tree().root.find_child("player", true, false)

	if dialogue_ui == null:
		dialogue_ui = get_tree().root.find_child("DialogueUI", true, false)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("player", true, false)

	if dialogue_ui == null or not is_instance_valid(dialogue_ui):
		dialogue_ui = get_tree().root.find_child("DialogueUI", true, false)

	if player == null or dialogue_ui == null:
		return

	# The player must be close enough to interact.
	var distance: float = global_position.distance_to(player.global_position)
	var near_auntie: bool = distance < 150.0
	var e_pressed: bool = Input.is_action_pressed("interact")

	# Interact only once per E press.
	if near_auntie and e_pressed and not interaction_was_pressed:
		if not dialogue_ui.dialogue_active and not dialogue_ui.closing:
			interact_with_auntie()

	interaction_was_pressed = e_pressed


func interact_with_auntie() -> void:
	# If the favor is already completed, do not give another reward.
	if GlobalInventory.favors["deliver_sporebread"]:
		dialogue_ui.start_dialogue([
			"Auntie Bell: Thank you again for the Sporebread, dear.",
			"Auntie Bell: It was just what I needed!"
		])
		return

	# Check whether the player has Sporebread to deliver.
	if GlobalInventory.inventory["Sporebread"] > 0:
		# Remove one Sporebread.
		GlobalInventory.inventory["Sporebread"] -= 1

		# Give the player one Hearth-Silk.
		GlobalInventory.add_item("Hearth-Silk")

		# Complete the favor.
		var favor_completed: bool = GlobalInventory.complete_favor(
			"deliver_sporebread"
		)

		if favor_completed:
			# Unlock the discovery in the ledger.
			GlobalInventory.unlock_discovery("fungal_record")

			# Refresh the ledger if the UI exists.
			var ledger_ui: Node = get_tree().root.find_child(
				"LedgerUI", true, false
			)

			if ledger_ui != null and ledger_ui.has_method("refresh_entries"):
				ledger_ui.refresh_entries()

			# Thank the player and announce the discovery.
			dialogue_ui.start_dialogue([
				"Auntie Bell: Oh! You brought me Sporebread!",
				"Auntie Bell: It smells wonderful, dear. Thank you.",
				"Auntie Bell: Here, take some Hearth-Silk for your kindness.",
				"FAVOR COMPLETE: Sporebread delivered!",
				"NEW DISCOVERY: The Fungal Record",
				"Auntie Bell: The fungi used for Sporebread grow near something old beneath the woods..."
			])
		else:
			# Safety fallback if the favor was completed elsewhere.
			dialogue_ui.start_dialogue([
				"Auntie Bell: Thank you for the Sporebread, dear."
			])

		return

	# If the player has no Sporebread, show the introduction and favor request.
	dialogue_ui.start_dialogue([
		"Auntie Bell: Welcome to Mycelgrove Hollow, dear.",
		"Auntie Bell: You look like you've wandered a long way.",
		"Auntie Bell: Are you looking for something?",
		"Auntie Bell: If you have time, could you bring me some Sporebread?"
	])
