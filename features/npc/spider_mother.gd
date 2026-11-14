class_name SpiderMother
extends QuestNpc
## The Spider Mother, drawn as what the lore says she is: a woman's body above,
## a spider's body below. Every other villager is a person in a coat, so her
## silhouette is the point — she should never read as another neighbour.
##
## `Npc` builds the primitive villager in `_build_model()`, and GDScript dispatch
## calls this override instead, so talking, gifts, schedules, and save data all
## keep working unchanged. Only the drawing is different.
##
## She is also the only flesh in the project that is a boss. The fight itself
## lives in `SpiderMotherBoss` (the `Boss` child in `spider_lair.tscn`); this
## script owns her body and the one place that can be hurt: the amber memory-sac
## where she keeps the honey that lets her memories walk around.

## Raised when anything strikes the memory-sac. The boss converts it into real
## damage, an interruption, and a stagger.
signal memory_sac_struck(amount: float)

const LEG_COUNT := 4
## Two shoulders' worth of arms are not enough for a mother of this many. Six,
## in three pairs: low and forward, middle and wide, high and raised.
const ARM_COUNT := 6
## Where the sac sits, in her own model space: the seam under the abdomen.
const SAC_POSITION := Vector3(0, 0.62, 0.42)

var _boss: SpiderMotherBoss
var _weak_point: StaticBody3D
var _sac_health: HealthComponent
var _sac_glow: OmniLight3D
var _sac_plates: Array[MeshInstance3D] = []
var _weak_open := false


func _ready() -> void:
	super()
	_boss = get_node_or_null("Boss") as SpiderMotherBoss


## The fight controller, when this Mother was placed with one.
func get_boss() -> SpiderMotherBoss:
	return _boss


## How many of her arms were built. Six for the Mother, and a test can tell.
func get_arm_count() -> int:
	var count := 0
	if _model == null:
		return count
	for child in _model.get_children():
		if String(child.name).begins_with("ArmUpper"):
			count += 1
	return count


## Opens or closes the plates over the memory-sac. While they are shut a blow
## still lands, but the silk takes it and nothing real gets through.
func set_weak_point_open(open: bool) -> void:
	if _weak_open == open:
		return

	_weak_open = open
	for plate in _sac_plates:
		if is_instance_valid(plate):
			plate.visible = not open
	if _sac_glow != null:
		_sac_glow.light_energy = 2.2 if open else 0.0


func is_weak_point_open() -> bool:
	return _weak_open


func get_interaction_text() -> String:
	if _boss != null and _boss.is_hostile():
		# Nothing to say while she is trying to kill you. An empty prompt also
		# clears the interaction ray's target.
		return ""
	if _boss != null and _boss.is_beaten():
		return "Spare the Spider Mother"
	return super()


func interact(interactor: Node) -> void:
	if _boss != null and _boss.is_hostile():
		_boss.speak_combat_line()
		return
	if _boss != null and _boss.is_beaten():
		_boss.spare()
		return
	super(interactor)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)

	var skin := _material(skin_color, 0.82)
	var hide := _material(coat_color.darkened(0.2), 0.95)
	var hide_dark := _material(coat_color.darkened(0.45), 0.98)
	var cloth := _material(trim_color, 0.9)
	var hair := _material(hair_color, 0.95)
	var thread := _material(Color(0.87, 0.85, 0.91, 1), 0.94)

	_build_spider_body(hide, hide_dark, thread)
	_build_torso(skin, cloth, hair, thread)
	_build_memory_sac(hide_dark)


## Abdomen, eight legs, and the join where the human half meets the spider half.
func _build_spider_body(hide: Material, hide_dark: Material, thread: Material) -> void:
	var abdomen := _sphere(_model, "Abdomen", Vector3(0, 0.95, 0.95), 0.74, hide)
	abdomen.scale = Vector3(1.12, 0.94, 1.4)

	# Pale markings: the Mother's web is part of her, so it shows on her back.
	for i in 4:
		var at := Vector3(0, 1.35 - i * 0.1, 0.75 + i * 0.28)
		var mark := _sphere(_model, "Marking%d" % i, at, 0.16 - i * 0.02, thread)
		mark.scale = Vector3(1.0, 0.4, 1.3)

	_sphere(_model, "Spinnerets", Vector3(0, 0.72, 1.72), 0.2, hide_dark)

	# Eight legs, four a side, each a hip-knee-foot chain. The pairs spread
	# backwards so the silhouette is wide and low, not a skirt.
	for side in [-1.0, 1.0]:
		for i in LEG_COUNT:
			var hip := Vector3(side * 0.36, 1.02, 0.5 - float(i) * 0.32)
			var knee := Vector3(side * (0.9 + float(i) * 0.1), 1.42, 0.62 - float(i) * 0.4)
			var foot := Vector3(side * (1.2 + float(i) * 0.16), 0.04, 0.7 - float(i) * 0.48)

			_strut("LegUpper%d_%d" % [0 if side < 0.0 else 1, i], hip, knee, 0.11, hide_dark)
			_strut("LegLower%d_%d" % [0 if side < 0.0 else 1, i], knee, foot, 0.08, hide_dark)
			_sphere(_model, "Joint%d_%d" % [0 if side < 0.0 else 1, i], knee, 0.1, hide)


func _build_torso(skin: Material, cloth: Material, hair: Material, thread: Material) -> void:
	var waist := _sphere(_model, "Waist", Vector3(0, 1.34, -0.12), 0.34, cloth)
	waist.scale = Vector3(1.0, 1.0, 0.9)
	_box(_model, "Torso", Vector3(0, 1.78, -0.16), Vector3(0.46, 0.66, 0.26), cloth)
	_box(_model, "Collar", Vector3(0, 2.08, -0.16), Vector3(0.32, 0.08, 0.24), thread)

	# A shawl of web over the shoulders.
	for side in [-1.0, 1.0]:
		_box(
			_model, "Shawl", Vector3(side * 0.2, 1.98, -0.02),
			Vector3(0.24, 0.5, 0.1), thread
		)

	_build_arms(cloth, skin)

	_sphere(_model, "Head", Vector3(0, 2.28, -0.16), 0.17, skin)
	var hair_mass := _sphere(_model, "Hair", Vector3(0, 2.36, -0.12), 0.18, hair)
	hair_mass.scale = Vector3(1.0, 0.7, 1.0)

	# Four small eyes: two where a person's are, two above them. Not a spider's
	# eight, because the face is still a woman's.
	var eye := _material(Color(0.06, 0.05, 0.06, 1), 0.6)
	for side in [-1.0, 1.0]:
		_box(_model, "Eye", Vector3(side * 0.065, 2.31, -0.32), Vector3(0.045, 0.05, 0.03), eye)
		_box(_model, "EyeHigh", Vector3(side * 0.055, 2.38, -0.31), Vector3(0.03, 0.03, 0.03), eye)


## Six arms in three pairs: low and forward (the ones that swipe), middle and
## wide (the ones that spread web), high and raised (the ones she never quite
## puts down).
func _build_arms(cloth: Material, skin: Material) -> void:
	var poses := [
		[Vector3(0.27, 1.88, -0.2), Vector3(0.5, 1.62, -0.34), Vector3(0.58, 1.36, -0.46)],
		[Vector3(0.31, 1.94, -0.08), Vector3(0.62, 1.86, 0.02), Vector3(0.76, 1.7, -0.04)],
		[Vector3(0.24, 2.02, -0.14), Vector3(0.44, 2.22, -0.22), Vector3(0.34, 2.38, -0.3)],
	]

	var index := 0
	for side in [-1.0, 1.0]:
		for pose in poses:
			var shoulder: Vector3 = pose[0]
			var elbow: Vector3 = pose[1]
			var hand: Vector3 = pose[2]
			shoulder.x *= side
			elbow.x *= side
			hand.x *= side
			_arm(index, shoulder, elbow, hand, cloth, skin)
			index += 1


func _arm(
	index: int, shoulder: Vector3, elbow: Vector3, hand: Vector3,
	cloth: Material, skin: Material
) -> void:
	_box(_model, "Shoulder%d" % index, shoulder, Vector3(0.16, 0.16, 0.16), cloth)
	_strut("ArmUpper%d" % index, shoulder, elbow, 0.12, cloth)
	_sphere(_model, "ArmElbow%d" % index, elbow, 0.08, cloth)
	_strut("ArmLower%d" % index, elbow, hand, 0.09, cloth)
	_sphere(_model, "Hand%d" % index, hand, 0.075, skin)


## The amber memory-sac: the honey that lets her memories walk about as children.
## It is the only soft place on her, and the only collider melee can find. While
## the silk plates are shut a blow lands on them instead; when she attacks, they
## pull back and the sac glows.
func _build_memory_sac(hide_dark: Material) -> void:
	var amber := _material(Color(0.82, 0.52, 0.16, 1), 0.34)
	amber.emission_enabled = true
	amber.emission = Color(0.95, 0.6, 0.18, 1)
	amber.emission_energy_multiplier = 1.2

	var sac := _sphere(_model, "MemorySac", SAC_POSITION, 0.33, amber)
	sac.scale = Vector3(1.0, 0.92, 1.05)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var plate := _box(
			_model, "SacPlate%d" % i,
			SAC_POSITION + Vector3(side * 0.13, 0.15, -0.14),
			Vector3(0.36, 0.32, 0.18), hide_dark
		)
		plate.rotation = Vector3(
			deg_to_rad(-16.0), deg_to_rad(side * 24.0), deg_to_rad(side * 14.0)
		)
		_sac_plates.append(plate)

	_sac_glow = OmniLight3D.new()
	_sac_glow.name = "SacGlow"
	_sac_glow.position = SAC_POSITION + Vector3(0, 0.05, 0.12)
	_sac_glow.light_color = Color(1.0, 0.68, 0.28, 1)
	_sac_glow.light_energy = 0.0
	_sac_glow.omni_range = 4.0
	_sac_glow.shadow_enabled = false
	_model.add_child(_sac_glow)

	_weak_point = StaticBody3D.new()
	_weak_point.name = "WeakPoint"
	# Enemy layer, so `AttackComponent`'s swing can find it and nothing else.
	_weak_point.collision_layer = 4
	_weak_point.collision_mask = 0
	_weak_point.add_to_group(&"enemy")
	_weak_point.position = SAC_POSITION

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.38
	shape.shape = sphere
	_weak_point.add_child(shape)
	_model.add_child(_weak_point)

	_sac_health = HealthComponent.new()
	_sac_health.name = "HealthComponent"
	# A trigger, not a second health pool: the handler tops it back up at once,
	# so it reports every blow and can never die.
	_sac_health.max_health = 9999.0
	_weak_point.add_child(_sac_health)
	_sac_health.set_health(9999.0)
	_sac_health.damaged.connect(_on_memory_sac_damaged)


func _on_memory_sac_damaged(amount: float) -> void:
	if _sac_health != null:
		_sac_health.set_health(_sac_health.max_health)
	memory_sac_struck.emit(amount)


## A box stretched between two points, so a limb is always attached at both ends
## whatever the pose.
func _strut(
	node_name: String, from: Vector3, to: Vector3, thickness: float, material: Material
) -> MeshInstance3D:
	var length := from.distance_to(to)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, maxf(length, 0.02))
	var at := (from + to) * 0.5
	var instance := _add_mesh(_model, node_name, mesh, at, material)
	var direction := to - from
	if direction.length_squared() > 0.0001:
		instance.transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), at)
	return instance
