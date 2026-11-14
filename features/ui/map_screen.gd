extends Control
## Full-screen storybook map of Mycelgrove Hollow, toggled with the `map` action.
##
## The screen is a child of the HUD, so every gameplay scene gets it for free.
## While it is open the player is UI-blocked and the mouse is released, exactly
## like the inventory panel. See AGENTS.md sections 6 and 7.
##
## The two outlying villages are drawn as storybook cards along the edge of the
## map they lie beyond. Their names, moods, symbols, and colours come from
## `TownRealm.VILLAGES`, so the map and the world can never disagree.

## The town generator maps the reference image with
## `x = (px - 656) * 0.14` and `z = (py - 600) * 0.14`, so these invert it.
const TOWN_SCENE := "res://scenes/town.tscn"
const MAP_CENTER := Vector2(656.0, 600.0)
const MAP_SCALE := 0.14
## How close the player must be to a village centre for its card to light up.
const VILLAGE_REACH := 60.0

@onready var _image: TextureRect = %MapImage
@onready var _marker: Label = %YouAreHere
@onready var _location: Label = %Location

var _player: PlayerController
## Village name -> its card on the map.
var _cards: Dictionary = {}
## Village name -> its "Travel here" button.
var _travel_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Events.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING and not visible:
		return
	if _dialogue_is_open():
		return

	if event.is_action_pressed("map"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# Escape closes the map instead of opening the pause menu while it is up.
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _dialogue_is_open():
		return

	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_put_inventory_away()
	visible = true
	if is_instance_valid(_player):
		_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_record_visit()
	_build_cards()
	_refresh_marker()


func close() -> void:
	visible = false
	if is_instance_valid(_player):
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


## Marks the player on the town map. Other scenes (the room, interiors) don't
## share this map, so the tag hides there. It also hides once the player walks
## beyond the map's edges: past that point the town plan no longer covers the
## ground, and the village card is the useful readout instead.
func _refresh_marker() -> void:
	_marker.visible = false
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != TOWN_SCENE:
		return
	if not is_instance_valid(_player) or _image.texture == null or _image.size.x <= 0.0:
		return

	var here := _player.global_position
	var reach := _image.size * 0.5 * MAP_SCALE
	if absf(here.x) > reach.x or absf(here.z) > reach.y:
		# The map no longer covers the ground underfoot, so the village card and
		# the footer carry the location instead of the "You are here" tag.
		_highlight_nearest_village(here)
		return

	var size := _image.texture.get_size()
	var px := MAP_CENTER.x + here.x / MAP_SCALE
	var py := MAP_CENTER.y + here.z / MAP_SCALE
	var at := Vector2(px / size.x, py / size.y) * _image.size
	_marker.position = at - Vector2(0.0, 18.0)
	_marker.visible = true

	_highlight_nearest_village(here)


## Builds one storybook card per outlying village, anchored to the edge of the
## map it lies beyond. Cards are built once and reused, because the map can be
## opened and closed all session.
func _build_cards() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_image):
		return

	if _cards.is_empty():
		for definition in TownRealm.VILLAGES:
			_add_card(definition)
	_layout_cards()
	_refresh_travel()


func _add_card(definition: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "%sCard" % definition["name"]
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style(definition))
	_image.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var title := Label.new()
	title.text = String(definition["name"])
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.78))
	box.add_child(title)

	var mood := Label.new()
	mood.text = String(definition["mood"])
	mood.add_theme_font_size_override("font_size", 12)
	mood.add_theme_color_override("font_color", Color(0.72, 0.65, 0.52))
	box.add_child(mood)

	var symbol := Label.new()
	symbol.text = String(definition["symbol"])
	symbol.add_theme_font_size_override("font_size", 12)
	symbol.add_theme_color_override("font_color", Color(0.86, 0.81, 0.68))
	symbol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	symbol.custom_minimum_size = Vector2(196.0, 0.0)
	box.add_child(symbol)

	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 3)
	for color in definition["swatches"]:
		var chip := ColorRect.new()
		chip.color = color
		chip.custom_minimum_size = Vector2(20.0, 13.0)
		swatches.add_child(chip)
	box.add_child(swatches)

	# Fast travel. The button is built with the card but only becomes usable
	# once the player has stood in the village at least once, so the map cannot
	# skip the walk the first time.
	var travel := Button.new()
	travel.name = "TravelButton"
	travel.text = "Travel here"
	travel.add_theme_font_size_override("font_size", 13)
	travel.pressed.connect(_travel_to.bind(definition))
	box.add_child(travel)
	_travel_buttons[definition["name"]] = travel

	_cards[definition["name"]] = card


func _layout_cards() -> void:
	await get_tree().process_frame
	var size := _image.size
	for definition in TownRealm.VILLAGES:
		var card := _cards.get(definition["name"]) as Control
		if card == null:
			continue
		var wanted := card.get_combined_minimum_size()
		match String(definition["edge"]):
			"north":
				card.position = Vector2((size.x - wanted.x) * 0.5, 10.0)
			"south":
				card.position = Vector2((size.x - wanted.x) * 0.5, size.y - wanted.y - 10.0)
			"east":
				card.position = Vector2(size.x - wanted.x - 10.0, (size.y - wanted.y) * 0.5)
			_:
				card.position = Vector2(10.0, (size.y - wanted.y) * 0.5)


func _card_style(definition: Dictionary) -> StyleBoxFlat:
	var swatches: Array = definition["swatches"]
	var made := StyleBoxFlat.new()
	made.bg_color = Color(0.1, 0.09, 0.07, 0.92)
	made.border_color = swatches[1]
	made.set_border_width_all(2)
	made.set_corner_radius_all(4)
	made.content_margin_left = 10.0
	made.content_margin_right = 10.0
	made.content_margin_top = 7.0
	made.content_margin_bottom = 7.0
	made.shadow_color = Color(0.02, 0.015, 0.01, 0.6)
	made.shadow_size = 6
	return made


## Lights the card of the village the player is standing in, darkens the others,
## and writes the name into the footer.
func _highlight_nearest_village(here: Vector3) -> void:
	var nearest := ""
	var best := VILLAGE_REACH
	for definition in TownRealm.VILLAGES:
		var centre: Vector2 = definition["centre"]
		var distance := Vector2(here.x, here.z).distance_to(centre)
		if distance < best:
			best = distance
			nearest = String(definition["name"])

	for key in _cards:
		var card := _cards[key] as Control
		if card != null:
			card.modulate = Color(1, 1, 1, 1) if key == nearest else Color(1, 1, 1, 0.72)
	_set_location(nearest)


func _set_location(village: String) -> void:
	if _location != null:
		_location.text = "Mycelgrove Hollow" if village.is_empty() else village


## Visiting a village on foot is what teaches the map to send you back. The
## flag is stored in `QuestLog` so it rides along in the save file with the
## rest of the world state.
func _record_visit() -> void:
	var realm := _town_realm()
	if realm == null or not is_instance_valid(_player):
		return

	var here := Vector2(_player.global_position.x, _player.global_position.z)
	for definition in TownRealm.VILLAGES:
		var centre: Vector2 = definition["centre"]
		if here.distance_to(centre) > VILLAGE_REACH:
			continue
		if QuestLog.set_flag(_visit_flag(definition["kind"])):
			Events.notification_requested.emit(
				"Map: %s added to fast travel" % definition["name"]
			)


func _visit_flag(village_kind: StringName) -> StringName:
	return StringName("visited.%s" % village_kind)


## Updates the three travel buttons from the current scene and the visited
## flags. Only the town scene has a `TownRealm`, so travel is unavailable in
## interiors and the mine.
func _refresh_travel() -> void:
	var realm := _town_realm()
	var here := Vector2.INF
	if is_instance_valid(_player):
		here = Vector2(_player.global_position.x, _player.global_position.z)

	for definition in TownRealm.VILLAGES:
		var button := _travel_buttons.get(definition["name"]) as Button
		if button == null:
			continue

		var centre: Vector2 = definition["centre"]
		var visited := QuestLog.has_flag(_visit_flag(definition["kind"]))
		var near := here != Vector2.INF \
			and here.distance_to(centre) <= VILLAGE_REACH

		button.visible = realm != null
		button.disabled = not visited or near
		if near:
			button.text = "You are here"
		elif not visited:
			button.text = "Travel (visit first)"
		else:
			button.text = "Travel here"


## Same-scene teleport: the village is already part of the town scene, so this
## moves the body through `PlayerController.teleport_to()` instead of loading
## anything. The map closes first so the player regains the mouse.
func _travel_to(definition: Dictionary) -> void:
	if _town_realm() == null:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if not is_instance_valid(_player):
		return

	var kind: StringName = definition["kind"]
	var at := TownRealm.arrival_for(kind)
	if at == Vector3.ZERO:
		return

	QuestLog.set_flag(_visit_flag(kind))
	close()
	_player.teleport_to(at)
	Events.notification_requested.emit("Travelled to %s" % definition["name"])


func _town_realm() -> TownRealm:
	return get_tree().get_first_node_in_group(&"town_realm") as TownRealm


func _dialogue_is_open() -> bool:
	var window := get_parent().get_node_or_null("DialogueWindow") as Control
	return window != null and window.visible


func _put_inventory_away() -> void:
	var hud := get_parent()
	if hud != null and hud.has_method("close_inventory"):
		get_parent().call("close_inventory")


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
