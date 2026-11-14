extends CanvasLayer
## Gameplay HUD: crosshair, interaction prompt, toasts, vitals, and inventory.
##
## The HUD only listens to signals and displays them. It never changes gameplay
## state directly; it asks the player to equip or use an item. See AGENTS.md
## section 6.

@onready var _crosshair: Control = %Crosshair
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _toast_label: Label = %ToastLabel
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _memory_bar: ProgressBar = %MemoryBar
@onready var _memory_label: Label = %MemoryLabel
@onready var _silk_label: Label = %SilkLabel
@onready var _anchor_label: Label = %AnchorLabel
@onready var _ledger_label: Label = %LedgerLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _tool_label: Label = %ToolLabel
@onready var _time_label: Label = %TimeLabel
@onready var _clock_timer: Timer = %ClockTimer
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _item_list: ItemList = %ItemList
@onready var _action_button: Button = %EquipButton
@onready var _close_button: Button = %CloseButton
@onready var _map_screen: Control = get_node_or_null("MapScreen") as Control
@onready var _journal: Control = get_node_or_null("QuestJournal") as Control
@onready var _ledger_shop: Control = get_node_or_null("LedgerShopPanel") as Control
@onready var _dialogue_window: Control = get_node_or_null("DialogueWindow") as Control
@onready var _minimap: Control = get_node_or_null("Minimap") as Control
@onready var _field_notes: Control = get_node_or_null("FieldNotes") as Control

var _interact_key := "E"
var _inventory_key := "I"
var _toast_tween: Tween
var _damage_tween: Tween

var _player: PlayerController
var _health: HealthComponent
var _stats: StatsComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
## True while the Anchor spell holds. Display only; `StatsComponent` owns it.
var _anchor_held := false
## Last escalation tier the HUD spoke about, so a rising Ledger says one line
## per tier instead of one per clock tick.
var _ledger_tier := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_interact_key = _get_action_key_label("interact")
	_inventory_key = _get_action_key_label("inventory")

	Events.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_state_changed.connect(_on_game_state_changed)
	Events.camera_mode_changed.connect(_on_camera_mode_changed)

	_prompt_panel.visible = false
	_toast_label.modulate.a = 0.0
	_inventory_panel.visible = false

	_action_button.pressed.connect(_on_action_pressed)
	_close_button.pressed.connect(close_inventory)
	_item_list.item_selected.connect(_on_item_selected)
	_clock_timer.timeout.connect(_refresh_clock)

	%ShopButton.pressed.connect(_open_book_tab.bind("Shop"))
	%SkillsButton.pressed.connect(_open_book_tab.bind("Skills"))
	%LedgerButton.pressed.connect(_open_book_tab.bind("Ledger"))

	_bind_player()
	_refresh_clock()


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		return

	_health = _player.get_node("%HealthComponent") as HealthComponent
	_stats = _player.get_node("%StatsComponent") as StatsComponent
	_inventory = _player.get_node("%InventoryComponent") as InventoryComponent
	_equipment = _player.get_node("%EquipmentComponent") as EquipmentComponent

	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.damaged.connect(_on_player_damaged)
		_health_bar.max_value = _health.get_max_health()
		_on_health_changed(_health.get_health(), _health.get_max_health())

	if _stats != null:
		_stats.stamina_changed.connect(_on_stamina_changed)
		_stats.mana_changed.connect(_on_memory_changed)
		_stats.silk_changed.connect(_on_silk_changed)
		_stats.anchoring_changed.connect(_on_anchoring_changed)
		_stats.anchor_guard_changed.connect(_on_anchor_guard_changed)
		_stamina_bar.max_value = _stats.get_max_stamina()
		_stamina_bar.value = _stats.get_stamina()
		_memory_bar.max_value = _stats.get_max_memory()
		_memory_bar.value = _stats.get_memory()
		_on_memory_changed(_stats.get_memory(), _stats.get_max_memory())
		_on_silk_changed(_stats.get_silk(), _stats.get_max_silk())
		_on_anchoring_changed(_stats.get_anchoring(), _stats.get_max_anchoring())

	if _inventory != null:
		_inventory.inventory_changed.connect(_refresh_inventory)

	if _equipment != null:
		_equipment.equipment_changed.connect(_refresh_equipment)

	_refresh_equipment()
	_refresh_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING:
		return
	# A map or conversation owns the screen while it is open; don't stack the
	# inventory on top.
	if _map_screen != null and _map_screen.visible:
		return
	if _journal != null and _journal.visible:
		return
	if _ledger_shop != null and _ledger_shop.visible:
		return
	if _field_notes != null and _field_notes.visible:
		return
	if _dialogue_window != null and _dialogue_window.visible:
		return
	if not event.is_action_pressed("inventory"):
		return

	toggle_inventory()
	get_viewport().set_input_as_handled()


# --- inventory panel -------------------------------------------------------


func toggle_inventory() -> void:
	if _inventory_panel.visible:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if _player == null:
		return

	_inventory_panel.visible = true
	_refresh_inventory()
	_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	_inventory_panel.visible = false
	if _player != null:
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Opens the Ledger, Shop or Skills tab from the inventory's book buttons.
func _open_book_tab(tab_name: String) -> void:
	close_inventory()
	if _ledger_shop != null and _ledger_shop.has_method("open"):
		_ledger_shop.call("open", tab_name)


func _refresh_inventory() -> void:
	if _inventory == null:
		return

	_item_list.clear()
	for stack in _inventory.get_slots():
		var data := stack["data"] as ItemData
		if data == null:
			continue
		var amount := int(stack["amount"])
		var suffix := "" if amount <= 1 else " x%d" % amount
		_item_list.add_item(data.display_name + suffix)
		var row := _item_list.item_count - 1
		if data.icon != null:
			_item_list.set_item_icon(row, data.icon)
		_item_list.set_item_metadata(row, data.id)

	_update_action_button()


func _update_action_button() -> void:
	var data := ItemDatabase.get_item(_selected_item_id())
	if data == null:
		_action_button.text = "Equip"
		_action_button.disabled = true
		return

	_action_button.disabled = false
	if data.is_consumable():
		_action_button.text = "Use"
	elif data.is_equipment():
		_action_button.text = "Equip"
	else:
		_action_button.text = "Inspect"
		_action_button.disabled = true


func _selected_item_id() -> StringName:
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		return &""
	return StringName(_item_list.get_item_metadata(selected[0]))


func _on_item_selected(_index: int) -> void:
	_update_action_button()


func _on_action_pressed() -> void:
	var id := _selected_item_id()
	if id == &"" or _player == null:
		return

	var data := ItemDatabase.get_item(id)
	if data == null:
		return

	if data.is_equipment():
		_player.try_equip(id)
	elif data.is_consumable():
		_player.use_item(id)

	_refresh_inventory()


func _refresh_equipment() -> void:
	if _equipment == null:
		return

	var weapon := _equipment.get_weapon()
	_weapon_label.text = "Unarmed" if weapon == null else weapon.display_name

	# The tool belt is a separate slot, so an axe stays in hand while the sword
	# is equipped. Both are shown so the player can see what E will allow.
	var tool := _equipment.get_equipped(ItemData.EquipSlot.TOOL)
	_tool_label.text = "Tools: none" if tool == null else "Tool: %s" % tool.display_name


## The clock advances every frame but the label only redraws twice a second.
## The Ledger word rides along because it is also a slow, qualitative display.
## See the "no per-frame UI" rule in AGENTS.md section 10.2.
func _refresh_clock() -> void:
	_time_label.text = WorldClock.get_time_string()
	_ledger_label.text = "Ledger: %s" % Ledger.get_state_word()
	_note_ledger_escalation()
	_note_places()
	_refresh_minimap()


## The escalation is the one part of the Ledger the world acts on, so a rise is
## spoken once. Quiet on the way down: relief does not need announcing.
func _note_ledger_escalation() -> void:
	var tier := Ledger.get_escalation()
	if tier == _ledger_tier:
		return
	var rising := tier > _ledger_tier
	_ledger_tier = tier
	if not rising:
		return
	var line := Ledger.get_escalation_line(tier)
	if not line.is_empty():
		_on_notification_requested(line)


## Records where the player stands for the Field Notes checklist. Only the
## continuous town counts by position: interiors place the player near the
## origin, which would falsely tick the market, so they are counted by scene
## instead. The first visit to a place writes one line down, once.
func _note_places() -> void:
	if _player == null or Game.state != Game.State.PLAYING:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	if scene.scene_file_path != "res://scenes/town.tscn":
		_note_room(scene)
		return

	for id in ExplorationLog.check(_player.global_position):
		_announce_place(id)


## An interior is entered, not walked into: the scene itself is the proof.
func _note_room(scene: Node) -> void:
	var id := ExplorationLog.note_scene(scene.scene_file_path, scene.name)
	if id.is_empty():
		return
	Events.notification_requested.emit(
		"Field notes: %s" % ExplorationLog.get_room_title(id)
	)


## A first visit to a named place is written down in Field Notes' own voice, so
## the tick arrives with a sentence rather than a bare toast.
func _announce_place(id: StringName) -> void:
	var title := ExplorationLog.get_title(id)
	var line := ExplorationLog.get_line(id)
	if line.is_empty():
		Events.notification_requested.emit("Field notes: %s" % title)
		return
	# A conversation already on screen keeps the screen; the note waits for the
	# next visit instead of stacking two panels on top of each other.
	if _dialogue_window != null and _dialogue_window.visible:
		Events.notification_requested.emit("Field notes: %s" % title)
		return
	Events.dialogue_requested.emit(
		"Field Notes", title, PackedStringArray([line])
	)


## The minimap rides the half-second tick. It hides while a full-screen panel
## owns the screen, so the corner stays quiet during reading.
func _refresh_minimap() -> void:
	if _minimap == null:
		return
	var busy := (
		_inventory_panel.visible
		or (_map_screen != null and _map_screen.visible)
		or (_field_notes != null and _field_notes.visible)
		or (_dialogue_window != null and _dialogue_window.visible)
	)
	_minimap.visible = _player != null and Game.state == Game.State.PLAYING and not busy
	if not _minimap.visible or _player == null:
		return
	_minimap.call("refresh_view", _player.global_position, _player.global_rotation.y)


# --- event handlers --------------------------------------------------------


func _get_action_key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"

	var key_event := events[0] as InputEventKey
	if key_event == null:
		return "?"

	var code := key_event.physical_keycode
	if code == 0:
		code = key_event.keycode
	return OS.get_keycode_string(code)


func _on_interaction_prompt_changed(text: String) -> void:
	if text.is_empty():
		_prompt_panel.visible = false
		return

	_prompt_label.text = "[%s] %s" % [_interact_key, text]
	_prompt_panel.visible = true


func _on_notification_requested(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "Health %d / %d" % [roundi(current), roundi(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _on_memory_changed(current: float, maximum: float) -> void:
	_memory_bar.max_value = maximum
	_memory_bar.value = current
	_memory_label.text = "Memory %d / %d" % [roundi(current), roundi(maximum)]


func _on_silk_changed(current: float, _maximum: float) -> void:
	_silk_label.text = "Silk %d" % roundi(current)


func _on_anchoring_changed(_current: int, _maximum: int) -> void:
	_render_anchors()


## The Anchors row names the held state too, so a player can tell a spent tooth
## from one that is still working. The count itself stays owned by the stats.
func _on_anchor_guard_changed(active: bool) -> void:
	_anchor_held = active
	_render_anchors()


func _render_anchors() -> void:
	if _stats == null:
		return
	var text := "Anchors %d/%d" % [
		_stats.get_anchoring(), _stats.get_max_anchoring()
	]
	if _anchor_held:
		text += " (held)"
	_anchor_label.text = text


func _on_player_damaged(_amount: float) -> void:
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()

	_health_bar.modulate = Color(1.0, 0.45, 0.45)
	_damage_tween = create_tween()
	_damage_tween.tween_property(_health_bar, "modulate", Color.WHITE, 0.45)


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING:
		_prompt_panel.visible = false
		if _inventory_panel.visible:
			close_inventory()


func _on_camera_mode_changed(is_first_person: bool) -> void:
	# In third person the player's body sits between the camera and the
	# crosshair, so the crosshair is hidden. The interaction prompt still shows
	# what you are looking at.
	_crosshair.visible = is_first_person
