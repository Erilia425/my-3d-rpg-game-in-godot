extends Area2D

var player = null

func _ready():
	player = get_tree().get_root().get_node("village/player")
	print("House 1 door is working!")

func _process(_delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if Input.is_action_pressed("interact"):
		print("E at house door. Distance: ", distance)

		if distance < 150:
			print("ENTERING HOUSE 1!")

			var result = get_tree().change_scene_to_file("res://house_interior.tscn")

			print("Scene change result: ", result)
