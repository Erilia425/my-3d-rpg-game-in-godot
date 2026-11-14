class_name BountyBoard
extends StaticBody3D
## The notice board in the market square.
##
## Three standing errands anyone can take, so quests are not limited to the two
## named villagers. Each errand asks for gathered goods and pays coins and
## experience; none of them can be "finished", they simply come round again, and
## the board remembers how many times each has been paid.
##
## The board never owns inventory or coins. It reads the player's
## `InventoryComponent` and pays through `Progression`, exactly like a shop.
## See AGENTS.md 6.3.

## Stable id for the save file. Leave empty for a board that should not persist.
@export var save_id: StringName = &"board.market_square"

const TITLE := "The Notice Board"
const SUBTITLE := (
	"Errands pinned by people who would rather not ask in person. Bring the"
	+ " goods; the tin takes the payment out of the same box."
)

## One row per errand. `counts` is how many times this board has paid it, and
## only exists to make the reward creep upward a little.
const BOUNTIES: Array[Dictionary] = [
	{
		"title": "Fieldstone for the causeway",
		"item": &"item.stone",
		"amount": 5,
		"coins": 20,
		"xp": 20,
		"line": "Bryn Thorne, Thornridge. The east bridge loses a stone a season.",
	},
	{
		"title": "Spruce for the boardwalk",
		"item": &"item.spruce_log",
		"amount": 4,
		"coins": 22,
		"xp": 22,
		"line": "Pell, Ashfall. The bog eats the planks faster than we cut them.",
	},
	{
		"title": "Flowers for the chapel",
		"item": &"item.flower",
		"amount": 3,
		"coins": 18,
		"xp": 18,
		"line": "Chapel. For the sill, on the days nobody comes.",
	},
	{
		"title": "Mushrooms for the pot",
		"item": &"item.mushroom",
		"amount": 3,
		"coins": 18,
		"xp": 18,
		"line": "The communal kitchen. Nothing stronger than ghost-cap, please.",
	},
]

var _open := false
var _player: Node = null
var _opened_frame := -1
## Errand title (as String) -> times paid.
var _counts: Dictionary = {}
## Last message shown in the panel, so a refusal is visible where it happened.
var _status_text := SUBTITLE

var _layer: CanvasLayer
var _panel: PanelContainer
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	if not save_id.is_empty():
		add_to_group(&"saveable")
	_build_ui()
	_build_visual()
	Events.game_state_changed.connect(_on_game_state_changed)


# --- interaction -----------------------------------------------------------


func get_interaction_text() -> String:
	return "" if _open else "Read the notice board"


func interact(interactor: Node) -> void:
	if _open:
		return
	_open_panel(interactor)


func is_open() -> bool:
	return _open


## How many times this errand has been paid. Exposed for tests and the panel.
func get_bounty_count(index: int) -> int:
	if index < 0 or index >= BOUNTIES.size():
		return 0
	return int(_counts.get(String(BOUNTIES[index]["title"]), 0))


## Pays one errand when the goods are in the bag. Returns true when it paid.
func pay(index: int, interactor: Node) -> bool:
	if index < 0 or index >= BOUNTIES.size():
		return false
	var bounty: Dictionary = BOUNTIES[index]
	var inventory := _inventory(interactor)
	if inventory == null:
		return false

	var item: StringName = bounty["item"]
	var need: int = int(bounty["amount"])
	if inventory.get_amount(item) < need:
		_status_text = "You need %d %s." % [need, _name_of(item)]
		_refresh()
		return false

	if not inventory.remove_item(item, need):
		_status_text = "The tin would not take them."
		_refresh()
		return false

	var times := get_bounty_count(index)
	# A small creep so repeat visits feel noticed without becoming a money
	# press: every fifth payment adds five coins.
	var bonus := 5 * int(times / 5)
	Progression.add_coins(int(bounty["coins"]) + bonus)
	Progression.add_xp(int(bounty["xp"]))
	_counts[String(bounty["title"])] = times + 1

	_status_text = "Paid: %d coins. Someone will be glad of that." % (
		int(bounty["coins"]) + bonus
	)
	Events.notification_requested.emit("Bounty paid: %d coins" % (
		int(bounty["coins"]) + bonus
	))
	_refresh()
	return true


# --- panel -----------------------------------------------------------------


func _open_panel(interactor: Node) -> void:
	_open = true
	_player = interactor
	_opened_frame = Engine.get_process_frames()
	_status.text = _status_text
	_panel.visible = true
	_layer.visible = true
	_refresh()

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	_layer.visible = false

	if _player != null and _player.has_method("set_ui_blocked"):
		_player.call("set_ui_blocked", false)
	_player = null

	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("interact"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		close_panel()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var inventory := _inventory(_player)
	for index in BOUNTIES.size():
		var bounty: Dictionary = BOUNTIES[index]
		var item: StringName = bounty["item"]
		var need: int = int(bounty["amount"])
		var held := 0 if inventory == null else inventory.get_amount(item)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		_list.add_child(row)

		var heading := Label.new()
		heading.text = "%s  —  %d %s" % [bounty["title"], need, _name_of(item)]
		row.add_child(heading)

		var line := Label.new()
		line.text = bounty["line"]
		line.modulate = Color(0.78, 0.76, 0.7, 1)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(line)

		var actions := HBoxContainer.new()
		row.add_child(actions)

		var held_label := Label.new()
		held_label.text = "you have %d" % held
		held_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(held_label)

		var button := Button.new()
		button.text = "Deliver (%d coins)" % int(bounty["coins"])
		button.disabled = held < need
		button.pressed.connect(_on_pay.bind(index))
		actions.add_child(button)


func _on_pay(index: int) -> void:
	pay(index, _player)
	_status.text = _status_text


# --- helpers ---------------------------------------------------------------


func _inventory(interactor: Node) -> InventoryComponent:
	if interactor == null or not interactor.has_method("get_inventory_component"):
		return null
	return interactor.call("get_inventory_component") as InventoryComponent


func _name_of(id: StringName) -> String:
	var data := ItemDatabase.get_item(id)
	return String(id) if data == null else data.display_name


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "BoardUI"
	_layer.layer = 3
	add_child(_layer)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 420)
	centre.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = TITLE
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	layout.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	layout.add_child(_list)

	layout.add_child(HSeparator.new())

	_status = Label.new()
	_status.text = _status_text
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_panel)
	layout.add_child(close_button)

	_panel.visible = false
	_layer.visible = false


func _build_visual() -> void:
	if get_node_or_null("Board") != null:
		return
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.42, 0.32, 0.21, 1)
	plank.roughness = 0.92
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.24, 0.18, 0.12, 1)
	dark.roughness = 0.95
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.88, 0.84, 0.72, 1)
	paper.roughness = 0.8

	var board := MeshInstance3D.new()
	board.name = "Board"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.9, 1.1, 0.08)
	board.mesh = board_mesh
	board.material_override = plank
	board.position = Vector3(0, 1.35, 0)
	add_child(board)

	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "Post"
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.12, 1.9, 0.12)
		post.mesh = post_mesh
		post.material_override = dark
		post.position = Vector3(side * 0.82, 0.95, 0)
		add_child(post)

	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(2.05, 0.08, 0.34)
	roof.mesh = roof_mesh
	roof.material_override = dark
	roof.position = Vector3(0, 1.96, 0.02)
	add_child(roof)

	# Three paper notices, slightly crooked, so the board reads before the panel.
	var notes := [
		{"at": Vector3(-0.5, 1.5, 0.05), "size": Vector3(0.42, 0.5, 0.01), "rot": 0.05},
		{"at": Vector3(0.05, 1.42, 0.05), "size": Vector3(0.38, 0.44, 0.01), "rot": -0.07},
		{"at": Vector3(0.58, 1.52, 0.05), "size": Vector3(0.34, 0.38, 0.01), "rot": 0.11},
	]
	for note in notes:
		var page := MeshInstance3D.new()
		page.name = "Notice"
		var page_mesh := BoxMesh.new()
		page_mesh.size = note["size"]
		page.mesh = page_mesh
		page.material_override = paper
		page.position = note["at"]
		page.rotation.z = note["rot"]
		add_child(page)


# --- persistence -----------------------------------------------------------


func get_save_id() -> StringName:
	return save_id


func save_data() -> Dictionary:
	return {"counts": _counts.duplicate()}


func load_data(data: Dictionary) -> void:
	_counts.clear()
	var saved: Variant = data.get("counts", {})
	if saved is Dictionary:
		for raw_key: Variant in (saved as Dictionary).keys():
			_counts[String(raw_key)] = maxi(int((saved as Dictionary)[raw_key]), 0)
	if _open:
		_refresh()
