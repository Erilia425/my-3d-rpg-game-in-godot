
extends CharacterBody2D

var player: Node2D = null
var was_interacting = false
var gift_given = false

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
		print("Mossy Villager: Welcome, dear. The woods have been restless.")
		if not gift_given:
			GlobalInventory.add_item("Mushroom")
			print("Mossy Villager: Here, take a mushroom for your travels.")
			gift_given = true
		else:
			print("Mossy Villager: Keep to the paths when the fog rolls in.")

	was_interacting = interacting
