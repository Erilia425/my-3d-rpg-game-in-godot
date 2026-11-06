extends Node
## Temporary probe: what stands within a few metres of the street camera?

const TOWN_SCENE := preload("res://scenes/town.tscn")
const LOOK_AT := Vector3(-37, 1.5, -13)


func _ready() -> void:
	var town: Node3D = TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var found := 0
	for group_name in ["Buildings", "Props", "Gates", "Water", "Paths", "Forest"]:
		var group := town.get_node_or_null(group_name)
		if group == null:
			continue
		for child in group.get_children():
			if child is not Node3D:
				continue
			var at := (child as Node3D).global_position
			var flat := Vector2(at.x - LOOK_AT.x, at.z - LOOK_AT.z).length()
			if flat < 6.0:
				found += 1
				# A tree at this range is the likely culprit: report its scale too.
				var extra := ""
				if "size" in child:
					extra = " size=%s" % str(child.get("size"))
				print("%-16s %-14s at %s flat=%.2f%s" % [group_name, child.name, at, flat, extra])
	print("near objects=", found)
	get_tree().quit()
