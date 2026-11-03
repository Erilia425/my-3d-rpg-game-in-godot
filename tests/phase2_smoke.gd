extends Node
## Phase 2 smoke test.
##
## Run from a terminal:
##   godot --headless --path . tests/phase2_smoke.tscn
## Or open this scene in the editor and press F6.
##
## Covers the data layer, inventory, equipment, health, stamina, attacks, the
## enemy, chest loot, and the HUD. Loads the real test room so the game code
## runs exactly as it does when playing. Prints PHASE2_SMOKE_OK on success.

const EPSILON := 0.05

var _failures: PackedStringArray = []
var _notifications: PackedStringArray = []
var _last_notification := ""
var _equipment_changes := 0
var _death_signals := 0

var _room: Node3D
var _player: PlayerController
var _enemy: Node3D
var _hud: CanvasLayer
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _stats: StatsComponent
var _health: HealthComponent


func _ready() -> void:
	await get_tree().process_frame

	Events.notification_requested.connect(_on_notification)

	_check_item_data()
	_check_database()
	await _check_inventory()
	await _check_equipment()
	await _check_health()

	var packed := load("res://scenes/test_room.tscn") as PackedScene
	_check(packed != null, "test room scene loads")
	if packed == null:
		_finish()
		return

	_room = packed.instantiate() as Node3D
	add_child(_room)
	await _physics_frames(4)

	_check_player_setup()
	_check_hud_vitals()
	await _check_stamina()
	await _check_chests()
	await _check_inventory_panel()
	await _check_combat()

	_finish()


# --- data layer -----------------------------------------------------------


func _check_item_data() -> void:
	var sword := _item(&"item.iron_sword")
	_check(sword != null, "iron sword definition loads")
	if sword == null:
		return

	_check(sword.id == &"item.iron_sword", "sword keeps its namespaced id")
	_check(sword.display_name == "Iron Sword", "sword has a display name")
	_check(sword.kind == ItemData.Kind.WEAPON, "sword is a weapon")
	_check(sword.equip_slot == ItemData.EquipSlot.MAIN_HAND, "sword equips in the main hand")
	_check(is_equal_approx(sword.damage, 12.0), "sword deals 12 damage")
	_check(sword.is_equipment(), "sword reports itself as equipment")
	_check(sword.stack_size == 1, "sword does not stack")

	var armor := _item(&"item.leather_armor")
	_check(armor != null, "leather armor definition loads")
	if armor != null:
		_check(armor.kind == ItemData.Kind.ARMOR, "armor is armor")
		_check(armor.equip_slot == ItemData.EquipSlot.BODY, "armor equips on the body")
		_check(is_equal_approx(armor.armor, 4.0), "armor grants 4 armor")

	var potion := _item(&"item.health_potion")
	_check(potion != null, "health potion definition loads")
	if potion != null:
		_check(potion.is_consumable(), "potion is a consumable")
		_check(not potion.is_equipment(), "potion is not equipment")
		_check(is_equal_approx(potion.restore_health, 35.0), "potion restores 35 health")
		_check(potion.stack_size == 5, "potions stack to 5")


func _check_database() -> void:
	var all_resolve := true
	for id in ItemDatabase.ITEMS.keys():
		if ItemDatabase.get_item(id) == null:
			all_resolve = false
	_check(all_resolve, "every registered item id resolves")
	_check(ItemDatabase.get_item(&"item.missing") == null, "an unknown item id returns null")
	_check(not ItemDatabase.has_item(&"item.missing"), "has_item() is false for unknown ids")


# --- inventory ------------------------------------------------------------


func _check_inventory() -> void:
	var inv := InventoryComponent.new()
	inv.capacity = 2
	add_child(inv)
	await get_tree().process_frame

	var potion := _item(&"item.health_potion")
	var added := 0
	added = inv.add_item(potion, 2)
	_check(added == 2, "adding 2 potions reports 2 added (%d)" % added)
	_check(inv.get_amount(&"item.health_potion") == 2, "inventory counts 2 potions")
	_check(inv.get_used_slots() == 1, "two potions share one stack slot")

	added = inv.add_item(potion, 6)
	_check(added == 6, "adding 6 more reports 6 added (%d)" % added)
	_check(inv.get_amount(&"item.health_potion") == 8, "inventory totals 8 potions")
	_check(inv.get_used_slots() == 2, "8 potions split into 2 stacks of at most 5")
	_check(inv.is_full(), "a 2-slot inventory of 2 stacks is full")

	added = inv.add_item(potion, 1)
	_check(added == 1, "a full inventory still tops up an existing stack (%d)" % added)
	_check(inv.get_amount(&"item.health_potion") == 9, "topping up raises the total to 9")

	var sword := _item(&"item.iron_sword")
	added = inv.add_item(sword, 1)
	_check(added == 0, "a full inventory refuses a new stack (%d)" % added)
	_check(not inv.has_item(&"item.iron_sword"), "the refused item never enters the inventory")

	_check(inv.remove_item(&"item.health_potion", 4), "removing 4 potions succeeds")
	_check(inv.get_amount(&"item.health_potion") == 5, "removing 4 leaves 5 potions")
	_check(inv.get_used_slots() == 1, "the emptied stack is freed")

	_check(not inv.remove_item(&"item.health_potion", 99), "removing more than held fails")
	_check(inv.get_amount(&"item.health_potion") == 5, "a refused removal changes nothing")
	_check(inv.has_item(&"item.health_potion", 5), "has_item() checks the minimum amount")
	_check(not inv.has_item(&"item.health_potion", 6), "has_item() fails above the amount held")
	_check(not inv.has_item(&"item.iron_sword"), "has_item() is false for an absent item")

	inv.clear()
	_check(inv.get_used_slots() == 0, "clear() empties the inventory")

	inv.free()


# --- equipment ------------------------------------------------------------


func _check_equipment() -> void:
	var inv := InventoryComponent.new()
	inv.capacity = 6
	add_child(inv)
	var equipment := EquipmentComponent.new()
	add_child(equipment)
	equipment.setup(inv)
	await get_tree().process_frame

	inv.add_item(_item(&"item.iron_sword"), 1)
	inv.add_item(_item(&"item.leather_armor"), 1)
	inv.add_item(_item(&"item.health_potion"), 1)

	_equipment_changes = 0
	equipment.equipment_changed.connect(_on_equipment_changed)

	_check(equipment.equip(&"item.iron_sword"), "the sword can be equipped")
	_check(not inv.has_item(&"item.iron_sword"), "equipping moves the sword out of the inventory")
	var weapon := equipment.get_weapon()
	_check(weapon != null and weapon.id == &"item.iron_sword", "the main hand holds the sword")
	_check(
		is_equal_approx(equipment.get_attack_damage(), equipment.unarmed_damage + 12.0),
		"attack damage is unarmed plus weapon damage (%.1f)" % equipment.get_attack_damage()
	)

	_check(not equipment.equip(&"item.health_potion"), "a potion cannot be equipped")
	_check(equipment.equip(&"item.leather_armor"), "the armor can be equipped")
	_check(is_equal_approx(equipment.get_armor_value(), 4.0), "equipped armor grants 4 armor")
	_check(_equipment_changes == 2, "equipment_changed fired once per equip (%d)" % _equipment_changes)

	_check(equipment.unequip(ItemData.EquipSlot.MAIN_HAND), "the main hand can be unequipped")
	_check(inv.has_item(&"item.iron_sword"), "unequipping returns the sword to the inventory")
	_check(
		is_equal_approx(equipment.get_attack_damage(), equipment.unarmed_damage),
		"unequipping returns attack damage to unarmed (%.1f)" % equipment.get_attack_damage()
	)
	_check(equipment.get_weapon() == null, "the main hand is empty after unequipping")

	inv.free()
	equipment.free()


# --- health ---------------------------------------------------------------


func _check_health() -> void:
	var health := HealthComponent.new()
	health.max_health = 20.0
	add_child(health)
	await get_tree().process_frame

	_death_signals = 0
	health.died.connect(_on_health_died)

	_check(is_equal_approx(health.get_health(), 20.0), "health starts full")
	_check(is_equal_approx(health.get_fraction(), 1.0), "a full health bar is 100%")

	var applied := health.take_damage(5.0)
	_check(is_equal_approx(applied, 5.0), "take_damage reports the damage applied")
	_check(is_equal_approx(health.get_health(), 15.0), "damage lowers health")

	var healed := health.heal(100.0)
	_check(is_equal_approx(healed, 5.0), "healing is capped at missing health")
	_check(is_equal_approx(health.get_health(), 20.0), "healing cannot exceed max health")

	health.take_damage(999.0)
	_check(health.is_dead(), "lethal damage kills the actor")
	_check(_death_signals == 1, "the died signal fires once (%d)" % _death_signals)
	_check(is_equal_approx(health.get_fraction(), 0.0), "an empty health bar is 0%")
	_check(is_equal_approx(health.heal(10.0), 0.0), "a dead actor cannot be healed")

	health.revive()
	_check(not health.is_dead(), "revive brings the actor back")
	_check(is_equal_approx(health.get_health(), 20.0), "revive restores full health")

	health.free()


# --- room: player, HUD, stamina -------------------------------------------


func _check_player_setup() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_check(_player != null, "test room contains a player")
	if _player == null:
		return

	_health = _player.get_health_component()
	_stats = _player.get_stats_component()
	_inventory = _player.get_inventory_component()
	_equipment = _player.get_equipment_component()

	_check(_health != null, "player has a health component")
	_check(_stats != null, "player has a stats component")
	_check(_inventory != null, "player has an inventory component")
	_check(_equipment != null, "player has an equipment component")
	_check(_inventory.get_used_slots() == 0, "the player starts with an empty inventory")
	_check(is_equal_approx(_health.get_health(), 100.0), "the player starts at full health")

	_enemy = _room.find_child("Enemy", true, false) as Node3D
	_check(_enemy != null, "test room contains an enemy")
	if _enemy != null:
		_check(_enemy.is_in_group("enemy"), "the enemy is in the enemy group")

	_hud = _room.find_child("HUD", true, false) as CanvasLayer
	_check(_hud != null, "test room contains a HUD")


func _check_hud_vitals() -> void:
	if _hud == null:
		return

	var health_bar := _hud.find_child("HealthBar", true, false) as ProgressBar
	var stamina_bar := _hud.find_child("StaminaBar", true, false) as ProgressBar
	var health_label := _hud.find_child("HealthLabel", true, false) as Label
	var weapon_label := _hud.find_child("WeaponLabel", true, false) as Label

	_check(health_bar != null, "HUD has a health bar")
	_check(stamina_bar != null, "HUD has a stamina bar")
	_check(health_label != null, "HUD has a health label")
	_check(weapon_label != null, "HUD has a weapon label")

	if health_bar != null:
		_check(is_equal_approx(health_bar.max_value, 100.0), "health bar knows the maximum health")
		_check(is_equal_approx(health_bar.value, 100.0), "health bar starts full")
	if health_label != null:
		_check(health_label.text == "Health 100 / 100", "health label reads the current health")
	if weapon_label != null:
		_check(weapon_label.text == "Unarmed", "weapon label starts unarmed")


func _check_stamina() -> void:
	if _stats == null:
		return

	_stats.restore_stamina(100.0)
	_check(is_equal_approx(_stats.get_stamina(), 100.0), "stamina starts full")

	_check(_stats.spend_stamina(30.0), "spending 30 stamina succeeds")
	_check(is_equal_approx(_stats.get_stamina(), 70.0), "spending lowers stamina (%.1f)" % _stats.get_stamina())
	_check(not _stats.spend_stamina(1000.0), "spending more than available fails")
	_check(is_equal_approx(_stats.get_stamina(), 70.0), "a refused spend changes nothing")

	var before := _stats.get_stamina()
	await _physics_frames(30)
	_check(_stats.get_stamina() > before, "stamina regenerates over time")
	_check(_stats.restore_stamina(1000.0) > 0.0, "restore_stamina tops the pool up")
	_check(is_equal_approx(_stats.get_stamina(), 100.0), "stamina cannot exceed the maximum")


# --- room: chests, inventory panel ----------------------------------------


func _check_chests() -> void:
	if _inventory == null:
		return

	var potion_chest := _room.find_child("ChestPotion", true, false) as Node3D
	_check(potion_chest != null, "test room contains a potion chest")
	if potion_chest != null:
		_last_notification = ""
		potion_chest.call("interact", _player)
		_check(
			_inventory.get_amount(&"item.health_potion") == 2,
			"opening the potion chest puts 2 potions in the inventory"
		)
		_check(
			_last_notification == "Health Potion acquired",
			"the potion chest names what was acquired (\"%s\")" % _last_notification
		)
		potion_chest.call("interact", _player)
		_check(
			_inventory.get_amount(&"item.health_potion") == 2,
			"an opened chest cannot be looted twice"
		)

	var armor_chest := _room.find_child("ChestArmor", true, false) as Node3D
	_check(armor_chest != null, "test room contains an armor chest")
	if armor_chest != null:
		armor_chest.call("interact", _player)
		_check(_inventory.has_item(&"item.leather_armor"), "the armor chest grants leather armor")

	_check(_player.try_equip(&"item.leather_armor"), "the player can equip armor from a chest")
	_check(is_equal_approx(_equipment.get_armor_value(), 4.0), "the equipped armor raises armor value")
	_check(_player.try_equip(&"item.iron_sword") == false, "an item the player does not own cannot be equipped")

	_player.add_item(_item(&"item.iron_sword"), 1)
	_check(_player.try_equip(&"item.iron_sword"), "the player can equip an owned sword")
	_check(_inventory.has_item(&"item.iron_sword") == false, "the equipped sword leaves the inventory")
	_check(
		is_equal_approx(_equipment.get_attack_damage(), 18.0),
		"the equipped sword raises attack damage (%.1f)" % _equipment.get_attack_damage()
	)

	var weapon_label := _hud.find_child("WeaponLabel", true, false) as Label
	if weapon_label != null:
		_check(weapon_label.text == "Iron Sword", "the HUD shows the equipped weapon")


func _check_inventory_panel() -> void:
	if _hud == null or _player == null:
		return

	var panel := _hud.find_child("InventoryPanel", true, false) as Control
	var list := _hud.find_child("ItemList", true, false) as ItemList
	_check(panel != null, "HUD has an inventory panel")
	_check(list != null, "the inventory panel has an item list")
	if panel == null:
		return

	_hud.call("open_inventory")
	_check(panel.visible, "opening the inventory shows the panel")
	_check(_player.is_ui_blocked(), "an open inventory blocks movement and look")

	if list != null:
		_check(
			list.item_count == _inventory.get_used_slots(),
			"the item list shows one row per stack (%d of %d)" % [list.item_count, _inventory.get_used_slots()]
		)
		if list.item_count > 0:
			list.select(0)
			list.item_selected.emit(0)
			_check(
				StringName(list.get_item_metadata(0)) == &"item.health_potion",
				"a row remembers which item id it stands for"
			)
			var action_button := _hud.find_child("EquipButton", true, false) as Button
			_check(action_button != null and action_button.text == "Use", "the panel offers Use for a potion")

	_hud.call("close_inventory")
	_check(not panel.visible, "closing the inventory hides the panel")
	_check(not _player.is_ui_blocked(), "closing the inventory gives control back")


# --- room: combat ---------------------------------------------------------


func _check_combat() -> void:
	if _player == null or _enemy == null:
		return

	var enemy_health := _enemy.get_node("HealthComponent") as HealthComponent
	_check(enemy_health != null, "the enemy has a health component")
	if enemy_health == null:
		return

	_check(is_equal_approx(enemy_health.get_health(), 40.0), "the enemy starts with 40 health")

	# Aggro: park the player inside the 6 m radius and watch the state.
	_place_player(Vector3(-6, 0.1, 1.5), 0.0, 0.0)
	await _physics_frames(10)
	_check(
		StringName(_enemy.call("get_state_name")) == &"CHASE",
		"the enemy chases a player inside its aggro radius (%s)" % _enemy.call("get_state_name")
	)

	# Let it strike: armor 4 turns its 8 damage into 4.
	var health_before := _health.get_health()
	_enemy.global_position = _player.global_position + Vector3(0, 0, -1.6)
	await _physics_frames(4)
	_check(
		StringName(_enemy.call("get_state_name")) == &"ATTACK",
		"the enemy attacks in melee range (%s)" % _enemy.call("get_state_name")
	)
	await _physics_frames(20)
	_check(
		_health.get_health() < health_before,
		"the enemy's attack hurts the player (%.1f -> %.1f)" % [health_before, _health.get_health()]
	)
	_check(
		is_equal_approx(health_before - _health.get_health(), 4.0),
		"equipped armor reduced the incoming damage to 4 (%.1f)" % (health_before - _health.get_health())
	)

	var health_bar := _hud.find_child("HealthBar", true, false) as ProgressBar
	if health_bar != null:
		_check(
			is_equal_approx(health_bar.value, _health.get_health()),
			"the HUD health bar follows the damage"
		)

	# Swing back. The enemy is re-placed in front so a stray step cannot make
	# the sphere sweep miss.
	_enemy.global_position = _player.global_position + Vector3(0, 0, -1.8)
	await _physics_frames(3)

	var stamina_before := _stats.get_stamina()
	var combat := _player.get_node("%PlayerCombat")
	combat.call("try_attack")
	_check(_stats.get_stamina() < stamina_before, "a swing spends stamina")

	var anim := _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		_check(anim.has_animation(&"attack"), "the player has an attack animation")
		_check(
			anim.current_animation == &"attack",
			"a swing plays the attack animation (%s)" % anim.current_animation
		)

	var after_hit := enemy_health.get_health()
	_check(
		is_equal_approx(enemy_health.get_health(), 40.0 - 18.0),
		"an 18-damage swing takes the enemy to 22 health (%.1f)" % after_hit
	)

	var swings := 0
	while not enemy_health.is_dead() and swings < 5:
		swings += 1
		combat.call("try_attack")
	_check(enemy_health.is_dead(), "three sword swings defeat the enemy")
	_check(StringName(_enemy.call("get_state_name")) == &"DEAD", "the defeated enemy is dead")

	_check(
		_notifications.has("Enemy defeated"),
		"defeating the enemy shows a notification"
	)

	var dead_health := enemy_health.get_health()
	combat.call("try_attack")
	_check(
		is_equal_approx(enemy_health.get_health(), dead_health),
		"a dead enemy takes no further damage"
	)

	# Potions: heal what the enemy took, and consume one.
	var missing := _health.get_max_health() - _health.get_health()
	_check(missing > 0.0, "the player still has damage to heal (%.1f)" % missing)
	var potions_before := _inventory.get_amount(&"item.health_potion")
	_check(_player.use_item(&"item.health_potion"), "a potion can be drunk")
	_check(
		is_equal_approx(_health.get_health(), _health.get_max_health()),
		"the potion restores the missing health"
	)
	_check(
		_inventory.get_amount(&"item.health_potion") == potions_before - 1,
		"drinking a potion consumes one"
	)
	_check(not _player.use_item(&"item.iron_sword"), "an equipment item cannot be drunk")


# --- helpers --------------------------------------------------------------


func _item(id: StringName) -> ItemData:
	return ItemDatabase.get_item(id)


func _place_player(position: Vector3, yaw_degrees: float, pitch_degrees: float) -> void:
	if _player == null:
		return
	_player.global_position = position
	_player.rotation.y = deg_to_rad(yaw_degrees)
	_player.velocity = Vector3.ZERO
	var head := _player.find_child("Head", true, false) as Node3D
	if head != null:
		head.rotation.x = deg_to_rad(pitch_degrees)


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _on_notification(text: String) -> void:
	_last_notification = text
	_notifications.append(text)


func _on_equipment_changed() -> void:
	_equipment_changes += 1


func _on_health_died() -> void:
	_death_signals += 1


func _finish() -> void:
	if _failures.is_empty():
		print("PHASE2_SMOKE_OK")
		get_tree().quit(0)
	else:
		push_error("PHASE2_SMOKE_FAILED: " + ", ".join(_failures))
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures.append(message)
		push_error("  FAIL: " + message)
