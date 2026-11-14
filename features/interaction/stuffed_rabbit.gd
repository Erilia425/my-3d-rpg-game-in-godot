class_name StuffedRabbit
extends StaticBody3D
## Little Eli's rabbit, which he calls Mister Rabbit.
##
## It is stitched from patchwork and sits where he leaves it. It also breathes,
## very slightly, and it always ends up facing whoever stands close — including
## when they were looking somewhere else a moment ago. Nothing in the game says
## why. That is deliberate: the Hollow answers children's wishes, and this one
## has been answered quietly.
##
## The root is the `StaticBody3D` on purpose. The interaction ray checks the
## collider it hits for the `interactable` group and the two interaction methods,
## and the collider here is the rabbit itself.

@export var rabbit_name: String = "Mister Rabbit"
@export_multiline var examine_lines: PackedStringArray = PackedStringArray(
	[
		"A stuffed rabbit, stitched from grey cloth and a red button.",
		"It is warm. It was not warm a moment ago.",
		"One ear has been sewn back on more than once.",
	]
)
## The rabbit turns to face anyone closer than this. It never turns back.
@export var notice_distance: float = 3.5
@export var turn_speed: float = 1.6

var _body: Node3D
var _player: Node3D
var _breath := 0.0
var _turned := false


func _ready() -> void:
	add_to_group(&"interactable")
	_build()
	_make_collision()
	set_process(true)


func get_interaction_text() -> String:
	return "Look at %s" % rabbit_name


func interact(interactor: Node) -> void:
	if interactor is Node3D:
		_face(interactor as Node3D, 1.0)
	if examine_lines.is_empty():
		return
	Events.dialogue_requested.emit(rabbit_name, "", examine_lines)


func _process(delta: float) -> void:
	if _body == null:
		return

	# A shallow breath, slow enough that a glance might miss it.
	_breath += delta * 1.4
	_body.scale = Vector3(1.0, 1.0 + sin(_breath) * 0.014, 1.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return

	var flat := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
	var distance := flat.distance_to(global_position)
	if distance > notice_distance or distance < 0.05:
		return

	_turned = true
	_face(_player, clampf(turn_speed * delta, 0.0, 1.0))


## Turns the rabbit so its front faces `target`. Which is not the same as facing
## the camera: stand behind it and it comes round to look at you.
func _face(target: Node3D, weight: float) -> void:
	var flat := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	var to_target := flat - global_position
	if to_target.length_squared() < 0.0004:
		return
	var wanted := atan2(-to_target.x, -to_target.z)
	rotation.y = lerp_angle(rotation.y, wanted, clampf(weight, 0.0, 1.0))


# --- art -------------------------------------------------------------------


func _build() -> void:
	_body = Node3D.new()
	_body.name = "RabbitBody"
	add_child(_body)

	var fur := _material(Color(0.66, 0.63, 0.58, 1), 0.96)
	var fur_dark := _material(Color(0.47, 0.44, 0.41, 1), 0.97)
	var patch := _material(Color(0.55, 0.35, 0.3, 1), 0.95)
	var thread := _material(Color(0.24, 0.21, 0.19, 1), 0.9)
	var button := _material(Color(0.42, 0.1, 0.09, 1), 0.4)

	# Body and head, low and rounded, the way a soft toy slumps.
	var body := _sphere("Body", Vector3(0, 0.2, 0), 0.2, 0.36, fur)
	body.scale = Vector3(1.0, 1.05, 0.9)
	_sphere("Head", Vector3(0, 0.42, -0.09), 0.15, 0.29, fur)
	_sphere("Muzzle", Vector3(0, 0.38, -0.22), 0.07, 0.12, fur_dark)
	_sphere("Nose", Vector3(0, 0.405, -0.265), 0.028, 0.05, thread)

	# Ears: one straight, one flopped, because it has been mended.
	var ear_left := _box("EarLeft", Vector3(-0.06, 0.66, -0.07), Vector3(0.06, 0.26, 0.03), fur)
	ear_left.rotation = Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(-9.0))
	var ear_right := _box("EarRight", Vector3(0.09, 0.6, -0.03), Vector3(0.06, 0.22, 0.03), fur_dark)
	ear_right.rotation = Vector3(deg_to_rad(-38.0), 0.0, deg_to_rad(34.0))

	# A patched belly and visible stitches.
	var belly := _sphere("BellyPatch", Vector3(0, 0.16, -0.15), 0.11, 0.19, patch)
	belly.scale = Vector3(1.0, 1.0, 0.5)
	for i in 3:
		_box(
			"Stitch%d" % i, Vector3(-0.05 + float(i) * 0.05, 0.22 + float(i) * 0.01, -0.2),
			Vector3(0.012, 0.05, 0.012), thread
		)

	# Button eyes: only one is sewn on properly.
	_sphere("EyeLeft", Vector3(-0.06, 0.46, -0.2), 0.025, 0.045, button)
	_sphere("EyeRight", Vector3(0.065, 0.455, -0.19), 0.02, 0.036, thread)

	# Legs and paws.
	for side in [-1.0, 1.0]:
		_sphere("Paw", Vector3(side * 0.13, 0.06, -0.1), 0.07, 0.11, fur_dark)
	_sphere("Tail", Vector3(0, 0.18, 0.17), 0.06, 0.1, fur_dark)


func _make_collision() -> void:
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 0.62, 0.42)
	shape.shape = box
	shape.position = Vector3(0, 0.34, 0)
	add_child(shape)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	return made


func _box(
	node_name: String, at: Vector3, size: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(node_name, mesh, at, material)


func _sphere(
	node_name: String, at: Vector3, radius: float, height: float, material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 6
	return _add(node_name, mesh, at, material)


func _add(
	node_name: String, mesh: Mesh, at: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	_body.add_child(instance)
	return instance
