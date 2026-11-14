extends Node3D
## Mycelgrove Hollow: the village the player's cottage sits in.
##
## The scene is a blockout of the reference map — the chapel, bell tower, market
## square, residential row, keepers' quarter, beekeepers, old quarter, cemetery,
## and the river with its bridges. Buildings and props assemble themselves from
## primitives at `_ready()` (`TownBuilding`, `TownProp`), so the saved scene stays
## a short list of placements instead of thousands of hand-placed nodes.
##
## The player's cottage is enterable; it leads to `scenes/test_room.tscn` through
## an `AreaGate`, and the rest of the village doors open their own interiors. The
## wider world grows around the village from the sibling `Realm` node
## (`TownRealm`) rather than through a gate to another scene.
## See AGENTS.md sections 4, 7, and 10.

func _ready() -> void:
	Game.set_state(Game.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
