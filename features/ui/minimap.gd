class_name Minimap
extends Control
## A small parchment map in the corner of the HUD.
##
## It shows only ground the player has already walked (`WorldMap`), so the
## world opens up as it is explored instead of arriving as a finished atlas.
## One square is 16 m; the view is 17 squares across, which covers a little
## under 300 m — enough to see the next landmark, not enough to read the map.
##
## Redraws are driven by the HUD's half-second clock tick, never per frame.
## See AGENTS.md 10.2.

const VIEW_CELLS := 17
const CELL_PX := 10.0
const MAP_PX := VIEW_CELLS * CELL_PX

const C_FRAME := Color(0.28, 0.24, 0.18, 0.95)
const C_PARCHMENT := Color(0.84, 0.77, 0.6, 1)
const C_FOG := Color(0.38, 0.34, 0.28, 1)
const C_LAND := Color(0.56, 0.62, 0.45, 1)
const C_TOWN := Color(0.72, 0.65, 0.47, 1)
const C_ROAD := Color(0.66, 0.56, 0.4, 1)
const C_PLAYER := Color(0.95, 0.87, 0.62, 1)

var _here := Vector3.ZERO
var _yaw := 0.0
var _has_player := false


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_PX, MAP_PX)
	size = Vector2(MAP_PX, MAP_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called by the HUD on its clock tick. Records the player's surroundings and
## redraws.
func refresh_view(at: Vector3, yaw: float) -> void:
	_here = at
	_yaw = yaw
	_has_player = true
	WorldMap.reveal(at)
	queue_redraw()


func _draw() -> void:
	var origin := Vector2.ZERO
	# Frame and parchment.
	draw_rect(Rect2(origin, Vector2(MAP_PX, MAP_PX)), C_FRAME, true)
	draw_rect(Rect2(origin + Vector2(3, 3), Vector2(MAP_PX - 6, MAP_PX - 6)), C_PARCHMENT, true)

	if not _has_player:
		return

	var centre_cell := WorldMap.cell_of(_here)
	var half := VIEW_CELLS / 2
	# The player's square is the middle of the view. The offset keeps the map
	# from jumping a whole square at a time as the player walks.
	var offset := Vector2(
		fposmod(_here.x, WorldMap.CELL_SIZE), fposmod(_here.z, WorldMap.CELL_SIZE)
	) / WorldMap.CELL_SIZE

	for row in VIEW_CELLS:
		for column in VIEW_CELLS:
			var cell_x := centre_cell.x + column - half
			var cell_z := centre_cell.y + row - half
			var at := Vector2(column, row) * CELL_PX + Vector2(3, 3)
			var colour := C_FOG
			if WorldMap.is_seen(cell_x, cell_z):
				colour = C_LAND
				# The town square and the two roads are painted, not invented:
				# the map knows where they are because the town is at the origin.
				var world_cell := Vector2(
					(cell_x + 0.5) * WorldMap.CELL_SIZE,
					(cell_z + 0.5) * WorldMap.CELL_SIZE
				)
				if absf(world_cell.x) < 90.0 and absf(world_cell.y) < 90.0:
					colour = C_TOWN
				elif absf(world_cell.y) < 14.0 or absf(world_cell.x) < 14.0:
					colour = C_ROAD
			draw_rect(Rect2(at, Vector2(CELL_PX - 0.6, CELL_PX - 0.6)), colour, true)

	# The player, as an arrow at the middle, turning with the body.
	var centre := Vector2(MAP_PX * 0.5, MAP_PX * 0.5)
	centre += (Vector2(0.5, 0.5) - offset) * CELL_PX
	var forward := Vector2(sin(_yaw), -cos(_yaw))
	draw_circle(centre, 3.2, C_PLAYER)
	draw_line(centre, centre + forward * 8.0, C_PLAYER, 2.0)

	# North marker in the corner of the parchment.
	var ui_font := get_theme_default_font()
	if ui_font != null:
		draw_string(
			ui_font,
			Vector2(MAP_PX - 15.0, 15.0),
			"N",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			C_FRAME
		)
