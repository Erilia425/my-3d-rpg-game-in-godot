extends Node
## Temporary screenshot harness for the town. Deleted with tools/ afterwards.
## Run windowed (rendering needs a real display):
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tools/shot.tscn

const TOWN_SCENE := preload("res://scenes/town.tscn")
const ROOM_SCENE := preload("res://scenes/test_room.tscn")


func _ready() -> void:
	var town: Node3D = TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	for layer_name in ["HUD", "PauseMenu", "HintPanel"]:
		var node := town.get_node_or_null(layer_name)
		if node is CanvasLayer or node is CanvasItem:
			node.visible = false

	# The F3 overlay is an autoload, not part of the town.
	var debug_overlay := get_node_or_null("/root/Debug")
	if debug_overlay is CanvasLayer:
		debug_overlay.visible = false

	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 400.0
	town.add_child(camera)
	camera.current = true

	await _shoot(camera, Vector3(-82, 66, 80), Vector3(4, 1, -6), "res://temp_town_wide.png")
	await _shoot(camera, Vector3(88, 62, 74), Vector3(16, 1, -14), "res://temp_town_wide_east.png")
	await _shoot(camera, Vector3(-37, 2.1, -13), Vector3(10, 1.4, -4), "res://temp_town_street.png")
	await _shoot(camera, Vector3(8, 2.6, -19), Vector3(21, 1.2, -6), "res://temp_town_market.png")
	await _shoot(camera, Vector3(-40, 2.0, -13), Vector3(-40, 2.0, -27), "res://temp_town_home.png")
	# What the player sees stepping out of their cottage door.
	await _shoot(camera, Vector3(-40, 1.65, -22.4), Vector3(-39, 1.5, 2), "res://temp_town_arrival.png")
	# The chapel green and the moved bakery / chapel cottage.
	await _shoot(camera, Vector3(-52, 34, 40), Vector3(-18, 1, 16), "res://temp_town_chapel.png")
	# The beekeeper district and the relocated abandoned houses.
	await _shoot(camera, Vector3(30, 34, -66), Vector3(38, 1, -36), "res://temp_town_north.png")
	# The north road gate out of the village.
	await _shoot(camera, Vector3(52, 5, -46), Vector3(52, 1.2, -62), "res://temp_town_gate.png")
	# The cemetery, with the two paths crossing the graves.
	await _shoot(camera, Vector3(8, 9, -50), Vector3(13, 0.5, -62), "res://temp_town_cemetery.png")

	town.queue_free()
	await get_tree().process_frame

	# The starting room, from the arrival point.
	var room: Node3D = ROOM_SCENE.instantiate()
	add_child(room)
	await get_tree().process_frame
	for layer_name in ["HUD", "PauseMenu", "HintPanel"]:
		var node := room.get_node_or_null(layer_name)
		if node is CanvasLayer or node is CanvasItem:
			node.visible = false
	if debug_overlay is CanvasLayer:
		debug_overlay.visible = false
	var room_camera := Camera3D.new()
	room_camera.fov = 65.0
	room.add_child(room_camera)
	room_camera.current = true
	await _shoot(room_camera, Vector3(0, 1.7, -8), Vector3(0, 1.2, 3), "res://temp_room_inside.png")
	await _shoot(room_camera, Vector3(3.5, 1.9, 4.5), Vector3(-1, 1.1, -6), "res://temp_room_corner.png")

	get_tree().quit()


func _shoot(camera: Camera3D, from: Vector3, to: Vector3, path: String) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("shot %s %dx%d error=%d" % [path, image.get_width(), image.get_height(), error])
