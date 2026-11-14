class_name ChunkDressing
extends RefCounted
## Swaps a streamed chunk's primitive blockout for the 2D art style.
##
## The chunk scenes are generated blockouts: each prop is a hidden-away mesh with
## a plain colour. This helper leaves every collision shape and transform alone
## and only changes what is *seen*: ground boxes get the pixel-art grass texture,
## and prop bodies get an upright camera-facing billboard. Hiding a mesh never
## touches its `StaticBody3D`, so walking into a tree or a rock feels the same.
##
## It is opt-in through `ChunkManager.biome`. An empty biome does nothing, which
## keeps test fixtures and any future un-themed manager exactly as authored.

const GRASS_TEXTURE: Texture2D = preload("res://assets/from_2d/materials/grass.png")
const TREE_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/tree.png")
const ROCK_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/rock.png")
const MUSHROOM_TEXTURE: Texture2D = preload("res://assets/from_2d/sprites/mushroom.png")

## Root-level meshes that are scenery in their own right, not props to replace.
const KEPT_MESHES: Array[StringName] = [&"Water", &"FrozenPond", &"SnowDrift"]


static func apply(root: Node3D, biome: StringName) -> void:
	if root == null or biome == &"":
		return

	var palette := _palette(biome)
	_texture_ground(root, palette)

	for child in root.get_children():
		if child is StaticBody3D:
			if _is_ground(child):
				continue
			_dress_prop(child, palette)
		elif child is MeshInstance3D and not KEPT_MESHES.has(child.name):
			_dress_loose_mesh(root, child, palette)


## Ground and seafloor bodies keep their box and collision; only the surface
## material changes. The texture repeats so a 32 m chunk does not look like one
## giant stretched blade of grass.
static func _texture_ground(root: Node3D, palette: Dictionary) -> void:
	for child in root.get_children():
		if not child is StaticBody3D or not _is_ground(child):
			continue
		var mesh := child.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			continue
		mesh.material_override = TownParts.material(
			palette.ground_tint,
			0.96,
			0.0,
			GRASS_TEXTURE,
			Vector3(16, 16, 1)
		)


static func _is_ground(body: Node3D) -> bool:
	return body.name == &"Ground" or body.name == &"Seafloor"


## A prop body (tree, rock, cactus, pillar...) becomes one billboard at its
## origin. `height` comes from the authored meshes so the art matches the old
## silhouette closely enough that collisions still make sense.
static func _dress_prop(body: StaticBody3D, palette: Dictionary) -> void:
	var height := 1.0
	var has_canopy := false
	var has_trunk := false
	var found_mesh := false

	for child in body.get_children():
		if child is not MeshInstance3D:
			continue
		found_mesh = true
		if child.name == &"Canopy":
			has_canopy = true
		if child.name == &"Trunk":
			has_trunk = true
		var aabb := (child as MeshInstance3D).get_aabb()
		height = maxf(height, aabb.end.y + child.position.y)
		child.visible = false

	if not found_mesh:
		return

	if has_canopy or has_trunk:
		_billboard(body, "TreeArt2D", TREE_TEXTURE, height, palette.tree_tint)
	else:
		_billboard(body, "RockArt2D", ROCK_TEXTURE, maxf(height, 1.2), palette.rock_tint)


## Loose decorative meshes (`Arm`, `Branch`, `DryShrub`, generated
## `@MeshInstance3D@N` nodes) have no body of their own. Their billboard is
## parented to the chunk root at the same spot, and the original mesh is hidden.
static func _dress_loose_mesh(root: Node3D, mesh: MeshInstance3D, palette: Dictionary) -> void:
	var aabb := mesh.get_aabb()
	var height := maxf(aabb.size.y, 0.6)
	if mesh.name == &"DryShrub":
		_billboard(root, "ShrubArt2D", MUSHROOM_TEXTURE, height, palette.shrub_tint, mesh.position)
	elif mesh.name == &"Arm" or mesh.name == &"Branch" or mesh.name == &"Shell":
		# Limbs and shells are small set dressing; a rock sprite reads well enough
		# at this size and keeps one texture path for every odd-shaped mesh.
		_billboard(root, "RockArt2D", ROCK_TEXTURE, height, palette.rock_tint, mesh.position)
	else:
		_billboard(root, "RockArt2D", ROCK_TEXTURE, height, palette.rock_tint, mesh.position)
	mesh.visible = false


## The shared billboard recipe from `TownProp._sprite()`: FIXED_Y so the art
## stays upright, nearest filtering so pixels stay crisp, and discard alpha so it
## never writes over the world behind it.
static func _billboard(
	parent: Node3D,
	sprite_name: String,
	texture: Texture2D,
	height: float,
	tint: Color,
	at: Vector3 = Vector3.ZERO
) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.modulate = tint
	sprite.pixel_size = height / float(maxi(texture.get_height(), 1))
	sprite.position = at + Vector3(0, height * 0.5, 0)
	parent.add_child(sprite)
	return sprite


## One colour set per biome. Tints multiply the same handful of 2D textures, so
## a desert shrub and an ice shrub share art but still feel like different places.
static func _palette(biome: StringName) -> Dictionary:
	match biome:
		&"ice":
			return {
				"ground_tint": Color(0.78, 0.88, 0.95, 1),
				"tree_tint": Color(0.82, 0.9, 1.0, 1),
				"rock_tint": Color(0.72, 0.82, 0.9, 1),
				"shrub_tint": Color(0.7, 0.82, 0.9, 1),
			}
		&"desert":
			return {
				"ground_tint": Color(0.86, 0.76, 0.52, 1),
				"tree_tint": Color(0.72, 0.72, 0.42, 1),
				"rock_tint": Color(0.88, 0.74, 0.52, 1),
				"shrub_tint": Color(0.7, 0.6, 0.36, 1),
			}
		&"ocean":
			return {
				"ground_tint": Color(0.76, 0.72, 0.55, 1),
				"tree_tint": Color(0.6, 0.78, 0.68, 1),
				"rock_tint": Color(0.62, 0.72, 0.7, 1),
				"shrub_tint": Color(0.56, 0.72, 0.62, 1),
			}
		_:
			return {
				"ground_tint": Color(0.66, 0.74, 0.55, 1),
				"tree_tint": Color(1, 1, 1, 1),
				"rock_tint": Color(0.86, 0.86, 0.8, 1),
				"shrub_tint": Color(0.82, 0.86, 0.68, 1),
			}
