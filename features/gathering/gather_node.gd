class_name GatherNode
extends StaticBody3D
## A standing dead tree, a boulder, or a gem seam the player can work on.
##
## Gathering is a tool check plus a hit count: E swings the equipped tool, each
## swing counts, and the last one hands the drops to the player's
## `InventoryComponent`. The tool lives in the tool slot (`ItemData.EquipSlot.TOOL`),
## so carrying an axe never costs the player their sword hand.
##
## The node owns only its own state: how many hits it has taken and whether it is
## currently spent. The loot it produces belongs to the inventory, exactly like a
## chest. Depleted nodes are saved by `save_id`; trees and seams regrow after
## `regrow_days` so the world does not run out of wood.
##
## Visuals are built at `_ready()` because one scene covers every resource kind:
## set `sprite_texture`, `sprite_height`, and `collision_radius`.

enum Kind {
	TREE,
	ROCK,
	ORE,
	CRYSTAL,
	CROP,
}

## Stable id for the save file. Leave empty for a node that should never persist.
@export var save_id: StringName = &""
@export var kind: Kind = Kind.TREE
## Tool tag the player must have equipped, e.g. `axe` or `pickaxe`. Leave empty
## for a crop that is picked by hand.
@export var required_tool_tag: StringName = &"axe"
## Swings needed before the node gives up its drops.
@export var hits_required: int = 3
@export var drop_item: StringName = &"item.wood"
@export var drop_amount: int = 2
## Optional second drop, used for the rare gem in an ore seam.
@export var extra_drop_item: StringName = &""
@export var extra_drop_amount: int = 1
## Days until a spent node comes back. 0 means it stays spent forever.
@export var regrow_days: int = 3

@export_group("Look")
## Art for the node. Without one a primitive shape is built instead.
@export var sprite_texture: Texture2D = null
## World height of the sprite in metres.
@export var sprite_height: float = 4.0
## World width of the sprite in metres. 0 keeps the art's own aspect ratio.
@export var sprite_width: float = 0.0
@export var tint: Color = Color.WHITE
@export var collision_radius: float = 0.45
@export var collision_height: float = 1.6
## How far a felled tree tips over before it disappears, in degrees.
@export var fall_degrees: float = 76.0

@export_group("Words")
## Shown in the prompt before the tool name, e.g. "Chop" or "Mine".
@export var verb: String = "Chop"
## Toast when the player has no matching tool.
@export var missing_tool_hint: String = "You need an axe for this"
## Toast when the node finally gives way.
@export var depleted_message: String = "Seasoned wood gathered"

var hits: int = 0
var is_depleted := false
## World day the node was spent, used by `regrow_days`.
var depleted_day: int = 0

## Set before the node enters the tree by `TownProp`, which already built a
## sprite or primitive tree. When set, this node drives that prop's visuals
## instead of building its own art, so a town tree can be scenery and harvest.
var proxy_visual: Node3D = null

var _visual: Node3D
var _sprite: Sprite3D
## Shown while the node is spent: a tree stump, or a patch of bare soil.
var _leaves: Node3D
## The living part of a crop. Hidden when picked, while the soil stays.
var _plant: Node3D
var _jiggle: Tween
var _fall: Tween


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")
	if regrow_days > 0:
		Events.day_changed.connect(_on_day_changed)

	_build_visuals()
	_set_depleted(false)


## The prompt reads like "Chop (Axe)" so the player can tell what is missing
## before pressing E. A crop with no tool requirement just says "Pick".
func get_interaction_text() -> String:
	if is_depleted:
		return ""
	if required_tool_tag.is_empty():
		return verb
	return "%s (%s)" % [verb, String(required_tool_tag).capitalize()]


func interact(interactor: Node) -> void:
	if is_depleted:
		return

	var by_hand := required_tool_tag.is_empty()
	if not by_hand:
		var tool := _held_tool(interactor)
		if tool == null or not tool.tags.has(String(required_tool_tag)):
			Events.notification_requested.emit(missing_tool_hint)
			return

	hits += 1
	_play_hit()
	if hits < hits_required:
		return

	_harvest(interactor)


# --- gathering -------------------------------------------------------------


## Grants the drops. A full bag leaves the node standing so nothing is lost.
func _harvest(interactor: Node) -> void:
	var data := ItemDatabase.get_item(drop_item)
	if data == null:
		push_warning("GatherNode %s has unknown drop %s" % [name, drop_item])
		return

	var granted := drop_amount
	if interactor != null and interactor.has_method("add_item"):
		granted = int(interactor.call("add_item", data, drop_amount))
	if granted <= 0:
		Events.notification_requested.emit("Your inventory is full")
		return

	Events.notification_requested.emit("%s x%d" % [data.display_name, granted])

	if not extra_drop_item.is_empty():
		var extra := ItemDatabase.get_item(extra_drop_item)
		if extra != null and interactor != null and interactor.has_method("add_item"):
			var extra_granted := int(interactor.call("add_item", extra, extra_drop_amount))
			if extra_granted > 0:
				Events.notification_requested.emit(
					"%s x%d" % [extra.display_name, extra_granted]
				)

	depleted_day = WorldClock.get_day()
	if kind == Kind.TREE and _has_art():
		_begin_fall()
	else:
		_set_depleted(true)
	Events.notification_requested.emit(depleted_message)


## Reads the tool slot through the interactor's public API. The player owns the
## equipment; this node never reaches into the player's children.
func _held_tool(interactor: Node) -> ItemData:
	if interactor == null or not interactor.has_method("get_equipment_component"):
		return null
	var equipment := interactor.call("get_equipment_component") as EquipmentComponent
	if equipment == null:
		return null
	return equipment.get_equipped(ItemData.EquipSlot.TOOL)


func _play_hit() -> void:
	var target := _pivot()
	if target == null:
		return

	if _jiggle != null and _jiggle.is_valid():
		_jiggle.kill()

	var rest := target.rotation
	_jiggle = create_tween()
	_jiggle.tween_property(target, "rotation:z", rest.z + 0.07, 0.06)
	_jiggle.tween_property(target, "rotation:z", rest.z - 0.05, 0.08)
	_jiggle.tween_property(target, "rotation:z", rest.z, 0.1)


# --- felling ---------------------------------------------------------------


## A chopped tree tips over before the stump is left behind. `is_depleted` and
## the collision go first, so the next E press cannot double-harvest a trunk
## that is still falling.
func _begin_fall() -> void:
	is_depleted = true
	collision_layer = 0

	var pivot := _pivot()
	if pivot == null:
		_finish_fall()
		return

	if _fall != null and _fall.is_valid():
		_fall.kill()
	var rest := pivot.rotation
	_fall = create_tween()
	_fall.tween_property(
		pivot, "rotation:z", rest.z + deg_to_rad(fall_degrees), 0.6
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall.tween_callback(_finish_fall)


func _finish_fall() -> void:
	_show_art(false)
	if _leaves != null:
		_leaves.visible = true


func _pivot() -> Node3D:
	if proxy_visual != null:
		return proxy_visual
	return _visual


func _has_art() -> bool:
	return proxy_visual != null or _sprite != null


## Hides or restores the living tree without touching the stump. In proxy mode
## the prop's own visible children are toggled; this node is a `StaticBody3D`,
## so it is never one of them.
func _show_art(shown: bool) -> void:
	if proxy_visual != null:
		for child in proxy_visual.get_children():
			if child is VisualInstance3D:
				(child as VisualInstance3D).visible = shown
		return
	if _sprite != null:
		_sprite.visible = shown


# --- look ------------------------------------------------------------------


func _build_visuals() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	if sprite_texture != null and proxy_visual == null:
		_sprite = Sprite3D.new()
		_sprite.name = "Art"
		_sprite.texture = sprite_texture
		_sprite.modulate = tint
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sprite.shaded = false
		_sprite.double_sided = true
		_sprite.pixel_size = sprite_height / float(maxi(sprite_texture.get_height(), 1))
		if sprite_width > 0.0:
			var natural := sprite_height * float(sprite_texture.get_width()) / float(maxi(sprite_texture.get_height(), 1))
			if natural > 0.0:
				_sprite.scale.x = sprite_width / natural
		_sprite.position = Vector3(0, sprite_height * 0.5, 0)
		_visual.add_child(_sprite)

	# A crop is picked, not felled, so it is drawn from primitives: a tight ball
	# of leaves low to the ground. Leaves the soil bare when spent.
	if sprite_texture == null and proxy_visual == null and kind == Kind.CROP:
		_build_crop_visual()

	# A small stump left behind, so a spent tree still reads as something that
	# was here rather than an empty patch of grass.
	if kind == Kind.TREE:
		var stump := MeshInstance3D.new()
		stump.name = "Stump"
		var mesh := CylinderMesh.new()
		mesh.top_radius = collision_radius * 0.8
		mesh.bottom_radius = collision_radius * 0.95
		mesh.height = 0.34
		mesh.radial_segments = 8
		stump.mesh = mesh
		stump.position = Vector3(0, 0.17, 0)
		stump.material_override = TownParts.material(Color(0.34, 0.24, 0.15, 1), 1.0)
		stump.visible = false
		_visual.add_child(stump)
		_leaves = stump

	var body := CollisionShape3D.new()
	body.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = collision_radius
	shape.height = maxf(collision_height, collision_radius * 2.0)
	body.shape = shape
	body.position = Vector3(0, shape.height * 0.5, 0)
	add_child(body)


## A hand-picked crop: a squat cabbage head with a loose ring of outer leaves.
## Six cheap primitives at most; garden beds hold several of these.
func _build_crop_visual() -> void:
	var leaf := TownParts.material(Color(0.33, 0.52, 0.27, 1), 0.9)
	var pale := TownParts.material(Color(0.55, 0.72, 0.44, 1), 0.9)
	var soil := TownParts.material(Color(0.28, 0.2, 0.13, 1), 1.0)

	var mound := MeshInstance3D.new()
	mound.name = "Mound"
	var disc := CylinderMesh.new()
	disc.top_radius = maxf(collision_radius, 0.3)
	disc.bottom_radius = maxf(collision_radius, 0.3) * 1.15
	disc.height = 0.08
	disc.radial_segments = 10
	mound.mesh = disc
	mound.position = Vector3(0, 0.04, 0)
	mound.material_override = soil
	_visual.add_child(mound)

	_plant = Node3D.new()
	_plant.name = "Plant"
	_visual.add_child(_plant)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var ball := SphereMesh.new()
	ball.radius = 0.26
	ball.height = 0.4
	head.mesh = ball
	head.position = Vector3(0, 0.24, 0)
	head.material_override = pale
	_plant.add_child(head)

	# Outer leaves fanning out on four sides.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var outer := MeshInstance3D.new()
		outer.name = "Leaf%d" % i
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.22
		leaf_mesh.height = 0.14
		outer.mesh = leaf_mesh
		outer.material_override = leaf
		outer.position = Vector3(cos(angle) * 0.16, 0.1, sin(angle) * 0.16)
		outer.rotation = Vector3(0.35, angle, 0.0)
		_plant.add_child(outer)


## Hides the art and stops the ray finding the node, without freeing it, so the
## save state and regrow timer survive.
func _set_depleted(value: bool) -> void:
	is_depleted = value
	if _fall != null and _fall.is_valid():
		_fall.kill()
	_show_art(not value)
	if _plant != null:
		_plant.visible = not value
	if _leaves != null:
		_leaves.visible = value
	collision_layer = 0 if value else 17

	if value:
		return

	hits = 0
	# Clear the felled tilt so the regrown tree stands up again.
	var pivot := _pivot()
	if pivot != null:
		pivot.rotation.z = 0.0


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"depleted": is_depleted, "day": depleted_day}


func load_data(data: Dictionary) -> void:
	hits = 0
	var spent := bool(data.get("depleted", false))
	depleted_day = int(data.get("day", WorldClock.get_day()))

	if spent and regrow_days > 0 and WorldClock.get_day() - depleted_day >= regrow_days:
		spent = false

	_set_depleted(spent)


## Called by `Game` once per midnight through `Events.day_changed`. A stump or
## a spent seam comes back while the player is still in the scene, not only
## after a save and load.
func _on_day_changed(_current_day: int) -> void:
	check_regrow()


func check_regrow() -> void:
	if not is_depleted or regrow_days <= 0:
		return
	if WorldClock.get_day() - depleted_day >= regrow_days:
		_set_depleted(false)
