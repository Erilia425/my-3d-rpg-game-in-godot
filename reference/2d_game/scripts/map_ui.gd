
extends Control

@export var cell_size: float = 64.0
@export var map_columns: int = 32
@export var map_rows: int = 32
@export var map_world_origin: Vector2 = Vector2(-1024, -1024)
@export var reveal_radius: int = 3
@export var show_minimap_at_start: bool = true

var player: Node2D = null
var revealed_cells: Dictionary = {}

var full_map_open: bool = false
var minimap_visible: bool = true


func _ready() -> void:
	# Fill the viewport through anchors, without manually setting size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2.ZERO

	visible = true
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	full_map_open = false
	minimap_visible = show_minimap_at_start

	# Find Fern by group first, then by node name.
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		player = players[0] as Node2D
	else:
		player = get_tree().root.find_child(
			"player", true, false
		) as Node2D

	if player == null:
		push_error(
			"MapUI: Player not found. Add Fern to the 'player' group."
		)
		set_process(false)
		set_process_input(false)
		return

	print("MapUI: Found player: ", player.name)
	print("M = full map, N = toggle minimap")

	reveal_player_area()
	queue_redraw()

	print("MapUI visible: ", visible)
	print("MapUI size: ", size)
	print("Minimap enabled: ", minimap_visible)


func _process(_delta: float) -> void:
	if player == null:
		return

	reveal_player_area()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("map"):
			full_map_open = not full_map_open
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("toggle_minimap"):
			minimap_visible = not minimap_visible
			queue_redraw()
			get_viewport().set_input_as_handled()


func reveal_player_area() -> void:
	if player == null:
		return

	var player_cell: Vector2i = world_to_cell(player.global_position)

	for x in range(
		player_cell.x - reveal_radius,
		player_cell.x + reveal_radius + 1
	):
		for y in range(
			player_cell.y - reveal_radius,
			player_cell.y + reveal_radius + 1
		):
			if x >= 0 and x < map_columns and y >= 0 and y < map_rows:
				revealed_cells[Vector2i(x, y)] = true


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position: Vector2 = world_position - map_world_origin

	return Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.y / cell_size)
	)


func _draw() -> void:
	if full_map_open:
		draw_full_map()
	elif minimap_visible:
		draw_minimap()


func draw_full_map() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var map_pixel_size: Vector2 = Vector2(
		map_columns * cell_size,
		map_rows * cell_size
	)

	var available_size: Vector2 = viewport_size - Vector2(100.0, 100.0)

	# Explicit float types prevent Variant inference warnings.
	var scale_factor: float = minf(
		minf(
			available_size.x / map_pixel_size.x,
			available_size.y / map_pixel_size.y
		),
		1.0
	)

	scale_factor = maxf(scale_factor, 0.1)

	var displayed_size: Vector2 = map_pixel_size * scale_factor
	var map_position: Vector2 = (viewport_size - displayed_size) / 2.0

	# Darkened background.
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color(0.04, 0.035, 0.025, 0.82)
	)

	# Parchment background and ink border.
	draw_rect(
		Rect2(map_position, displayed_size),
		Color(0.78, 0.68, 0.48, 0.98)
	)
	draw_rect(
		Rect2(map_position, displayed_size),
		Color(0.25, 0.17, 0.09),
		false,
		4.0
	)

	# Draw explored and unexplored cells.
	for x in range(map_columns):
		for y in range(map_rows):
			var cell: Vector2i = Vector2i(x, y)
			var cell_position: Vector2 = map_position + Vector2(
				x * cell_size * scale_factor,
				y * cell_size * scale_factor
			)
			var cell_rect: Rect2 = Rect2(
				cell_position,
				Vector2.ONE * cell_size * scale_factor
			)

			if revealed_cells.has(cell):
				draw_rect(
					cell_rect,
					Color(0.66, 0.56, 0.38, 0.55)
				)
				draw_rect(
					cell_rect,
					Color(0.30, 0.22, 0.13, 0.25),
					false,
					1.0
				)
			else:
				draw_rect(
					cell_rect,
					Color(0.12, 0.10, 0.08, 0.96)
				)

	# Mark Fern's position.
	if player != null:
		var player_cell: Vector2i = world_to_cell(player.global_position)

		if (
			player_cell.x >= 0
			and player_cell.x < map_columns
			and player_cell.y >= 0
			and player_cell.y < map_rows
		):
			var marker_position: Vector2 = map_position + Vector2(
				(player_cell.x + 0.5) * cell_size * scale_factor,
				(player_cell.y + 0.5) * cell_size * scale_factor
			)

			draw_circle(
				marker_position,
				maxf(5.0, 7.0 * scale_factor),
				Color(0.65, 0.12, 0.08)
			)

	draw_string(
		ThemeDB.fallback_font,
		map_position + Vector2(12.0, -12.0),
		"THE LEDGER - EXPLORED LANDS",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(0.88, 0.78, 0.56)
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(24.0, viewport_size.y - 24.0),
		"M: Close Map",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color(0.95, 0.88, 0.72)
	)


func draw_minimap() -> void:
	var mini_cell_size: float = 5.0
	var mini_width: float = map_columns * mini_cell_size
	var mini_height: float = map_rows * mini_cell_size
	var margin: float = 20.0

	var mini_position: Vector2 = Vector2(
		get_viewport_rect().size.x - mini_width - margin,
		margin
	)

	var backing_rect: Rect2 = Rect2(
		mini_position - Vector2(8.0, 8.0),
		Vector2(mini_width + 16.0, mini_height + 16.0)
	)

	# Parchment backing and ink border.
	draw_rect(
		backing_rect,
		Color(0.72, 0.61, 0.42, 0.94)
	)
	draw_rect(
		backing_rect,
		Color(0.24, 0.16, 0.09),
		false,
		2.0
	)

	# Draw the minimap grid.
	for x in range(map_columns):
		for y in range(map_rows):
			var cell: Vector2i = Vector2i(x, y)
			var cell_position: Vector2 = mini_position + Vector2(
				x * mini_cell_size,
				y * mini_cell_size
			)

			var cell_color: Color = Color(0.10, 0.085, 0.065, 1.0)

			if revealed_cells.has(cell):
				cell_color = Color(0.62, 0.51, 0.34, 1.0)

			draw_rect(
				Rect2(
					cell_position,
					Vector2.ONE * mini_cell_size
				),
				cell_color
			)

	# Red dot marks Fern.
	if player != null:
		var player_cell: Vector2i = world_to_cell(player.global_position)

		if (
			player_cell.x >= 0
			and player_cell.x < map_columns
			and player_cell.y >= 0
			and player_cell.y < map_rows
		):
			var marker_position: Vector2 = mini_position + Vector2(
				(player_cell.x + 0.5) * mini_cell_size,
				(player_cell.y + 0.5) * mini_cell_size
			)

			draw_circle(
				marker_position,
				4.0,
				Color(0.70, 0.10, 0.08)
			)
