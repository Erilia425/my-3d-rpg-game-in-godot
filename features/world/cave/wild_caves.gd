class_name WildCaves
extends Node3D
## A cave under the Hollow that is a different cave every time the player enters.
##
## The Old Adit (`mine_cave.gd`) stays a hand-cut, stable mine with fixed seams
## and save ids. This is the wild rock: chambers are laid out with a fresh random
## seed on every entry, joined by wide natural passages, and nothing inside is
## persisted, because a cave that changes shape should not remember what you
## mined in a shape that no longer exists.
##
## The shell is built from overlapping circles. A chamber's wall is only placed
## where the boundary is not already inside a neighbour, so two circles that
## overlap leave a passage instead of a wall. That one rule is the whole cave:
## no corridor meshes, no doorway authoring, and no way to generate a sealed room
## or a hole into empty space.
##
## `spider_lair.tscn` reuses the same generator with a fixed seed, because the
## Spider Mother's lair should not move between visits.

const GATHER_SCENE := preload("res://features/gathering/gather_node.tscn")
const SPIDER_SCENE := preload("res://features/combat/ghost_spider.tscn")
const EXIT_SCRIPT := preload("res://features/world/interiors/interior_exit.gd")

const HEIGHT := 4.4
## Wall blocks are axis-aligned on purpose: their collision matches their art
## exactly, and a ring of jagged blocks reads as cut rock. Spacing around a
## circle is about 1.6 m, so blocks this wide always overlap.
const WALL_BLOCK := Vector3(2.6, HEIGHT, 1.9)

@export var fixed_seed: int = 0
@export var chamber_min: int = 4
@export var chamber_max: int = 7
@export var spider_count: int = 3
@export var seam_count: int = 4
## The lair is a fixed, dressed version of the same generator: violet web light,
## strands, sacs, and no random seams to distract from the Mother.
@export var is_lair: bool = false

var _rng := RandomNumberGenerator.new()
var _chambers: Array[Dictionary] = []
## The lair's arena: the far chamber, kept clear of boulders, where the Mother
## waits. Empty in a wild cave.
var _arena: Dictionary = {}
var _spawn := Vector3.ZERO
var _cave_seed := 0
var _wall_blocks := 0
var _rock: StandardMaterial3D
var _rock_dark: StandardMaterial3D
var _floor: StandardMaterial3D
var _iron: StandardMaterial3D
var _gem: StandardMaterial3D
var _glow: StandardMaterial3D
var _web: StandardMaterial3D
var _daylight: StandardMaterial3D


func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_cave_seed = fixed_seed if fixed_seed != 0 else _fresh_seed()
	_rng.seed = _cave_seed

	_materials()
	_environment()
	_chambers = _layout()
	if is_lair:
		_plan_lair_arena()
	_floors()
	_walls()
	_details()
	_lights()
	_seams()
	_enemies()
	if is_lair:
		_web_dressing()
		_lair_dressing()
	_exit_portal()
	_place_player()

	TownParts.merge_children(self)
	# The Mother is a node, not geometry, so she is positioned after the merge.
	if is_lair:
		_lair_stage()


## Unix time mixed with a frame-time-based integer, so two entries in the same
## second still differ. No save field is written: the cave simply is what it is
## this visit.
func _fresh_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) ^ randi()


# --- read-only view, for tests and tools -----------------------------------


## The seed this cave was built from. Two visits to `wild_caves.tscn` differ;
## the lair's fixed seed never does.
func get_cave_seed() -> int:
	return _cave_seed


func get_chamber_count() -> int:
	return _chambers.size()


## How many rock blocks make up the chamber walls. Merged meshes hide them, so
## this counter is the only way to check a cave was actually built.
func get_wall_count() -> int:
	return _wall_blocks


# --- materials -------------------------------------------------------------


func _materials() -> void:
	var tint := Color(0.2, 0.18, 0.24, 1) if is_lair else Color(0.26, 0.25, 0.23, 1)
	_rock = TownParts.material(tint, 0.99)
	_rock_dark = TownParts.material(tint.darkened(0.45), 1.0)
	_floor = TownParts.material(tint.darkened(0.18), 1.0)
	_iron = TownParts.material(Color(0.7, 0.42, 0.2, 1), 0.7)
	_gem = TownParts.material(Color(0.55, 0.78, 0.9, 1), 0.3, 1.2)
	_glow = TownParts.material(Color(0.72, 0.66, 1.0, 1), 0.5, 2.4)
	_web = TownParts.material(Color(0.82, 0.8, 0.86, 0.72), 0.95)
	_web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_web.cull_mode = BaseMaterial3D.CULL_DISABLED
	_daylight = TownParts.material(Color(1.0, 0.93, 0.74, 1), 0.6, 2.2)


func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.008, 0.012, 1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.19, 0.17, 0.22, 1)
	environment.ambient_light_energy = 0.16
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.06, 0.055, 0.07, 1)
	environment.fog_density = 0.05
	environment.fog_sky_affect = 0.0

	var world := WorldEnvironment.new()
	world.name = "CaveEnvironment"
	world.environment = environment
	add_child(world)


# --- layout ----------------------------------------------------------------


## A random walk of circles. Each new chamber overlaps the previous one by three
## to four and a half metres, which is always wider than a player's shoulders.
func _layout() -> Array[Dictionary]:
	var chambers: Array[Dictionary] = []
	var count := _rng.randi_range(chamber_min, chamber_max)
	var radius := _rng.randf_range(7.0, 9.0)
	var centre := Vector2.ZERO
	chambers.append({"centre": centre, "radius": radius})

	var heading := _rng.randf() * TAU
	for i in range(1, count):
		heading += _rng.randf_range(-1.0, 1.0)
		var next_radius := _rng.randf_range(5.0, 8.5)
		var step := radius + next_radius - _rng.randf_range(3.4, 4.8)
		centre += Vector2(cos(heading), sin(heading)) * step
		chambers.append({"centre": centre, "radius": next_radius})
		radius = next_radius

	return chambers


func _bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for chamber in _chambers:
		var centre: Vector2 = chamber["centre"]
		var radius: float = chamber["radius"] + 2.0
		min_point = min_point.min(centre - Vector2(radius, radius))
		max_point = max_point.max(centre + Vector2(radius, radius))
	return Rect2(min_point, max_point - min_point)


func _floors() -> void:
	var bounds := _bounds()
	var middle := bounds.position + bounds.size * 0.5
	var size := Vector3(bounds.size.x, 0.6, bounds.size.y)

	# One floor and one ceiling for the whole cave. The walls hide the overhang.
	TownParts.box(self, "CaveFloor", Vector3(middle.x, -0.3, middle.y), size, _floor)
	TownParts.collision(self, size, Vector3(middle.x, -0.3, middle.y))
	TownParts.box(self, "CaveCeiling", Vector3(middle.x, HEIGHT + 0.3, middle.y), size, _rock)
	TownParts.collision(self, size, Vector3(middle.x, HEIGHT + 0.3, middle.y))


## Ring of rock blocks around every chamber, minus the arcs that fall inside a
## neighbour. This is what turns overlapping circles into a connected cave.
func _walls() -> void:
	for index in _chambers.size():
		var chamber := _chambers[index]
		var centre: Vector2 = chamber["centre"]
		var radius: float = chamber["radius"]
		var segments := maxi(12, int(radius * 4.0))
		for step in segments:
			var angle := TAU * float(step) / float(segments)
			var point := centre + Vector2(cos(angle), sin(angle)) * radius
			if _inside_other(point, index):
				continue
			TownParts.box(
				self, "Wall%d_%d" % [index, step],
				Vector3(point.x, HEIGHT * 0.5, point.y), WALL_BLOCK, _rock
			)
			TownParts.collision(
				self, WALL_BLOCK, Vector3(point.x, HEIGHT * 0.5, point.y)
			)
			_wall_blocks += 1


func _inside_other(point: Vector2, skip: int) -> bool:
	for index in _chambers.size():
		if index == skip:
			continue
		var other := _chambers[index]
		if point.distance_to(other["centre"]) < float(other["radius"]) - 0.4:
			return true
	return false


## A floor point inside a chamber, kept away from the wall by `edge` (0 centre,
## 1 wall).
func _spot(index: int, edge: float) -> Vector2:
	var chamber := _chambers[index]
	var centre: Vector2 = chamber["centre"]
	var radius: float = chamber["radius"]
	var angle := _rng.randf() * TAU
	return centre + Vector2(cos(angle), sin(angle)) * radius * edge


func _add_body(
	node_name: String, at: Vector3, radius: float, height: float, mat: Material
) -> MeshInstance3D:
	return TownParts.sphere(self, node_name, at, radius, height, mat)


# --- detail ----------------------------------------------------------------


func _details() -> void:
	var boulders := 0
	var spikes := 0
	for index in _chambers.size():
		var radius: float = _chambers[index]["radius"]

		# Boulders at the foot of the wall.
		for i in 5:
			var point := _spot(index, _rng.randf_range(0.72, 0.95))
			_add_body(
				"Boulder%d" % boulders, Vector3(point.x, 0.35, point.y),
				_rng.randf_range(0.45, 0.95), _rng.randf_range(0.6, 1.3), _rock_dark
			)
			boulders += 1

		# Stalagmites on the floor and their mirrors overhead.
		for i in 4:
			var point := _spot(index, _rng.randf_range(0.3, 0.9))
			var height := _rng.randf_range(0.5, 1.6)
			TownParts.cone(
				self, "Stalagmite%d" % spikes,
				Vector3(point.x, height * 0.5, point.y),
				_rng.randf_range(0.16, 0.4), height, _rock, 6
			)
			spikes += 1

			var hang := _rng.randf_range(0.4, 1.2)
			var tip := TownParts.cone(
				self, "Stalactite%d" % spikes,
				Vector3(point.x, HEIGHT - hang * 0.5, point.y),
				_rng.randf_range(0.12, 0.3), hang, _rock_dark, 6
			)
			tip.rotation.x = PI
			spikes += 1

		# A low ceiling crack, so no chamber reads as a box.
		var lump := _spot(index, _rng.randf_range(0.2, 0.6))
		TownParts.sphere(
			self, "RoofLump%d" % index, Vector3(lump.x, HEIGHT - 0.5, lump.y),
			_rng.randf_range(1.4, 2.6), _rng.randf_range(1.1, 1.8), _rock_dark
		)

		if is_lair:
			_add_cocoon(index, radius)


func _add_cocoon(index: int, radius: float) -> void:
	var point := _spot(index, 0.62)
	var at := Vector3(point.x, 1.6, point.y)
	TownParts.sphere(self, "Cocoon%d" % index, at, 0.55, 1.9, _web)
	TownParts.sphere(self, "CocoonTip%d" % index, at + Vector3(0, 0.9, 0), 0.22, 0.4, _web)


## One pool of light per chamber, plus glowing crystals. Deliberately few: the
## darkness is the point, and a cave lit like a street is not a cave.
func _lights() -> void:
	for index in _chambers.size():
		var centre: Vector2 = _chambers[index]["centre"]

		var light := OmniLight3D.new()
		light.name = "CaveLight%d" % index
		light.position = Vector3(centre.x, HEIGHT - 0.9, centre.y)
		light.light_color = Color(0.62, 0.66, 0.95, 1) if is_lair else Color(1.0, 0.7, 0.4, 1)
		light.light_energy = 1.5 if is_lair else 1.25
		light.omni_range = 14.0
		light.shadow_enabled = false
		add_child(light)

		for i in 2:
			var point := _spot(index, _rng.randf_range(0.7, 0.92))
			for shard in 4:
				var angle := TAU * float(shard) / 4.0
				var crystal := TownParts.cone(
					self, "Crystal%d_%d" % [index, i * 4 + shard],
					Vector3(point.x + cos(angle) * 0.16, 0.38, point.y + sin(angle) * 0.16),
					0.1, _rng.randf_range(0.5, 0.9), _glow, 5
				)
				crystal.rotation = Vector3(
					deg_to_rad(_rng.randf_range(-16.0, 16.0)), angle,
					deg_to_rad(_rng.randf_range(-16.0, 16.0))
				)


# --- content ---------------------------------------------------------------


## Ore and glass seams. No `save_id`: the cave is rebuilt under the player, so a
## remembered "already mined" flag would belong to a passage that is gone. They
## are here to be mined this visit.
func _seams() -> void:
	const DROPS: Array[StringName] = [
		&"item.iron_ore", &"item.gemstone", &"item.seaglass"
	]
	var count := seam_count
	for i in count:
		var index := _rng.randi_range(0, _chambers.size() - 1)
		var point := _spot(index, _rng.randf_range(0.7, 0.9))
		var drop: StringName = DROPS[_rng.randi_range(0, DROPS.size() - 1)]
		var crystal := drop != &"item.iron_ore"
		_add_seam("Seam%d" % i, Vector3(point.x, 0, point.y), drop, crystal)


func _add_seam(node_name: String, at: Vector3, drop: StringName, crystal: bool) -> void:
	var seam := GATHER_SCENE.instantiate() as GatherNode
	seam.name = node_name
	seam.position = at
	seam.save_id = &""
	seam.kind = GatherNode.Kind.CRYSTAL if crystal else GatherNode.Kind.ORE
	seam.required_tool_tag = &"pickaxe"
	seam.hits_required = _rng.randi_range(2, 4)
	seam.drop_item = drop
	seam.drop_amount = 1 if crystal else 2
	seam.extra_drop_item = &"item.gemstone" if drop == &"item.seaglass" else &""
	seam.extra_drop_amount = 1 if seam.extra_drop_item != &"" else 0
	seam.regrow_days = 0
	seam.verb = "Mine"
	seam.missing_tool_hint = "You need a pickaxe for this"
	seam.depleted_message = (
		"The crystal comes free with a clean ring"
		if crystal
		else "The seam breaks down to rubble"
	)
	seam.collision_radius = 0.85
	seam.collision_height = 1.3

	var art := Node3D.new()
	art.name = "SeamArt"
	TownParts.sphere(art, "Boulder", Vector3(0, 0.55, 0), 0.82, 1.35, _rock)
	TownParts.sphere(art, "BoulderB", Vector3(0.52, 0.34, 0.28), 0.52, 0.85, _rock_dark)
	if crystal:
		for i in 5:
			var angle := TAU * float(i) / 5.0 + 0.4
			var shard := TownParts.cone(
				art, "Shard%d" % i,
				Vector3(cos(angle) * 0.42, 0.95, sin(angle) * 0.42),
				0.13, 0.72, _gem, 5
			)
			shard.rotation = Vector3(deg_to_rad(-18.0), angle, deg_to_rad(14.0))
	else:
		for i in 7:
			var angle := TAU * float(i) / 7.0
			TownParts.sphere(
				art, "Ore%d" % i,
				Vector3(cos(angle) * 0.55, 0.45 + (i % 3) * 0.26, sin(angle) * 0.55),
				0.11, 0.2, _iron
			)
	seam.proxy_visual = art
	seam.add_child(art)
	add_child(seam)


## Ghost spiders, not the surface's mist creatures: the caves have their own
## things in them, and none of these are saved because the cave is not.
func _enemies() -> void:
	var count := spider_count
	for i in count:
		if _chambers.size() < 2:
			break
		var index := _rng.randi_range(1, _chambers.size() - 1)
		var point := _spot(index, _rng.randf_range(0.15, 0.6))
		var spider := SPIDER_SCENE.instantiate() as Node3D
		spider.name = "CaveSpider%d" % i
		(spider as Node).set("save_id", &"")
		add_child(spider)
		spider.position = Vector3(point.x, 0.05, point.y)


func _web_dressing() -> void:
	for index in _chambers.size():
		for i in 7:
			var point := _spot(index, _rng.randf_range(0.2, 0.9))
			var height := _rng.randf_range(2.2, HEIGHT)
			var strand := TownParts.box(
				self, "Strand%d_%d" % [index, i],
				Vector3(point.x, height * 0.5, point.y),
				Vector3(0.05, height, 0.05), _web
			)
			strand.rotation = Vector3(
				_rng.randf_range(-0.12, 0.12), _rng.randf_range(0.0, TAU),
				_rng.randf_range(-0.12, 0.12)
			)


# --- exit ------------------------------------------------------------------


## A lit opening in the rock, near but not on the way out of the entrance
## chamber. The trigger sits in front of it, a couple of metres from the spawn,
## so arriving never bounces straight back to the surface.
func _exit_portal() -> void:
	var chamber := _chambers[0]
	var centre: Vector2 = chamber["centre"]
	var radius: float = chamber["radius"]

	var angle := _rng.randf() * TAU
	for attempt in 16:
		var probe := centre + Vector2(cos(angle), sin(angle)) * (radius - 0.9)
		if not _inside_other(probe, 0):
			break
		angle += TAU / 16.0

	var door := centre + Vector2(cos(angle), sin(angle)) * (radius - 0.75)
	var outward := Vector2(cos(angle), sin(angle))

	# Frame and daylight. The slab stands where the wall would be.
	TownParts.box(
		self, "ExitFrameL", Vector3(door.x - outward.y * 0.8, 1.2, door.y + outward.x * 0.8),
		Vector3(0.25, 2.4, 0.25), _rock_dark
	)
	TownParts.box(
		self, "ExitFrameR", Vector3(door.x + outward.y * 0.8, 1.2, door.y - outward.x * 0.8),
		Vector3(0.25, 2.4, 0.25), _rock_dark
	)
	TownParts.box(
		self, "ExitGlow", Vector3(door.x, 1.1, door.y),
		Vector3(1.1, 2.2, 0.12), _daylight
	)
	var glow := OmniLight3D.new()
	glow.name = "ExitLight"
	glow.position = Vector3(door.x, 1.6, door.y)
	glow.light_color = Color(1.0, 0.94, 0.78, 1)
	glow.light_energy = 1.6
	glow.omni_range = 9.0
	glow.shadow_enabled = false
	add_child(glow)

	var exit := Area3D.new()
	exit.name = "ExitDoor"
	exit.position = Vector3(door.x - outward.x * 0.9, 1.1, door.y - outward.y * 0.9)
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.set_script(EXIT_SCRIPT)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 2.2, 1.3)
	shape.shape = box
	exit.add_child(shape)
	add_child(exit)

	_spawn = Vector3(centre.x, 0.2, centre.y)


func _place_player() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player != null:
		player.global_position = _spawn

	Events.notification_requested.emit(
		"The passages have moved since anyone last walked them."
	)
