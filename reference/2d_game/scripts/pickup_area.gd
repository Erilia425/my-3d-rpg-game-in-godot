extends Area2D

@export var item_name = "Mushroom"

var player = null

func _ready():
	player = get_tree().get_root().get_node("village/player")

func _process(_delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance < 80 and Input.is_action_pressed("interact"):
		player.add_item(item_name)
		get_parent().queue_free()
