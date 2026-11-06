extends Area3D
## The inside face of an interior's door.
##
## It does not know the street it belongs to: `Game` recorded the doorstep when
## the player entered, and `Game.exit_interior()` travels back to it. The area
## sits just inside the door, clear of the player's spawn, so arriving cannot
## immediately fire it.

var _leaving := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	_leaving = true
	# The player can reach the door while the arrival fade is still running;
	# Game refuses travel mid-transition, so wait for it to finish first.
	while SceneRouter.is_transitioning():
		await get_tree().process_frame
	if not await Game.exit_interior():
		_leaving = false
