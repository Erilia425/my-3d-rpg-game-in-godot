extends Control
## The Ledger: one full-screen panel with three tabs.
##
## Shop sells randomized upgrades and market stock for coins. Skills spends the
## skill points earned by levelling. Ledger shows the lore pages found so far.
## Like the quest journal it is a child of the HUD, so every gameplay scene gets
## it for free; it only reads `Progression` and asks the player to apply the new
## ranks. See AGENTS.md sections 4.6 and 6.

@onready var _coins_label: Label = %CoinsLabel
@onready var _level_label: Label = %LevelLabel
@onready var _tabs: TabContainer = %Tabs
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _skill_list: VBoxContainer = %SkillList
@onready var _ledger_list: VBoxContainer = %LedgerList

var _player: PlayerController

## Tab names in the same order as the TabContainer children.
const TAB_SHOP := 0
const TAB_SKILLS := 1
const TAB_LEDGER := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Events.game_state_changed.connect(_on_game_state_changed)


func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING and not visible:
		return
	if _dialogue_is_open():
		return

	# Escape closes the panel instead of opening the pause menu while it is up.
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Opens the panel on a named tab ("Shop", "Skills" or "Ledger").
func open(tab_name: String = "Shop") -> void:
	if _dialogue_is_open():
		return

	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_put_other_panels_away()
	visible = true
	if is_instance_valid(_player):
		_player.set_ui_blocked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match tab_name:
		"Skills":
			_tabs.current_tab = TAB_SKILLS
		"Ledger":
			_tabs.current_tab = TAB_LEDGER
		_:
			_tabs.current_tab = TAB_SHOP
	_refresh()


func close() -> void:
	visible = false
	if is_instance_valid(_player):
		_player.set_ui_blocked(false)
	if Game.state == Game.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


# --- refresh ---------------------------------------------------------------


func _refresh() -> void:
	_coins_label.text = "Coins: %d" % Progression.get_coins()
	_level_label.text = "Level %d  •  XP %d/%d  •  Skill points %d" % [
		Progression.get_level(),
		Progression.get_xp(),
		Progression.xp_for_next_level(),
		Progression.get_skill_points(),
	]

	_refresh_shop()
	_refresh_skills()
	_refresh_ledger()


func _refresh_shop() -> void:
	_clear(_shop_list)

	_add_heading(_shop_list, "This run's offers")
	var offers := Progression.get_shop_offers()
	if offers.is_empty():
		_add_note(_shop_list, "Nothing in stock today.")
	for id in offers:
		var def := Progression.get_upgrade_def(id)
		if def.is_empty():
			continue
		var rank := Progression.get_upgrade_level(id)
		var max_rank := int(def.get("max_level", 1))
		var price := Progression.get_discounted_price(Progression.get_upgrade_price(id))
		var owned := rank >= max_rank
		_add_row(
			_shop_list,
			String(def.get("title", String(id))),
			String(def.get("description", "")),
			"Rank %d/%d" % [rank, max_rank],
			"Maxed" if owned else "%d coins" % price,
			"Owned" if owned else "Buy",
			owned or not Progression.can_buy_upgrade(id),
			_on_buy_upgrade.bind(id)
		)

	_add_heading(_shop_list, "Market stock")
	var stock := Progression.get_stock()
	for item_id: Variant in stock.keys():
		var key := StringName(item_id)
		var data := ItemDatabase.get_item(key)
		if data == null:
			continue
		var price := Progression.get_stock_price(key)
		_add_row(
			_shop_list,
			data.display_name,
			"Everyday goods from the market stalls.",
			"",
			"%d coins" % price,
			"Buy",
			Progression.get_coins() < price,
			_on_buy_stock.bind(key)
		)

	if Progression.get_best_discount() > 0.0:
		_add_note(
			_shop_list,
			"A friendly face gets you %d%% off." % roundi(
				Progression.get_best_discount() * 100.0
			)
		)


func _refresh_skills() -> void:
	_clear(_skill_list)

	_add_heading(_skill_list, "Skills")
	_add_note(
		_skill_list,
		"Earn XP by defeating creatures; every level grants a skill point."
	)

	for id in Progression.get_skill_ids():
		var def := Progression.get_skill_def(id)
		if def.is_empty():
			continue
		var rank := Progression.get_skill_level(id)
		var max_rank := int(def.get("max_level", 1))
		var cost := Progression.get_skill_cost(id)
		var owned := rank >= max_rank
		_add_row(
			_skill_list,
			String(def.get("title", String(id))),
			String(def.get("description", "")),
			"Rank %d/%d" % [rank, max_rank],
			"Maxed" if owned else "%d point%s" % [cost, "" if cost == 1 else "s"],
			"Known" if owned else "Learn",
			owned or not Progression.can_unlock_skill(id),
			_on_learn_skill.bind(id)
		)


func _refresh_ledger() -> void:
	_clear(_ledger_list)

	if not Progression.has_ledger():
		_add_heading(_ledger_list, "The Ledger is lost")
		_add_note(
			_ledger_list,
			"Your ledger sits on the desk in your study. Read it, and the pages "
			+ "you recover will have a home."
		)
		return

	var pages := Progression.get_ledger_pages()
	_add_heading(
		_ledger_list,
		"Recovered pages (%d of %d)" % [pages.size(), Progression.LORE_DEFS.size()]
	)
	if pages.is_empty():
		_add_note(
			_ledger_list,
			"The pages are scattered around the Hollow. Look along the forest "
			+ "edge, near the stalls, and behind the cottages."
		)
		return

	for id in pages:
		var title := Progression.get_lore_title(id)
		var body := Progression.get_lore_body(id)
		_add_entry(_ledger_list, title, body)


# --- row helpers -----------------------------------------------------------


func _add_heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1))
	parent.add_child(label)


func _add_note(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.19, 1))
	parent.add_child(label)


func _add_entry(parent: VBoxContainer, title: String, body: String) -> void:
	_add_heading(parent, title)
	_add_note(parent, body)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	parent.add_child(spacer)


## One row: title and description on the left, rank and price on the right, and
## a button that buys or learns. The button is disabled when the player cannot
## afford the action.
func _add_row(
	parent: VBoxContainer,
	title: String,
	description: String,
	rank: String,
	price: String,
	button_text: String,
	disabled: bool,
	action: Callable
) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1))
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.19, 1))
	text_box.add_child(desc_label)

	if not rank.is_empty():
		var rank_label := Label.new()
		rank_label.text = rank
		rank_label.add_theme_font_size_override("font_size", 13)
		rank_label.add_theme_color_override("font_color", Color(0.45, 0.36, 0.24, 1))
		text_box.add_child(rank_label)

	var price_label := Label.new()
	price_label.text = price
	price_label.custom_minimum_size = Vector2(80.0, 0.0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color(0.42, 0.28, 0.1, 1))
	row.add_child(price_label)

	var button := Button.new()
	button.text = button_text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(92.0, 0.0)
	button.pressed.connect(action)
	row.add_child(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	parent.add_child(spacer)


func _clear(parent: VBoxContainer) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


# --- actions ---------------------------------------------------------------


func _on_buy_upgrade(id: StringName) -> void:
	if not Progression.buy_upgrade(id):
		Events.notification_requested.emit("Not enough coins")
		return

	var def := Progression.get_upgrade_def(id)
	Events.notification_requested.emit(
		"Bought %s" % String(def.get("title", String(id)))
	)
	# A new rank changes movement, health or capacity, so rebuild the player's
	# derived stats before redrawing the rows.
	if is_instance_valid(_player):
		_player.apply_progression()
	# Re-roll the shelf after every purchase so the next visit differs.
	Progression.roll_shop_offers()
	_refresh()


func _on_learn_skill(id: StringName) -> void:
	if not Progression.unlock_skill(id):
		Events.notification_requested.emit("Not enough skill points")
		return

	var def := Progression.get_skill_def(id)
	Events.notification_requested.emit(
		"Learned %s" % String(def.get("title", String(id)))
	)
	if is_instance_valid(_player):
		_player.apply_progression()
	_refresh()


func _on_buy_stock(item_id: StringName) -> void:
	var price := Progression.get_stock_price(item_id)
	if not Progression.spend_coins(price):
		Events.notification_requested.emit("Not enough coins")
		return

	var data := ItemDatabase.get_item(item_id)
	if data == null or not is_instance_valid(_player):
		# Refund if the shop row pointed at a missing item.
		Progression.add_coins(price)
		return

	var granted := _player.add_item(data, 1)
	if granted <= 0:
		Progression.add_coins(price)
		Events.notification_requested.emit("Your inventory is full")
		return

	Events.notification_requested.emit("Bought %s" % data.display_name)
	_refresh()


# --- panel plumbing --------------------------------------------------------


func _dialogue_is_open() -> bool:
	var window := get_parent().get_node_or_null("DialogueWindow") as Control
	return window != null and window.visible


func _put_other_panels_away() -> void:
	var hud := get_parent()
	if hud == null:
		return
	if hud.has_method("close_inventory"):
		hud.call("close_inventory")
	var journal := hud.get_node_or_null("QuestJournal") as Control
	if journal != null and journal.has_method("close") and journal.visible:
		journal.call("close")
	var map := hud.get_node_or_null("MapScreen") as Control
	if map != null and map.has_method("close") and map.visible:
		map.call("close")


func _on_game_state_changed(_previous_state: int, current_state: int) -> void:
	if current_state != Game.State.PLAYING and visible:
		close()
