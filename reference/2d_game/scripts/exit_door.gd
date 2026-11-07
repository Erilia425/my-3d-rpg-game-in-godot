extends Area2D

var player = null
var leaving = false

func _ready():
	player = get_tree().get_root().find_child("player", true, false)
	print("Exit door found player: ", player)

func _input(event):
	if player == null:
		return

	if leaving:
		return

	if event is InputEventKey:
		if event.is_action_pressed("interact") and event.pressed and not event.echo:

			var distance = global_position.distance_to(player.global_position)

			if distance < 150:
				leaving = true
				print("LEAVING HOUSE!")

				get_tree().change_scene_to_file("res://village.tscn")
