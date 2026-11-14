extends StaticBody3D
## A bed the player can sleep in.
##
## Sleeping is the game's rest action: it moves the world clock to the next
## morning, restores health and stamina, and writes a manual save so the rest
## point survives quitting. It carries no visuals of its own: the painted bed
## sprite in the room is the art, this node is only the solid, usable body.

## Hour of day the player wakes at (0-24). 7.0 is one hour before the 08:00
## start of the villager daytime schedule, so resting feels like a night.
@export var wake_hour: float = 7.0
## Shown through the HUD toast after sleeping.
@export var wake_message: String = "You sleep until morning"

@onready var _interaction_text: String = "Sleep"


func get_interaction_text() -> String:
	return _interaction_text


func interact(interactor: Node) -> void:
	if interactor == null or not interactor.has_method("get_health_component"):
		return

	var health := interactor.call("get_health_component") as HealthComponent
	var stats := interactor.call("get_stats_component") as StatsComponent
	if health == null or stats == null:
		return

	if health.is_dead():
		health.revive()
	health.heal(health.get_max_health())
	stats.restore_stamina(stats.get_max_stamina())
	stats.restore_mana(stats.get_max_mana())

	WorldClock.rest_until(wake_hour)

	# A deliberate rest is a manual save (slot 0), so it can never be
	# overwritten by the autosave slot. See AGENTS.md section 8.
	Game.save_game(Game.MANUAL_SLOT)

	Events.notification_requested.emit(wake_message)
