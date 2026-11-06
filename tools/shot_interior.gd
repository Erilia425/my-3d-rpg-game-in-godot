extends Node
## Throwaway: renders one room from each layout family so they can be eyeballed.
## Delete with tools/.

const ROOMS := [
	"res://features/world/interiors/rooms/chapel.tscn",
	"res://features/world/interiors/rooms/bell_tower.tscn",
	"res://features/world/interiors/rooms/honey_store.tscn",
	"res://features/world/interiors/rooms/hive_tower.tscn",
	"res://features/world/interiors/rooms/rowans_house.tscn",
	"res://features/world/interiors/rooms/abandoned_house.tscn",
	"res://features/world/interiors/bakery_interior.tscn",
]


func _ready() -> void:
	for path in ROOMS:
		await _shot_room(path)
	get_tree().quit()


func _shot_room(path: String) -> void:
	var room: Node3D = (load(path) as PackedScene).instantiate()
	add_child(room)
	await get_tree().process_frame

	for layer_name in ["HUD", "PauseMenu"]:
		var node := room.get_node_or_null(layer_name)
		if node is CanvasLayer or node is CanvasItem:
			node.visible = false
	var debug_overlay := get_node_or_null("/root/Debug")
	if debug_overlay is CanvasLayer:
		debug_overlay.visible = false

	var size: Vector2 = room.get("room_size")
	var camera := Camera3D.new()
	camera.fov = 72.0
	camera.far = 100.0
	room.add_child(camera)
	camera.current = true

	var label := path.get_file().get_basename()
	await _shoot(
		camera,
		Vector3(0, 1.65, size.y * 0.5 - 1.35),
		Vector3(0, 1.05, -size.y * 0.5 + 0.6),
		"res://temp_room_%s.png" % label
	)

	room.queue_free()
	await get_tree().process_frame


func _shoot(camera: Camera3D, from: Vector3, to: Vector3, path: String) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("shot %s %dx%d error=%d" % [path, image.get_width(), image.get_height(), error])
