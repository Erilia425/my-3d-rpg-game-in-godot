extends Node
## Read-only layout audit for `scenes/town.tscn`.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/audit_town.tscn
##
## Run as a *scene*, not with `--script`, because the town instantiates the
## player, HUD, and pause menu, which reference autoloads.
##
## Checks, in the order they print:
##   A  building vs building overlap (oriented boxes, penetration depth)
##   B  props standing inside a building footprint
##   C  props blocking a path ribbon
##   D  buildings sitting on a path ribbon
##   E  forest clump trees inside buildings or on paths
##   F  building doors facing away from the nearest path
##   G  gate volume clearance and path reach
##   H  prop kind counts, mesh/light/collider totals (performance surface)
##
## Nothing is modified. Delete with `tools/` once the layout is signed off.

const TOWN_SCENE := preload("res://scenes/town.tscn")

## Props that legitimately stand on or beside a street.
const PATH_FRIENDLY: Array[int] = [3, 4, 5, 7, 10, 13]  # well stall bridge signpost reeds lantern
## Props that may stand in water.
const WATER_FRIENDLY: Array[int] = [5, 10]  # bridge reeds

const TOWN_CENTRE := Vector2(0, -8)


func _ready() -> void:
	var town: Node3D = TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var buildings := _collect(town, "Buildings")
	var props := _collect(town, "Props")
	var forest := _collect(town, "Forest")
	var paths := _collect(town, "Paths")
	var water := _collect(town, "Water")
	var gates := _collect(town, "Gates")

	var footprints := _footprints(buildings)
	var ribbons := _ribbons(paths)
	var rivers := _ribbons(water, true)

	print("=== TOWN AUDIT ===")
	print("buildings=%d props=%d forest_children=%d paths=%d water=%d gates=%d" % [
		buildings.size(), props.size(), forest.size(), ribbons.size(), rivers.size(), gates.size()
	])

	_check_overlaps(footprints)
	_check_props_in_buildings(props, footprints)
	_check_props_on_paths(props, ribbons)
	_check_buildings_on_paths(footprints, ribbons)
	_check_forest(forest, footprints, ribbons)
	_check_doors(footprints, ribbons)
	_check_gates(gates, footprints, props, ribbons)
	_check_rivers(props, rivers)
	_performance(town, props, buildings)

	print("=== AUDIT END ===")
	get_tree().quit()


# --- collection ------------------------------------------------------------


func _collect(town: Node3D, group_name: String) -> Array[Node]:
	var found: Array[Node] = []
	var group := town.get_node_or_null(group_name)
	if group == null:
		push_warning("audit: missing group node %s" % group_name)
		return found
	for child in group.get_children():
		found.append(child)
	return found


func _footprints(buildings: Array[Node]) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for child in buildings:
		if not (child is Node3D):
			continue
		var node := child as Node3D
		var size: Vector2 = node.get("footprint") if "footprint" in node else Vector2(6, 5)
		var angle := deg_to_rad(float(node.get("facing_degrees")) if "facing_degrees" in node else 0.0)
		var rects: Array[Dictionary] = []
		rects.append({"half": size * 0.5, "offset": Vector2.ZERO})
		# The longhouse lean-to sticks out past the footprint on its east flank.
		if int(node.get("style")) == 1:
			rects.append({"half": Vector2(1.3, size.y * 0.275), "offset": Vector2(size.x * 0.5 + 1.2, size.y * 0.22)})
		made.append({
			"name": String(node.name),
			"at": Vector2(node.position.x, node.position.z),
			"angle": angle,
			"rects": rects,
			"style": int(node.get("style")) if "style" in node else 0,
			"label": String(node.get("label")) if "label" in node else "",
		})
	return made


func _ribbons(container: Array[Node], water: bool = false) -> Array[Dictionary]:
	var made: Array[Dictionary] = []
	for child in container:
		if not (child is Node3D):
			continue
		var node := child as Node3D
		if not ("points" in node):
			continue
		var points: PackedVector3Array = node.get("points")
		if points.size() < 2:
			continue
		made.append({
			"name": String(node.name),
			"points": points,
			"width": float(node.get("width")),
			"water": water,
			"transparent": bool(node.get("transparent")) if "transparent" in node else false,
		})
	return made


# --- A: building overlaps --------------------------------------------------


func _check_overlaps(footprints: Array[Dictionary]) -> void:
	print("\n[A] BUILDING OVERLAPS")
	var count := 0
	for i in footprints.size():
		for j in range(i + 1, footprints.size()):
			var a: Dictionary = footprints[i]
			var b: Dictionary = footprints[j]
			if _distance(a, b) > 14.0:
				continue
			var depth := _rect_overlap(a, b)
			if depth > 0.25:
				count += 1
				print("  %s <-> %s  penetration=%.2fm  (at %s / %s)" % [
					a["name"], b["name"], depth, _fmt2(a["at"]), _fmt2(b["at"])
				])
	if count == 0:
		print("  none")


# --- B: props inside buildings --------------------------------------------


func _check_props_in_buildings(props: Array[Node], footprints: Array[Dictionary]) -> void:
	print("\n[B] PROPS INSIDE A BUILDING FOOTPRINT")
	var count := 0
	for child in props:
		if not (child is Node3D):
			continue
		var at := Vector2(child.position.x, child.position.z)
		var kind := int(child.get("kind")) if "kind" in child else -1
		for footprint in footprints:
			if _point_in(footprint, at, 0.1):
				count += 1
				print("  %s (kind %d) at %s inside %s" % [child.name, kind, _fmt2(at), footprint["name"]])
				break
	if count == 0:
		print("  none")


# --- C: props on paths -----------------------------------------------------


func _check_props_on_paths(props: Array[Node], ribbons: Array[Dictionary]) -> void:
	print("\n[C] PROPS BLOCKING A PATH")
	var count := 0
	for child in props:
		if not (child is Node3D):
			continue
		var at := Vector2(child.position.x, child.position.z)
		var kind := int(child.get("kind")) if "kind" in child else -1
		if kind in PATH_FRIENDLY:
			continue
		for ribbon in ribbons:
			var reach: float = float(ribbon["width"]) * 0.5 + 0.45
			var distance := _to_polyline(at, ribbon["points"])
			if distance < reach:
				count += 1
				print("  %s (kind %d) at %s is %.2fm from %s centreline" % [
					child.name, kind, _fmt2(at), distance, ribbon["name"]
				])
				break
	if count == 0:
		print("  none")


# --- D: buildings on paths -------------------------------------------------


func _check_buildings_on_paths(footprints: Array[Dictionary], ribbons: Array[Dictionary]) -> void:
	print("\n[D] BUILDINGS ON A PATH")
	var count := 0
	for footprint in footprints:
		for ribbon in ribbons:
			var hit := _rect_hits_polyline(footprint, ribbon["points"])
			if hit >= 0.0:
				count += 1
				print("  %s overlaps %s at segment %.1fm" % [footprint["name"], ribbon["name"], hit])
				break
	if count == 0:
		print("  none")


# --- E: forest clumps ------------------------------------------------------


func _check_forest(forest: Array[Node], footprints: Array[Dictionary], ribbons: Array[Dictionary]) -> void:
	print("\n[E] FOREST CLUMPS INSIDE BUILDINGS OR ON PATHS")
	var inside := 0
	var on_path := 0
	for child in forest:
		if not (child is Node3D) or child.get_child_count() == 0:
			continue
		if not String(child.name).begins_with("Clump"):
			continue
		var at := Vector2(child.position.x, child.position.z)
		for footprint in footprints:
			if _point_in(footprint, at, 0.3):
				inside += 1
				print("  %s inside %s" % [child.name, footprint["name"]])
				break
		for ribbon in ribbons:
			if _to_polyline(at, ribbon["points"]) < float(ribbon["width"]) * 0.5 + 0.6:
				on_path += 1
				print("  %s on %s" % [child.name, ribbon["name"]])
				break
	if inside == 0 and on_path == 0:
		print("  none")


# --- F: door orientation ---------------------------------------------------


func _check_doors(footprints: Array[Dictionary], ribbons: Array[Dictionary]) -> void:
	print("\n[F] DOORS WITH NO PATH IN FRONT")
	var count := 0
	for footprint in footprints:
		var style: int = footprint["style"]
		if style == 5:  # ruin: no door
			continue
		var at: Vector2 = footprint["at"]
		var angle: float = footprint["angle"]
		# Local -z is the door face; rotate it into world space.
		var facing := Vector2(-sin(angle), -cos(angle))
		var best := INF
		var best_name := ""
		for ribbon in ribbons:
			for point in ribbon["points"]:
				var offset := Vector2(point.x, point.z) - at
				var distance := offset.length()
				if distance < 0.5 or distance > 16.0:
					continue
				if facing.dot(offset / distance) < 0.45:
					continue
				if distance < best:
					best = distance
					best_name = String(ribbon["name"])
		if best == INF:
			count += 1
			print("  %-26s door faces %s, nothing walkable within 16m ahead" % [
				footprint["name"], _fmt2(facing)
			])
		elif best > 9.0:
			print("  %-26s door faces %s, only %s at %.1fm" % [
				footprint["name"], _fmt2(facing), best_name, best
			])
	if count == 0:
		print("  none completely blind")


# --- G: gates --------------------------------------------------------------


func _check_gates(gates: Array[Node], footprints: Array[Dictionary], props: Array[Node], ribbons: Array[Dictionary]) -> void:
	print("\n[G] GATE CLEARANCE")
	for gate in gates:
		if not (gate is Area3D):
			continue
		var at := Vector2(gate.position.x, gate.position.z)
		print("  %s at %s -> %s" % [gate.name, _fmt2(at), String(gate.get("target_scene"))])

		var near_building := 999.0
		var near_name := ""
		for footprint in footprints:
			var distance := _distance_to_rect(footprint, at)
			if distance < near_building:
				near_building = distance
				near_name = footprint["name"]
		print("     nearest building %s at %.2fm" % [near_name, near_building])
		if near_building < 1.2:
			print("     ^^ WARNING: gate sits against a wall")

		var near_path := INF
		var path_name := ""
		for ribbon in ribbons:
			var distance := _to_polyline(at, ribbon["points"])
			if distance < near_path:
				near_path = distance
				path_name = ribbon["name"]
		print("     nearest path %s at %.2fm" % [path_name, near_path])
		if near_path > 3.5:
			print("     ^^ WARNING: gate is not on a road")

		# Only props standing in the doorway itself are a problem. A cottage door
		# always has a lantern, a sign, or a bench within a couple of metres, so a
		# fixed clearance radius would flag ordinary front-garden dressing.
		var doorway := _gate_rect(gate)
		var blocking := 0
		for prop in props:
			if not (prop is Node3D):
				continue
			var prop_at := Vector2(prop.position.x, prop.position.z)
			var clearance := _distance_to_rect(doorway, prop_at)
			if clearance < 0.45:
				blocking += 1
				print("     prop %s at %s is %.2fm from the doorway" % [prop.name, _fmt2(prop_at), clearance])
		if blocking > 0:
			print("     ^^ %d props block the doorway" % blocking)


# --- rivers ----------------------------------------------------------------


func _gate_rect(gate: Node) -> Dictionary:
	var size := Vector2(2.0, 0.8)
	var collider := gate.get_node_or_null("Collision") as CollisionShape3D
	if collider != null and collider.shape is BoxShape3D:
		var box := collider.shape as BoxShape3D
		size = Vector2(box.size.x, box.size.z)
	var node := gate as Node3D
	return {
		"at": Vector2(node.position.x, node.position.z),
		"angle": node.rotation.y,
		"rects": [{"half": size * 0.5, "offset": Vector2.ZERO}],
	}


func _check_rivers(props: Array[Node], rivers: Array[Dictionary]) -> void:
	print("\n[R] PROPS STANDING IN WATER")
	var count := 0
	for child in props:
		if not (child is Node3D):
			continue
		var kind := int(child.get("kind")) if "kind" in child else -1
		if kind in WATER_FRIENDLY:
			continue
		var at := Vector2(child.position.x, child.position.z)
		for river in rivers:
			if not bool(river["transparent"]):
				continue
			if _to_polyline(at, river["points"]) < float(river["width"]) * 0.5:
				count += 1
				print("  %s (kind %d) at %s in %s" % [child.name, kind, _fmt2(at), river["name"]])
				break
	if count == 0:
		print("  none")


# --- H: performance surface ------------------------------------------------


func _performance(town: Node3D, props: Array[Node], buildings: Array[Node]) -> void:
	print("\n[H] CONTENT / PERFORMANCE SURFACE")
	var kinds := {}
	for child in props:
		if child is Node3D and "kind" in child:
			var kind := int(child.get("kind"))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	for kind in kinds:
		print("  prop kind %-2d x%d" % [kind, kinds[kind]])

	var meshes := 0
	var lights := 0
	var bodies := 0
	var shapes := 0
	var multimeshes := 0
	var labels := 0
	var total := 0
	var counts := {
		"nodes": 0, "mesh_instances": 0, "multimesh": 0, "lights": 0,
		"static_bodies": 0, "collision_shapes": 0, "label3d": 0,
	}
	_tally(town, counts)
	total = int(counts["nodes"])
	meshes = int(counts["mesh_instances"])
	multimeshes = int(counts["multimesh"])
	lights = int(counts["lights"])
	bodies = int(counts["static_bodies"])
	shapes = int(counts["collision_shapes"])
	labels = int(counts["label3d"])
	print("  nodes=%d mesh_instances=%d multimesh=%d lights=%d static_bodies=%d shapes=%d label3d=%d" % [
		total, meshes, multimeshes, lights, bodies, shapes, labels
	])
	print("  buildings=%d forest_props=%d" % [buildings.size(), _forest_props(town)])

	# The biggest visual clusters are the first place to look when frames drop.
	var top: Array[Dictionary] = []
	for group_name in ["Buildings", "Props", "Forest"]:
		var group := town.get_node_or_null(group_name)
		if group == null:
			continue
		for child in group.get_children():
			var meshes_here := _count_type(child, MeshInstance3D)
			top.append({"name": "%s/%s" % [group_name, child.name], "meshes": meshes_here})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["meshes"]) > int(b["meshes"]))
	for i in mini(8, top.size()):
		print("  heavy: %-38s %d meshes" % [top[i]["name"], top[i]["meshes"]])


func _forest_props(town: Node3D) -> int:
	var forest := town.get_node_or_null("Forest")
	if forest == null:
		return 0
	var count := 0
	for child in forest.get_children():
		if child is TownProp:
			count += 1
	return count


func _count_type(node: Node, type: Variant) -> int:
	var total := 1 if is_instance_of(node, type) else 0
	for child in node.get_children():
		total += _count_type(child, type)
	return total


func _tally(node: Node, counts: Dictionary) -> void:
	counts["nodes"] = int(counts["nodes"]) + 1
	if node is MultiMeshInstance3D:
		counts["multimesh"] = int(counts["multimesh"]) + 1
	elif node is MeshInstance3D:
		counts["mesh_instances"] = int(counts["mesh_instances"]) + 1
	elif node is Light3D:
		counts["lights"] = int(counts["lights"]) + 1
	elif node is StaticBody3D:
		counts["static_bodies"] = int(counts["static_bodies"]) + 1
	elif node is CollisionShape3D:
		counts["collision_shapes"] = int(counts["collision_shapes"]) + 1
	elif node is Label3D:
		counts["label3d"] = int(counts["label3d"]) + 1
	for child in node.get_children():
		_tally(child, counts)


# --- geometry helpers ------------------------------------------------------


func _corners(footprint: Dictionary, rect: Dictionary) -> PackedVector2Array:
	var half: Vector2 = rect["half"]
	var offset: Vector2 = rect["offset"]
	var angle: float = footprint["angle"]
	var at: Vector2 = footprint["at"]
	var points := PackedVector2Array()
	var signs: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner in signs:
		# Godot's Y rotation turns the other way from Vector2.rotated(), so a
		# building facing `angle` puts local (x, z) at `local.rotated(-angle)`.
		var local := Vector2(corner.x * half.x, corner.y * half.y) + offset
		points.append(local.rotated(-angle) + at)
	return points


func _all_corners(footprint: Dictionary) -> Array[PackedVector2Array]:
	var made: Array[PackedVector2Array] = []
	for rect in footprint["rects"]:
		made.append(_corners(footprint, rect))
	return made


func _rect_overlap(a: Dictionary, b: Dictionary) -> float:
	var best := INF
	for poly_a in _all_corners(a):
		for poly_b in _all_corners(b):
			var depth := _poly_overlap(poly_a, poly_b)
			if depth <= 0.0:
				return 0.0
			best = minf(best, depth)
	return best if best != INF else 0.0


func _poly_overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var least := INF
	for poly_value in [a, b]:
		var poly: PackedVector2Array = poly_value
		for i in poly.size():
			var edge: Vector2 = poly[(i + 1) % poly.size()] - poly[i]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var a_span := _project(a, axis)
			var b_span := _project(b, axis)
			var overlap := minf(a_span.y, b_span.y) - maxf(a_span.x, b_span.x)
			if overlap <= 0.0:
				return 0.0
			least = minf(least, overlap)
	return least


func _project(poly: PackedVector2Array, axis: Vector2) -> Vector2:
	var low := INF
	var high := -INF
	for point in poly:
		var value := point.dot(axis)
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


func _distance(a: Dictionary, b: Dictionary) -> float:
	return (a["at"] as Vector2).distance_to(b["at"] as Vector2)


func _point_in(footprint: Dictionary, at: Vector2, margin: float) -> bool:
	for rect in footprint["rects"]:
		var half: Vector2 = rect["half"]
		var offset: Vector2 = rect["offset"]
		var angle: float = footprint["angle"]
		var local := at - (footprint["at"] as Vector2)
		# Inverse of the local-to-world turn above.
		local = local.rotated(angle) - offset
		if absf(local.x) <= half.x + margin and absf(local.y) <= half.y + margin:
			return true
	return false


func _distance_to_rect(footprint: Dictionary, at: Vector2) -> float:
	var best := INF
	for poly in _all_corners(footprint):
		for i in poly.size():
			best = minf(best, _to_segment(at, poly[i], poly[(i + 1) % poly.size()]))
	return best


## Returns the arc-length at which the polyline first enters the footprint, or -1.
func _rect_hits_polyline(footprint: Dictionary, points: PackedVector3Array) -> float:
	var travelled := 0.0
	for i in points.size() - 1:
		var from := Vector2(points[i].x, points[i].z)
		var to := Vector2(points[i + 1].x, points[i + 1].z)
		var length := from.distance_to(to)
		var steps := maxi(2, int(length / 0.5))
		for step in steps + 1:
			var at := from.lerp(to, float(step) / float(steps))
			if _point_in(footprint, at, -0.05):
				return travelled + length * (float(step) / float(steps))
		travelled += length
	return -1.0


func _to_polyline(at: Vector2, points: PackedVector3Array) -> float:
	var best := INF
	for i in points.size() - 1:
		best = minf(best, _to_segment(at, Vector2(points[i].x, points[i].z), Vector2(points[i + 1].x, points[i + 1].z)))
	return best


func _nearest_on_polyline(at: Vector2, points: PackedVector3Array) -> Vector2:
	var best := INF
	var nearest := at
	for i in points.size() - 1:
		var from := Vector2(points[i].x, points[i].z)
		var to := Vector2(points[i + 1].x, points[i + 1].z)
		var projected := Geometry2D.get_closest_point_to_segment(at, from, to)
		var distance := at.distance_to(projected)
		if distance < best:
			best = distance
			nearest = projected
	return nearest


func _to_segment(at: Vector2, from: Vector2, to: Vector2) -> float:
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at, from, to))


func _fmt2(at: Vector2) -> String:
	return "(%.1f, %.1f)" % [at.x, at.y]
