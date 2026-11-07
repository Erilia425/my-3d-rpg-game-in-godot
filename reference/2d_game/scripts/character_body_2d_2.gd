extends CharacterBody2D

var player: Node2D = null
var was_interacting: bool = false
var ledger_given: bool = false


func _ready():
	print("Rowan script is running!")

	player = get_tree().get_root().find_child("player", true, false)

	print("Player found: ", player)
	print("Rowan is ready to give the Ledger Page.")


func _physics_process(_delta):
	# Find the player again if they were not found at startup.
	if player == null or not is_instance_valid(player):
		player = get_tree().get_root().find_child("player", true, false)

	# Do nothing until the player is found.
	if player == null:
		return

	# Check how close the player is to Rowan.
	var distance_to_player = global_position.distance_to(player.global_position)
	var nearby = distance_to_player < 60.0

	# E only interacts when the player is nearby.
	var interacting = nearby and Input.is_action_pressed("interact")

	# Trigger once when E is first pressed, rather than every frame.
	if interacting and not was_interacting:
		if not ledger_given:
			print("Rowan: The ledger holds more than names.")

			GlobalInventory.add_item("Ledger Page")

			print(
				"Rowan sees Ledger Page count: ",
				GlobalInventory.inventory.get("Ledger Page", 0)
			)
			print("You received a Ledger Page.")

			ledger_given = true
		else:
			print("Rowan: Keep it safe. Some exchanges cannot be undone.")

	# Remember the interaction state so holding E doesn't repeat it.
	was_interacting = interacting
