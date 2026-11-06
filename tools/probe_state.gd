extends SceneTree
## Temporary probe: print the saved node paths of scenes/town.tscn.

func _initialize() -> void:
	var packed := load("res://scenes/town.tscn") as PackedScene
	var state := packed.get_state()
	print("node_count=", state.get_node_count())
	for i in mini(state.get_node_count(), 16):
		print(i, " path=", state.get_node_path(i), " name=", state.get_node_name(i), " type=", state.get_node_type(i))
	for i in state.get_node_count():
		if String(state.get_node_name(i)) in ["HomeGate", "Player"]:
			print("--- ", state.get_node_name(i))
			for p in state.get_node_property_count(i):
				print("   ", state.get_node_property_name(i, p), " = ", state.get_node_property_value(i, p))
	quit()
