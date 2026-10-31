extends Control
## Temporary boot screen. Routes to the main menu after one frame so the
## engine has time to finish initializing autoloads.


func _ready() -> void:
	Game.set_state(Game.State.BOOT)
	await get_tree().process_frame
	SceneRouter.goto_scene("res://scenes/main_menu.tscn", false)
