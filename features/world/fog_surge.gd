extends Node3D
## Breath-driven fog surges: every so often the Hollow's mist thickens for a
## short while, then eases back. Ported in spirit from the 2D game's weather
## moods.
##
## A surge is watchful and dangerous. At its peak it drinks memory charge, frays
## silk, and sends something out of the white to find the player. The town stays
## cosy between surges, which is what makes going indoors worth doing. Set
## `dangerous = false` for the old atmosphere-only behaviour.
##
## The script looks for the scene's `WorldEnvironment` and `Sun` siblings, so it
## can be dropped into any exterior scene that has both. Missing nodes are
## ignored instead of crashing.

## Fog density while the air is calm.
@export var normal_density: float = 0.0022
## Fog density at the peak of a surge.
@export var surge_density: float = 0.012
## Seconds of calm between surges.
@export var calm_min: float = 45.0
@export var calm_max: float = 100.0
## Seconds a surge takes to rise and to fall again.
@export var fade_time: float = 6.0
## Seconds the fog stays thick between the rise and the fall.
@export var hold_time: float = 14.0
## How much the sun dims at the peak (0 = no change, 1 = fully dim).
@export var sun_dim: float = 0.45
## Show a soft line of flavour text the first time a surge begins.
@export var whisper: bool = true

@export_group("Danger")
## A surge is not only weather. While the mist holds it drinks memory charge,
## frays silk, and something out in the fog comes looking. Turning this off
## restores the old atmosphere-only behaviour.
@export var dangerous: bool = true
## Memory charge lost per second while the fog is at its thickest.
@export var memory_drain_per_second: float = 3.0
## Silk frayed per second while the fog is at its thickest. Silk never protects
## the player from damage; the mist is simply harder to hold anything in.
@export var silk_drain_per_second: float = 1.0
## What the mist sends. Empty disables summoning but keeps the drain.
@export var summon_scene: PackedScene = preload("res://features/combat/guest.tscn")
@export var summon_interval: float = 7.0
## At most this many fog creatures can be alive at once, so a long surge cannot
## bury the town in them.
@export var max_summons: int = 3
## How far from the player a fog creature steps out of the mist.
@export var summon_distance_min: float = 12.0
@export var summon_distance_max: float = 17.0

var _environment: Environment
var _sun: DirectionalLight3D
var _sun_energy: float = 1.0
var _time_left: float = 0.0
var _phase: int = 0  # 0 = calm, 1 = rising, 2 = holding, 3 = falling
var _phase_time: float = 0.0
var _whispered: bool = false
var _summon_timer: float = 0.0
var _summoned: Array[Node] = []
var _heard_the_mist: bool = false


func _ready() -> void:
	var world_env := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		# Duplicate so runtime fog changes never write back to the scene file.
		_environment = world_env.environment.duplicate()
		world_env.environment = _environment
		_environment.fog_density = normal_density

	_sun = get_node_or_null("../Sun") as DirectionalLight3D
	if _sun != null:
		_sun_energy = _sun.light_energy

	_time_left = randf_range(calm_min, calm_max)


func _process(delta: float) -> void:
	if _environment == null:
		return

	match _phase:
		0:
			_time_left -= delta
			if _time_left <= 0.0:
				_begin_surge()
		1:
			_phase_time += delta
			var t := clampf(_phase_time / fade_time, 0.0, 1.0)
			_apply(lerpf(normal_density, surge_density, t), t)
			if t >= 1.0:
				_phase = 2
				_phase_time = 0.0
		2:
			_phase_time += delta
			if dangerous:
				_haunt(delta)
			if _phase_time >= hold_time:
				_phase = 3
				_phase_time = 0.0
		3:
			_phase_time += delta
			var t := clampf(_phase_time / fade_time, 0.0, 1.0)
			_apply(lerpf(surge_density, normal_density, t), 1.0 - t)
			if t >= 1.0:
				_phase = 0
				_time_left = randf_range(calm_min, calm_max)


func _begin_surge() -> void:
	_phase = 1
	_phase_time = 0.0
	# The fog is a single weather event, not a standing army: each surge starts
	# its own count so last night's bodies do not use up tonight's welcome.
	_summoned.clear()
	_summon_timer = summon_interval * 0.5
	if whisper and not _whispered:
		_whispered = true
		Events.notification_requested.emit("The mist leans close, listening.")
	else:
		Events.notification_requested.emit("The mist comes in thick. Do not stand in it.")


## Starts a surge on demand, for tests and future scripted weather beats.
func force_surge() -> void:
	_begin_surge()


## True when this surge is allowed to bite.
func is_dangerous() -> bool:
	return dangerous


## Living fog creatures spawned by this surge.
func get_summon_count() -> int:
	return _living_summons()


## The mist's teeth: it drinks the player's memory charge, frays the silk holding
## it together, and now and then something walks out of the white.
func _haunt(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return

	var stats := player.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		if memory_drain_per_second > 0.0:
			stats.set_memory(
				maxf(stats.get_memory() - memory_drain_per_second * delta, 0.0)
			)
		if silk_drain_per_second > 0.0:
			stats.damage_silk(silk_drain_per_second * delta)

	_summon_timer -= delta
	if _summon_timer > 0.0 or summon_scene == null:
		return
	_summon_timer = summon_interval
	if _living_summons() >= max_summons:
		return

	var spot := _mist_spot(player)
	if spot == Vector3.INF:
		return

	var parent := get_parent()
	if parent == null:
		return
	var creature := summon_scene.instantiate() as Node3D
	parent.add_child(creature)
	creature.global_position = spot
	_summoned.append(creature)

	if not _heard_the_mist:
		_heard_the_mist = true
		Events.notification_requested.emit("Something else is walking in the mist.")


## A point on open ground at a middle distance from the player. A creature that
## steps out inside a wall can never reach anybody, so the spot is tested against
## the real world colliders before it is used.
func _mist_spot(player: Node3D) -> Vector3:
	var space := get_world_3d().direct_space_state
	for attempt in 8:
		var angle := randf() * TAU
		var distance := randf_range(summon_distance_min, summon_distance_max)
		var at := player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

		var from := Vector3(at.x, at.y + 3.0, at.z)
		var to := Vector3(at.x, at.y - 3.0, at.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if hit.is_empty():
			continue

		var ground: Vector3 = hit["position"]
		var probe := SphereShape3D.new()
		probe.radius = 0.6
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.transform = Transform3D(Basis(), ground + Vector3(0, 1.0, 0))
		query.collision_mask = 1
		if not space.intersect_shape(query, 1).is_empty():
			continue

		return ground + Vector3(0, 0.05, 0)
	return Vector3.INF


func _living_summons() -> int:
	var living := 0
	for i in range(_summoned.size() - 1, -1, -1):
		var node := _summoned[i]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_summoned.remove_at(i)
			continue
		living += 1
	return living


## Sets the calm-weather fog density. `Weather` calls this when the day turns
## rainy or misty, so the two systems share one number instead of each writing
## `environment.fog_density` behind the other's back. While a surge is running the
## new value is picked up by the next transition; while calm it is applied at once.
func set_base_density(density: float) -> void:
	normal_density = density
	if _environment != null and _phase == 0:
		_environment.fog_density = density


func _apply(density: float, strength: float) -> void:
	_environment.fog_density = density
	if _sun != null:
		_sun.light_energy = lerpf(_sun_energy, _sun_energy * (1.0 - sun_dim), strength)