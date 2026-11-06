extends Node
## Temporary performance probe for the town. Deleted with tools/ afterwards.
## Run windowed so the GPU metrics are real:
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/bench.tscn

const TOWN_SCENE := preload("res://scenes/town.tscn")


func _ready() -> void:
	var town: Node3D = TOWN_SCENE.instantiate()
	add_child(town)

	for i in 120:
		await get_tree().process_frame

	print("fps=", Engine.get_frames_per_second())
	print("nodes=", _count_nodes(town))
	print("draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	print("physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	get_tree().quit()


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
