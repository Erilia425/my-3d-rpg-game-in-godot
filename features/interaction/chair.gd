extends StaticBody3D
## A chair the player can sit on with E.
##
## The chair is only an interactable (collision layer 16, the `interactable`
## bit), so the player walks through it but the interaction ray still finds it.
## The painted chair sprite in the room provides the art.
##
## Sitting itself lives in `PlayerController`: a chair never moves the player
## and never owns camera state. It just asks the player to sit here and facing
## the way the chair faces. See AGENTS.md sections 4.6 and 6.

## Optional nudge so the player's eyes sit at a believable chair-seat height.
@export var seat_height_offset: float = 0.0


func get_interaction_text() -> String:
	return "Sit"


func interact(interactor: Node) -> void:
	if interactor == null or not interactor.has_method("sit_at"):
		return

	var seat := global_position
	seat.y += seat_height_offset
	# Global yaw, so a chair nested under a rotated prop still faces the right way.
	interactor.call("sit_at", seat, global_rotation.y)
