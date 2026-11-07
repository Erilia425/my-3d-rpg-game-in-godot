class_name Npc
extends CharacterBody3D
## One villager, assembled from primitives so a new face is a scene instance
## with a few exported colours instead of a new model.
##
## Villagers join the `interactable` group and sit on the world + npc +
## interactable collision layers, so the interaction ray finds them and the
## player bumps into them. Talking only announces a line through the event bus;
## a full dialogue panel is a later feature. See AGENTS.md sections 4 and 6.

enum HatStyle {
	NONE,
	WIDE_BRIM,
	BEEKEEPER_VEIL,
}

const GRAVITY := 18.0
## Stop within this distance of a wander point.
const ARRIVE_DISTANCE := 0.45
## Give up on a wander point after this long, so a blocked villager never walks
## into a wall forever.
const WANDER_TIMEOUT := 14.0
## World + npc + interactable, the layer set in npc.tscn.
const ACTIVE_COLLISION_LAYER := 25
const SCHEDULE_CHECK_INTERVAL := 0.5

@export_group("Identity")
@export var npc_name: String = "Villager"
@export var role: String = ""
@export_multiline var greeting_lines: PackedStringArray = PackedStringArray(
	["Good day to you."]
)

@export_group("Look")
## Optional animated 2D portrait cut from the Mycelgrove Hollow art. When set,
## the villager is drawn as an AnimatedSprite3D billboard instead of the
## primitive body. Takes priority over `sprite_texture`.
@export var sprite_frames: SpriteFrames
## Animation names inside `sprite_frames` used while standing and walking.
## Only switched to when the resource actually holds that animation.
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
## Optional single 2D portrait cut from the Mycelgrove Hollow art. When set, the
## villager is drawn as one sprite billboard instead of the primitive body, so
## the 2D game's character art appears in the 3D street unchanged. Ignored when
## `sprite_frames` is set.
@export var sprite_texture: Texture2D
@export var coat_color: Color = Color(0.42, 0.35, 0.26, 1)
@export var trim_color: Color = Color(0.72, 0.6, 0.38, 1)
@export var skin_color: Color = Color(0.83, 0.67, 0.51, 1)
@export var hair_color: Color = Color(0.28, 0.19, 0.12, 1)
@export var has_apron: bool = false
@export var has_blindfold: bool = false
@export var long_skirt: bool = false
@export var hat_style: HatStyle = HatStyle.NONE
@export var facing_degrees: float = 0.0

@export_group("Behaviour")
@export var wander: bool = false
## World-space points walked between, in order and then looping.
@export var wander_points: PackedVector3Array = PackedVector3Array()
@export var walk_speed: float = 1.5
@export var pause_at_points: float = 2.5

@export_group("Schedule")
## When true the villager only exists between these hours on the 24h clock.
## One placement can be the home (night) and another the daytime spot.
@export var scheduled: bool = false
@export var active_from_hour: int = 8
@export var active_to_hour: int = 18

var _target_index := 0
var _rest := 0.0
var _travel_time := 0.0
var _active := true
var _schedule_check := 0.0
var _label: Label3D
var _role_label: Label3D
var _model: Node3D
var _anim_sprite: AnimatedSprite3D
var _playing_walk := false


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"npc")
	rotation.y = deg_to_rad(facing_degrees)
	_build_model()
	_build_labels()
	_update_schedule(true)


func _physics_process(delta: float) -> void:
	if scheduled:
		_schedule_check -= delta
		if _schedule_check <= 0.0:
			_schedule_check = SCHEDULE_CHECK_INTERVAL
			_update_schedule()
		if not _active:
			return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if Game.state == Game.State.PLAYING and wander and wander_points.size() > 0:
		_wander(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)

	move_and_slide()
	_update_sprite_animation()


# --- schedule --------------------------------------------------------------


## Shows or hides this placement from the current world hour. Hidden villagers
## keep their physics tick only so they can come back; they are not drawn and
## their collision layer is cleared, so they cannot be seen or interacted with.
func _update_schedule(force: bool = false) -> void:
	if not scheduled:
		return

	var should_be_active := _hour_in_window(WorldClock.get_hour())
	if not force and should_be_active == _active:
		return

	_active = should_be_active
	visible = _active
	collision_layer = ACTIVE_COLLISION_LAYER if _active else 0
	if not _active:
		velocity = Vector3.ZERO
		_rest = 0.0


func _hour_in_window(hour: float) -> bool:
	var start := float(active_from_hour)
	var end := float(active_to_hour)
	if start == end:
		return true
	if start < end:
		return hour >= start and hour < end
	# The window crosses midnight, e.g. 18:00 -> 08:00.
	return hour >= start or hour < end


func is_scheduled_active() -> bool:
	return _active


# --- talking ---------------------------------------------------------------


func get_interaction_text() -> String:
	return "Talk to %s" % npc_name


func interact(interactor: Node) -> void:
	if interactor is Node3D:
		_face(interactor as Node3D)

	if greeting_lines.is_empty():
		return

	Events.dialogue_requested.emit(npc_name, role, greeting_lines)


func _face(target: Node3D) -> void:
	var flat := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	if flat.distance_to(global_position) < 0.05:
		return
	var direction := (flat - global_position).normalized()
	rotation.y = atan2(-direction.x, -direction.z)


# --- wandering -------------------------------------------------------------


func _wander(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		return

	var target := wander_points[_target_index]
	var to_target := target - global_position
	to_target.y = 0.0

	if to_target.length() <= ARRIVE_DISTANCE or _travel_time >= WANDER_TIMEOUT:
		_travel_time = 0.0
		_rest = pause_at_points
		_target_index = (_target_index + 1) % wander_points.size()
		return

	_travel_time += delta
	var direction := to_target.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(7.0 * delta, 0.0, 1.0))


# --- look ------------------------------------------------------------------


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	if sprite_frames != null:
		_build_animated_sprite()
		return

	if sprite_texture != null:
		_build_sprite()
		return

	var coat := _material(coat_color, 0.95)
	var coat_dark := _material(coat_color.darkened(0.28), 0.95)
	var trim := _material(trim_color, 0.92)
	var skin := _material(skin_color, 0.85)
	var hair := _material(hair_color, 0.95)
	var dark := _material(Color(0.12, 0.1, 0.08, 1), 0.9)
	var boots := _material(Color(0.22, 0.16, 0.11, 1), 0.95)

	if long_skirt:
		_cylinder(_model, "Skirt", Vector3(0, 0.42, 0), 0.3, 0.42, 0.84, coat)
	else:
		for side in [-1.0, 1.0]:
			_box(_model, "Leg", Vector3(side * 0.11, 0.38, 0), Vector3(0.17, 0.7, 0.2), coat_dark)
			_box(_model, "Boot", Vector3(side * 0.11, 0.07, -0.03), Vector3(0.19, 0.14, 0.28), boots)

	_box(_model, "Torso", Vector3(0, 1.02, 0), Vector3(0.5, 0.62, 0.29), coat)
	_box(_model, "Collar", Vector3(0, 1.34, 0), Vector3(0.34, 0.08, 0.26), trim)

	for side in [-1.0, 1.0]:
		_box(_model, "Arm", Vector3(side * 0.32, 1.04, 0), Vector3(0.14, 0.58, 0.17), coat_dark)
		_sphere(_model, "Hand", Vector3(side * 0.32, 0.73, 0), 0.075, skin)

	if has_apron:
		_box(_model, "Apron", Vector3(0, 1.0, -0.16), Vector3(0.42, 0.56, 0.03), trim)
		_box(_model, "ApronStrap", Vector3(0, 1.28, -0.16), Vector3(0.1, 0.18, 0.03), trim)

	_sphere(_model, "Head", Vector3(0, 1.6, 0), 0.17, skin)
	_sphere(_model, "Hair", Vector3(0, 1.68, 0.02), 0.18, hair).scale = Vector3(1.0, 0.72, 1.0)

	if has_blindfold:
		_box(_model, "Blindfold", Vector3(0, 1.63, -0.145), Vector3(0.36, 0.1, 0.05), dark)
		_box(_model, "BlindfoldStrapL", Vector3(-0.165, 1.63, 0.0), Vector3(0.05, 0.1, 0.3), dark)
		_box(_model, "BlindfoldStrapR", Vector3(0.165, 1.63, 0.0), Vector3(0.05, 0.1, 0.3), dark)
	else:
		for side in [-1.0, 1.0]:
			_box(_model, "Eye", Vector3(side * 0.065, 1.63, -0.16), Vector3(0.045, 0.045, 0.03), dark)

	match hat_style:
		HatStyle.WIDE_BRIM:
			_cylinder(_model, "HatBrim", Vector3(0, 1.79, 0), 0.31, 0.31, 0.05, trim)
			_cylinder(_model, "HatCrown", Vector3(0, 1.9, 0), 0.16, 0.18, 0.2, trim)
		HatStyle.BEEKEEPER_VEIL:
			_cylinder(
				_model, "Veil", Vector3(0, 1.71, 0),
				0.2, 0.32, 0.46, _material(Color(0.86, 0.85, 0.74, 1), 1.0)
			)
			_cylinder(_model, "VeilBand", Vector3(0, 1.58, 0), 0.21, 0.22, 0.04, trim)
			_cylinder(_model, "HatBrim", Vector3(0, 1.96, 0), 0.33, 0.33, 0.05, trim)
			_cylinder(_model, "HatCrown", Vector3(0, 2.07, 0), 0.15, 0.17, 0.18, trim)


## One camera-facing billboard, scaled so the villager is about 1.9 m tall.
## Nearest-neighbour filtering keeps the pixel art crisp. The primitive body is
## skipped entirely when a texture is supplied.
func _build_sprite() -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = sprite_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = 1.9 / float(sprite_texture.get_height())
	sprite.position = Vector3(0, 0.95, 0)
	_model.add_child(sprite)


## Same billboard look as `_build_sprite`, driven by a `SpriteFrames` resource so
## animated characters have a real frame pipeline. Frame height sets the scale so
## every villager stays about 1.9 m tall whatever the source art size.
func _build_animated_sprite() -> void:
	var start_animation := _first_animation()
	if start_animation == &"":
		push_warning("Npc '%s' has SpriteFrames with no animations." % npc_name)
		return

	var height := _frame_height(start_animation)

	var sprite := AnimatedSprite3D.new()
	sprite.name = "AnimatedSprite"
	sprite.sprite_frames = sprite_frames
	sprite.animation = start_animation
	sprite.frame = 0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.pixel_size = 1.9 / float(maxi(height, 1))
	sprite.position = Vector3(0, 0.95, 0)
	sprite.play(start_animation)
	_model.add_child(sprite)
	_anim_sprite = sprite


## Chooses the idle or walk clip from horizontal speed, but only if the
## SpriteFrames resource actually contains that animation. Missing clips leave
## the current one playing, so a single-frame resource is harmless.
func _update_sprite_animation() -> void:
	if _anim_sprite == null or sprite_frames == null:
		return

	var moving := Vector2(velocity.x, velocity.z).length() > 0.15
	if moving == _playing_walk:
		return

	var wanted := walk_animation if moving else idle_animation
	if not sprite_frames.has_animation(wanted):
		return

	if wanted == _anim_sprite.animation:
		return

	_playing_walk = moving
	_anim_sprite.play(wanted)


func _first_animation() -> StringName:
	if sprite_frames == null:
		return &""
	if sprite_frames.has_animation(idle_animation):
		return idle_animation
	var names := sprite_frames.get_animation_names()
	if names.is_empty():
		return &""
	return StringName(names[0])


func _frame_height(animation: StringName) -> int:
	if sprite_frames == null:
		return 0
	if not sprite_frames.has_animation(animation):
		return 0
	var count := sprite_frames.get_frame_count(animation)
	if count <= 0:
		return 0
	var texture := sprite_frames.get_frame_texture(animation, 0)
	if texture == null:
		return 0
	return texture.get_height()


func _build_labels() -> void:
	# A hat or veil makes the head taller, so lift the name clear of it.
	var rise := 0.38 if hat_style != HatStyle.NONE else 0.0

	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.text = npc_name
	_label.position = Vector3(0, 2.34 + rise, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 44
	_label.pixel_size = 0.0035
	_label.outline_size = 16
	_label.outline_modulate = Color(0.09, 0.06, 0.04, 0.92)
	_label.modulate = Color(0.98, 0.93, 0.8, 1)
	add_child(_label)

	if role.is_empty():
		return

	_role_label = Label3D.new()
	_role_label.name = "RoleLabel"
	_role_label.text = role
	_role_label.position = Vector3(0, 2.08 + rise, 0)
	_role_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_role_label.font_size = 22
	_role_label.pixel_size = 0.0032
	_role_label.outline_size = 12
	_role_label.outline_modulate = Color(0.09, 0.06, 0.04, 0.92)
	_role_label.modulate = Color(0.82, 0.76, 0.62, 1)
	add_child(_role_label)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, node_name, mesh, at, material)


func _sphere(parent: Node3D, node_name: String, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh(parent, node_name, mesh, at, material)


func _cylinder(
	parent: Node3D, node_name: String, at: Vector3,
	top_radius: float, bottom_radius: float, height: float, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return _add_mesh(parent, node_name, mesh, at, material)


func _add_mesh(
	parent: Node3D, node_name: String, mesh: Mesh, at: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance
