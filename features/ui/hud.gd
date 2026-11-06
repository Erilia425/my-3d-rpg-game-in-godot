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
@onready var _weapon_label: Label = %WeaponLabel
@onready var _time_label: Label = %TimeLabel
@onready var _clock_timer: Timer = %ClockTimer
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _item_list: ItemList = %ItemList
@onready var _action_button: Button = %EquipButton
@onready var _close_button: Button = %CloseButton
@onready var _map_screen: Control = get_node_or_null("MapScreen") as Control
@onready var _dialogue_window: Control = get_node_or_null("DialogueWindow") as Control

var _interact_key := "E"
var _inventory_key := "I"
var _toast_tween: Tween
var _damage_tween: Tween

var _player: PlayerController
var _health: HealthComponent
var _stats: StatsComponent
var _inventory: InventoryComponent
var _equipment: EquipmentComponent


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
		_stamina_bar.max_value = _stats.get_max_stamina()
		_stamina_bar.value = _stats.get_stamina()

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
		_item_list.set_item_metadata(_item_list.item_count - 1, data.id)

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


## The clock advances every frame but the label only redraws twice a second.
## See the "no per-frame UI" rule in AGENTS.md section 10.2.
func _refresh_clock() -> void:
	_time_label.text = WorldClock.get_time_string()


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
