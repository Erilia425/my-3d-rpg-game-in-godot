extends Node3D
## The Old Adit, a hand-cut mine under the north meadow.
##
## A standalone interior scene rather than a `layout` of `InteriorRoom`: a mine
## is a rough stone shell with no plaster, no windows, and no house door, so it
## would have meant a second shell inside the room builder. It reuses the same
## exit trigger and `TownParts` primitives, which is where the shared behaviour
## actually lives.
##
## The ore and gemstone seams are ordinary `GatherNode`s with a `proxy_visual`,
## exactly like a town tree: one node is scenery, an obstacle, and a harvest.
## Looking at a seam for the first time unlocks the "Old Adit" discovery.

const EXIT_SCRIPT := preload("res://features/world/interiors/interior_exit.gd")
const GATHER_SCENE := preload("res://features/gathering/gather_node.tscn")

## Inside measurements. The entrance corridor runs off the south (+z) wall.
const ROOM := Vector2(18.0, 14.0)
const HEIGHT := 4.2
const WALL := 0.8
const CORRIDOR_WIDTH := 2.6
const CORRIDOR_HEIGHT := 2.6
const CORRIDOR_DEPTH := 4.2

var _half := Vector2.ZERO
var _rock: StandardMaterial3D
var _rock_dark: StandardMaterial3D
var _floor: StandardMaterial3D
var _iron: StandardMaterial3D
var _gem: StandardMaterial3D
var _glow: StandardMaterial3D
var _timber: StandardMaterial3D
var _torch_light: StandardMaterial3D


func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_half = ROOM * 0.5
	_materials()
	_environment()
	_shell()
	_details()
	_seams()
	_torches()
	_exit_door()

	# One draw call per material for the rock shell. The gather bodies, lights,
	# and exit area are separate children and survive the merge.
	TownParts.merge_children(self)

	if DiscoveryLog.unlock(DiscoveryLog.OLD_ADIT):
		Events.notification_requested.emit(
			"Discovery: %s" % DiscoveryLog.get_title(DiscoveryLog.OLD_ADIT)
		)


# --- shell -----------------------------------------------------------------


func _materials() -> void:
	_rock = TownParts.material(Color(0.3, 0.29, 0.27, 1), 0.98)
	_rock_dark = TownParts.material(Color(0.17, 0.16, 0.15, 1), 0.99)
	_floor = TownParts.material(Color(0.26, 0.25, 0.23, 1), 1.0)
	_iron = TownParts.material(Color(0.72, 0.42, 0.19, 1), 0.72)
	_gem = TownParts.material(Color(0.62, 0.82, 0.92, 1), 0.32, 1.1)
	_glow = TownParts.material(Color(1.0, 0.7, 0.36, 1), 0.5, 2.6)
	_timber = TownParts.material(Color(0.3, 0.23, 0.16, 1), 0.94)
	_torch_light = TownParts.material(Color(0.85, 0.55, 0.24, 1), 0.85)


func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.011, 0.01, 1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.24, 0.22, 0.2, 1)
	environment.ambient_light_energy = 0.26
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.09, 0.08, 0.07, 1)
	environment.fog_density = 0.035
	environment.fog_sky_affect = 0.0

	var world := WorldEnvironment.new()
	world.name = "CaveEnvironment"
	world.environment = environment
	add_child(world)


func _shell() -> void:
	var outer := Vector2(ROOM.x + WALL * 2.0, ROOM.y + WALL * 2.0)
	var half_height := HEIGHT * 0.5

	TownParts.box(self, "Floor", Vector3(0, -0.25, 0), Vector3(outer.x, 0.5, outer.y), _floor)
	TownParts.collision(self, Vector3(outer.x, 0.5, outer.y), Vector3(0, -0.25, 0))
	TownParts.box(self, "Ceiling", Vector3(0, HEIGHT + 0.25, 0), Vector3(outer.x, 0.5, outer.y), _rock)
	TownParts.collision(self, Vector3(outer.x, 0.5, outer.y), Vector3(0, HEIGHT + 0.25, 0))

	_wall("NorthWall", Vector3(0, half_height, -_half.y - WALL * 0.5), Vector3(outer.x, HEIGHT, WALL))
	_wall("WestWall", Vector3(-_half.x - WALL * 0.5, half_height, 0), Vector3(WALL, HEIGHT, ROOM.y))
	_wall("EastWall", Vector3(_half.x + WALL * 0.5, half_height, 0), Vector3(WALL, HEIGHT, ROOM.y))

	# The south wall is split around the entrance corridor.
	var side_width := _half.x - CORRIDOR_WIDTH * 0.5
	_wall(
		"SouthWallL", Vector3(-CORRIDOR_WIDTH * 0.5 - side_width * 0.5, half_height, _half.y + WALL * 0.5),
		Vector3(side_width, HEIGHT, WALL)
	)
	_wall(
		"SouthWallR", Vector3(CORRIDOR_WIDTH * 0.5 + side_width * 0.5, half_height, _half.y + WALL * 0.5),
		Vector3(side_width, HEIGHT, WALL)
	)
	_wall(
		"SouthLintel",
		Vector3(0, CORRIDOR_HEIGHT + (HEIGHT - CORRIDOR_HEIGHT) * 0.5, _half.y + WALL * 0.5),
		Vector3(CORRIDOR_WIDTH, HEIGHT - CORRIDOR_HEIGHT, WALL)
	)

	# The way out: a short rough corridor with the exit trigger inside its far end.
	var corridor_mid := _half.y + WALL + CORRIDOR_DEPTH * 0.5
	for side in [-1.0, 1.0]:
		_wall(
			"CorridorWall%d" % (1 if side < 0.0 else 2),
			Vector3(side * (CORRIDOR_WIDTH * 0.5 + WALL * 0.5), CORRIDOR_HEIGHT * 0.5, corridor_mid),
			Vector3(WALL, CORRIDOR_HEIGHT, CORRIDOR_DEPTH)
		)
	TownParts.box(
		self, "CorridorCeiling",
		Vector3(0, CORRIDOR_HEIGHT + 0.2, corridor_mid),
		Vector3(CORRIDOR_WIDTH + WALL * 2.0, 0.4, CORRIDOR_DEPTH), _rock
	)
	TownParts.collision(
		self, Vector3(CORRIDOR_WIDTH + WALL * 2.0, 0.4, CORRIDOR_DEPTH),
		Vector3(0, CORRIDOR_HEIGHT + 0.2, corridor_mid)
	)
	# A rock face closes the corridor behind the trigger, so the player cannot
	# run out of the world if the exit ever fails to fire.
	_wall(
		"CorridorEnd",
		Vector3(0, CORRIDOR_HEIGHT * 0.5, _half.y + WALL + CORRIDOR_DEPTH),
		Vector3(CORRIDOR_WIDTH, CORRIDOR_HEIGHT, WALL)
	)


func _wall(node_name: String, position: Vector3, size: Vector3) -> void:
	TownParts.box(self, node_name, position, size, _rock)
	TownParts.collision(self, size, position)


## Lumps, boulders, and stalactites. The wall boxes read as a cave once a dozen
## irregular shapes sit along their seams.
func _details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110

	# Boulders around the foot of every wall.
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var x := clampf(cos(angle) * 8.6, -_half.x + 0.5, _half.x - 0.5)
		var z := clampf(sin(angle) * 6.6, -_half.y + 0.5, _half.y - 0.5)
		TownParts.sphere(
			self, "CaveBoulder%d" % i, Vector3(x, 0.35, z),
			rng.randf_range(0.5, 1.0), rng.randf_range(0.7, 1.4), _rock
		)

	# Rock lumps high on the walls.
	for i in 10:
		var side := rng.randi_range(0, 3)
		var x := 0.0
		var z := 0.0
		match side:
			0:
				x = rng.randf_range(-_half.x + 0.6, _half.x - 0.6)
				z = -_half.y + 0.35
			1:
				x = rng.randf_range(-_half.x + 0.6, _half.x - 0.6)
				z = _half.y - 0.35
			2:
				x = -_half.x + 0.35
				z = rng.randf_range(-_half.y + 0.6, _half.y - 0.6)
			_:
				x = _half.x - 0.35
				z = rng.randf_range(-_half.y + 0.6, _half.y - 0.6)
		TownParts.sphere(
			self, "CaveLump%d" % i, Vector3(x, rng.randf_range(1.6, 3.2), z),
			rng.randf_range(0.5, 1.1), rng.randf_range(0.7, 1.5), _rock_dark
		)

	# Stalactites hanging from the ceiling.
	for i in 8:
		var x := rng.randf_range(-_half.x + 1.5, _half.x - 1.5)
		var z := rng.randf_range(-_half.y + 1.5, _half.y - 1.5)
		var height := rng.randf_range(0.5, 1.3)
		var spike := TownParts.cone(
			self, "Stalactite%d" % i, Vector3(x, HEIGHT - height * 0.5, z),
			rng.randf_range(0.18, 0.38), height, _rock_dark, 6
		)
		spike.rotation.x = PI


# --- seams -----------------------------------------------------------------


func _seams() -> void:
	# Iron first, then the rarer pale gemstone. Each position hugs a wall so the
	# middle of the cave stays walkable.
	_add_seam(
		"IronSeam0", &"gather.cave.iron_0", Vector3(-7.3, 0, -4.3),
		GatherNode.Kind.ORE, &"item.iron_ore", 2, 3, &"", 0, false
	)
	_add_seam(
		"IronSeam1", &"gather.cave.iron_1", Vector3(7.4, 0, -4.6),
		GatherNode.Kind.ORE, &"item.iron_ore", 2, 3, &"", 0, false
	)
	_add_seam(
		"IronSeam2", &"gather.cave.iron_2", Vector3(-6.2, 0, 4.7),
		GatherNode.Kind.ORE, &"item.iron_ore", 2, 3, &"item.gemstone", 1, false
	)
	_add_seam(
		"GemSeam0", &"gather.cave.gem_0", Vector3(7.2, 0, 3.7),
		GatherNode.Kind.CRYSTAL, &"item.gemstone", 1, 4, &"", 0, true
	)
	_add_seam(
		"GemSeam1", &"gather.cave.gem_1", Vector3(0.6, 0, -6.2),
		GatherNode.Kind.CRYSTAL, &"item.gemstone", 1, 4, &"item.iron_ore", 1, true
	)
	# Sea glass. The Old Adit was flooded once, or the shards came up with the
	# rock; nobody agrees which. The machine in the square takes them.
	_add_seam(
		"GlassSeam0", &"gather.cave.glass_0", Vector3(-1.2, 0, 4.6),
		GatherNode.Kind.CRYSTAL, &"item.seaglass", 2, 3, &"item.gemstone", 1, true
	)


func _add_seam(
	node_name: String,
	id: StringName,
	at: Vector3,
	kind: int,
	drop: StringName,
	amount: int,
	hits: int,
	extra: StringName,
	extra_amount: int,
	crystal: bool
) -> void:
	var seam := GATHER_SCENE.instantiate() as GatherNode
	seam.name = node_name
	seam.position = at
	seam.save_id = id
	seam.kind = kind
	seam.required_tool_tag = &"pickaxe"
	seam.hits_required = hits
	seam.drop_item = drop
	seam.drop_amount = amount
	seam.extra_drop_item = extra
	seam.extra_drop_amount = extra_amount
	seam.regrow_days = 7
	seam.verb = "Mine"
	seam.missing_tool_hint = "You need a pickaxe for this"
	seam.depleted_message = (
		"The crystal comes free with a clean ring"
		if crystal
		else "The seam breaks down to rubble"
	)
	seam.collision_radius = 0.85
	seam.collision_height = 1.3

	# A rock body with ore studs or crystal shards. The gather node drives this
	# art through `proxy_visual`, so harvesting hides the whole thing.
	var art := Node3D.new()
	art.name = "SeamArt"
	TownParts.sphere(art, "Boulder", Vector3(0, 0.55, 0), 0.82, 1.35, _rock)
	TownParts.sphere(
		art, "BoulderB", Vector3(0.52, 0.34, 0.28), 0.52, 0.85, _rock_dark
	)
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


# --- light -----------------------------------------------------------------


func _torches() -> void:
	var spots: Array[Vector3] = [
		Vector3(-_half.x + 0.55, 2.3, -_half.y + 0.55),
		Vector3(_half.x - 0.55, 2.3, -_half.y + 0.55),
		Vector3(-_half.x + 0.55, 2.3, _half.y - 0.55),
		Vector3(_half.x - 0.55, 2.3, _half.y - 0.55),
		Vector3(0, 2.3, -_half.y + 0.55),
	]
	for i in spots.size():
		var at: Vector3 = spots[i]
		var holder := Node3D.new()
		holder.name = "Torch%d" % i
		holder.position = at
		add_child(holder)
		# Bracket, sconce, and flame. They stay inside `holder`, so the shell
		# merge leaves them alone.
		TownParts.box(holder, "Bracket", Vector3(0, -0.2, 0), Vector3(0.08, 0.5, 0.08), _timber)
		TownParts.box(holder, "Sconce", Vector3(0, 0.05, 0), Vector3(0.18, 0.18, 0.18), _torch_light)
		TownParts.sphere(holder, "Flame", Vector3(0, 0.24, 0), 0.11, 0.26, _glow)

		var light := OmniLight3D.new()
		light.name = "Glow"
		light.position = Vector3(0, 0.3, 0)
		light.light_color = Color(1, 0.72, 0.38, 1)
		light.light_energy = 1.8
		light.omni_range = 11.0
		light.shadow_enabled = false
		holder.add_child(light)


# --- exit ------------------------------------------------------------------


func _exit_door() -> void:
	var exit := Area3D.new()
	exit.name = "ExitDoor"
	exit.position = Vector3(0, 1.2, _half.y + WALL + CORRIDOR_DEPTH - 0.8)
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.set_script(EXIT_SCRIPT)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(CORRIDOR_WIDTH, 2.2, 1.0)
	shape.shape = box
	exit.add_child(shape)
	add_child(exit)
