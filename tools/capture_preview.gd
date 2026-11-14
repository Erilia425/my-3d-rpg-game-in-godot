extends SceneTree
## Development helper: loads a scene, lets it settle, and saves a screenshot.
## Run headful (not --headless) so the GPU draws the frame:
##   godot --path . --script res://tools/capture_preview.gd
##
## Entry: [scene, label, hour, camera_position, camera_target]
## hour < 0 leaves the clock alone. Camera entries may be null to use the
## scene's own player camera.

const SHOTS: Array = [
	["res://features/world/interiors/rooms/garden_cottage.tscn", "garden_cottage", -1.0, null, null],
	["res://features/world/interiors/rooms/beekeeper_cottage.tscn", "beekeeper_cottage", 21.0, null, null],
	["res://scenes/town.tscn", "town_thatch", 10.0, Vector3(60, 2.4, -19), Vector3(60, 0.9, -26)],
	["res://scenes/town.tscn", "town_spiders", 10.0, Vector3(52, 1.8, 30), Vector3(60, 0.4, 41)],
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 540)
	for shot in SHOTS:
		await _capture(shot[0], shot[1], shot[2], shot[3], shot[4])
	quit()


func _capture(path: String, label: String, hour: float,
		camera_position, camera_target) -> void:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	if hour >= 0.0:
		WorldClock.hour = hour

	var camera: Camera3D = null
	if camera_position != null:
		camera = Camera3D.new()
		root.add_child(camera)
		camera.global_position = camera_position
		camera.look_at(camera_target, Vector3.UP)
		camera.fov = 70.0
		camera.make_current()

	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var out := "C:/Users/summe/AppData/Local/Temp/opencode/preview_%s.png" % label
	image.save_png(out)
	print("saved ", out, " ", image.get_size())

	if camera != null:
		camera.queue_free()
	root.remove_child(scene)
	scene.free()
	await process_frame
