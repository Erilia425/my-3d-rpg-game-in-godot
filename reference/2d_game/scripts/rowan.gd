
extends CharacterBody2D

var player: Node2D = null
var was_interacting = false
var ledger_given = false

func _ready():
	player = get_tree().get_root().find_child("player", true, false)

func _physics_process(_delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_root().find_child("player", true, false)

	if player == null:
		return

	var nearby = global_position.distance_to(player.global_position) < 60.0
	var interacting = nearby and Input.is_action_pressed("interact")

	if interacting and not was_interacting:
		if not ledger_given:
			print("Rowan: The ledger holds more than names.")
			GlobalInventory.add_item("Ledger Page")
			print("You received a Ledger Page.")
			ledger_given = true
		else:
			print("Rowan: Keep it safe. Some exchanges cannot be undone.")

	was_interacting = interacting
