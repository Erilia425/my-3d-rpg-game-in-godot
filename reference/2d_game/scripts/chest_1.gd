extends Area2D

var player = null
var opened = false

func _ready():
	player = get_tree().get_root().find_child("player", true, false)

func _input(event):
	if player == null or opened:
		return

	if event is InputEventKey:
		if event.is_action_pressed("interact") and event.pressed and not event.echo:
			var distance = global_position.distance_to(player.global_position)

			if distance < 120:
				opened = true
				player.add_item("Hearth-Silk")
				print("You found Hearth-Silk in Rowan's chest!")
