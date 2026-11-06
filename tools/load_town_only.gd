extends Node
## Throwaway: load the town's scene state the way the phase 3 test does, to see
## whether the RefCounted leak comes from the town content alone.

func _ready() -> void:
	var packed := load("res://scenes/town.tscn") as PackedScene
	print("loaded=%s" % (packed != null))
	if packed != null:
		var state := packed.get_state()
		print("nodes=%d" % state.get_node_count())
	get_tree().quit()
