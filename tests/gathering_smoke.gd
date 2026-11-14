extends Node
## Gathering smoke test: choppable trees, species logs, fieldstone, regrowth,
## and tag-based crafting.
##
## Loads the real town so the checks run against the shipped content instead of
## a fixture. Prints `GATHERING_SMOKE_OK` on success, like the phase suites.

class Stub extends Node:
	var inventory := InventoryComponent.new()
	var equipment := EquipmentComponent.new()

	func _ready() -> void:
		add_child(inventory)
		add_child(equipment)
		equipment.setup(inventory)
		inventory.add_item(ItemDatabase.get_item(&"item.axe"), 1)
		equipment.equip(&"item.axe")

	func add_item(data: ItemData, amount: int) -> int:
		return inventory.add_item(data, amount)

	func get_equipment_component() -> EquipmentComponent:
		return equipment

	func get_inventory_component() -> InventoryComponent:
		return inventory


func _ready() -> void:
	await get_tree().process_frame
	var town := (load("res://scenes/town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- items -------------------------------------------------------------
	for id in [&"item.spruce_log", &"item.birch_log", &"item.stone"]:
		var item := ItemDatabase.get_item(id)
		_check(item != null, "item exists: %s" % id)
		if item != null:
			_check(item.icon != null, "%s has an icon" % id)

	# --- the machine's goods and its key ----------------------------------
	for id in [
		&"item.seaglass",
		&"item.spider_coin",
		&"item.moss_rock",
		&"item.small_opal",
		&"item.faux_ivory_brooch",
		&"item.planting_mushroom",
		&"item.dirt_sack",
		&"item.gnome_statue",
	]:
		var odd := ItemDatabase.get_item(id)
		_check(odd != null, "the machine's goods exist: %s" % id)
		if odd != null:
			_check(odd.icon != null, "%s has an icon" % id)

	# --- a town tree can be chopped ---------------------------------------
	var tree := town.get_node_or_null("Props/Tree012") as TownProp
	_check(tree != null, "Tree012 exists")
	var chop := tree.get_node_or_null("Choppable") as GatherNode
	_check(chop != null, "Tree012 has a chop body")
	if chop != null:
		_check(not chop.save_id.is_empty(), "chop body has a save id (%s)" % chop.save_id)
		_check(chop.drop_item == &"item.spruce_log", "town tree drops spruce")
		_check(
			chop.get_interaction_text().begins_with("Chop"),
			"prompt says Chop: %s" % chop.get_interaction_text()
		)

		var stub := Stub.new()
		add_child(stub)
		await get_tree().process_frame

		for i in 3:
			chop.interact(stub)
		_check(chop.is_depleted, "tree is spent after three swings")
		_check(stub.inventory.get_amount(&"item.spruce_log") == 2, "two spruce logs granted")
		_check(stub.inventory.get_amount_with_tag(&"wood") >= 2, "logs carry the wood tag")

		await get_tree().create_timer(0.9).timeout
		_check(not tree.get_node("TreeArt").visible, "felled art is hidden")
		var stump := chop.get_node_or_null("Visual/Stump") as MeshInstance3D
		_check(stump != null and stump.visible, "a stump is left behind")

		# --- regrow on a later day ----------------------------------------
		chop.check_regrow()
		_check(chop.is_depleted, "no regrow before the timer")
		WorldClock.day += 7
		chop.check_regrow()
		_check(not chop.is_depleted, "stump regrows after six days")
		_check(tree.get_node("TreeArt").visible, "regrown art is visible again")
		stub.queue_free()

	# --- a primitive pine is choppable too --------------------------------
	var pine := town.get_node_or_null("Props/Pine096") as TownProp
	_check(pine != null and pine.get_node_or_null("Choppable") != null, "pine has a chop body")

	# --- realm trees: some are birch --------------------------------------
	var birch := _find_drop(town, &"item.birch_log")
	var spruce := _find_drop(town, &"item.spruce_log")
	_check(birch != null, "a pale realm tree drops birch")
	_check(spruce != null, "a realm tree drops spruce")

	# --- ground forage -----------------------------------------------------
	var forage := _find_prefix(town, "RealmForage")
	var rocks := _find_prefix(town, "RealmRock")
	_check(forage != null, "log/stone pickups exist in the realm")
	_check(rocks != null, "boulders exist in the realm")

	# --- crafting tag handling --------------------------------------------
	var inv := InventoryComponent.new()
	add_child(inv)
	inv.add_item(ItemDatabase.get_item(&"item.spruce_log"), 2)
	inv.add_item(ItemDatabase.get_item(&"item.stone"), 1)
	_check(inv.get_amount_with_tag(&"wood") == 2, "tag count sees spruce logs")
	_check(inv.remove_by_tag(&"wood", 2), "tag removal spends the logs")
	_check(inv.get_amount(&"item.spruce_log") == 0, "spruce stacks are empty")
	inv.queue_free()

	var axe := RecipeDatabase.get_recipe(&"recipe.axe")
	_check(axe != null and axe.tag_for(0) == &"wood", "the axe recipe accepts any wood")

	# --- forge service ----------------------------------------------------
	var dagger := ItemDatabase.get_item(&"item.iron_dagger")
	_check(dagger != null, "iron dagger item exists")
	if dagger != null:
		_check(dagger.icon != null, "iron dagger has an icon")
		_check(dagger.damage > 0.0, "iron dagger has damage")
	var dagger_recipe := RecipeDatabase.get_recipe(&"recipe.iron_dagger")
	_check(dagger_recipe != null, "iron dagger recipe exists")
	if dagger_recipe != null:
		_check(dagger_recipe.output_id == &"item.iron_dagger", "dagger recipe outputs the dagger")
		_check(dagger_recipe.tag_for(1) == &"wood", "dagger recipe accepts any wood")

	var forge := (load("res://features/world/interiors/rooms/thornridge_forge.tscn") as PackedScene).instantiate()
	add_child(forge)
	await get_tree().process_frame
	var station := forge.get_node_or_null("ForgeStation") as CraftingStation
	_check(station != null, "the forge has a crafting station")
	if station != null:
		_check(station.title == "Orrin's Forge", "the forge station names itself")
		_check(station.recipe_ids.has(&"recipe.iron_dagger"), "the forge offers the dagger")
		_check(station.get_interaction_text().contains("forge"), "the forge prompt names the forge")
	forge.queue_free()
	await get_tree().process_frame

	# --- village quests ---------------------------------------------------
	for id in [
		QuestLog.ASHFALL_MUSHROOMS, QuestLog.ASHFALL_SNAGS,
		QuestLog.THORNRIDGE_STONE, QuestLog.THORNRIDGE_ORE,
	]:
		_check(QuestLog.DEFS.has(id), "quest definition exists: %s" % id)

	var maren := town.get_node_or_null("Realm/Ashfall_maren_ash") as QuestNpc
	_check(maren != null, "Maren Ash is a QuestNpc")
	if maren != null:
		_check(maren.offers_quest == &"quest.ashfall_mushrooms", "Maren offers the mushroom errand")
		_check(maren.deliver_item == &"item.mushroom", "Maren asks for mushrooms")

		var quest_stub := Stub.new()
		add_child(quest_stub)
		await get_tree().process_frame
		quest_stub.inventory.add_item(ItemDatabase.get_item(&"item.mushroom"), 2)
		maren.interact(quest_stub)
		_check(QuestLog.is_active(&"quest.ashfall_mushrooms"), "talking to Maren starts the errand")
		maren.interact(quest_stub)
		_check(QuestLog.is_completed(&"quest.ashfall_mushrooms"), "two mushrooms finish the errand")
		_check(
			quest_stub.inventory.get_amount(&"item.health_potion") == 1,
			"the errand pays a health potion"
		)
		quest_stub.queue_free()

	# Every village NPC that carries an errand is a QuestNpc. Plain villagers
	# remain possible later, so the check is per villager rather than per village.
	for path in ["Realm/Ashfall_pell", "Realm/Thornridge_bryn_thorne", "Realm/Thornridge_sable"]:
		var npc := town.get_node_or_null(path) as QuestNpc
		_check(npc != null and not npc.offers_quest.is_empty(), "%s offers a quest" % path)

	# --- landmarks --------------------------------------------------------
	_check(town.get_node_or_null("Realm/AshfallShrine") != null, "Ashfall has a wayside shrine")
	_check(town.get_node_or_null("Realm/AshfallWatchpost") != null, "Ashfall has a watchpost")

	# --- door plates ------------------------------------------------------
	var bakery := town.get_node_or_null("Buildings/AuntieBellsBakery") as TownBuilding
	_check(bakery != null, "the bakery building exists")
	if bakery != null:
		var plate := bakery.get_node_or_null("DoorPlate") as Label3D
		_check(plate != null, "the bakery has a door plate")
		if plate != null:
			_check(plate.text.contains("Auntie Bell"), "the door plate names the owner")
			_check(plate.position.y < 4.0, "the plate sits at the door, not the roof")

	var empty_house := town.get_node_or_null("Buildings/ThreadkeepersHouse") as TownBuilding
	_check(empty_house != null, "the Threadkeeper's House exists")
	if empty_house != null:
		var empty_plate := empty_house.get_node_or_null("DoorPlate") as Label3D
		_check(
			empty_plate != null and empty_plate.text.contains("Empty"),
			"an unowned home says Empty"
		)

	# --- road signs with distances ---------------------------------------
	var distant_signs := 0
	for node in town.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.text.contains(" m") and label.text.contains("Ashfall"):
			distant_signs += 1
	_check(distant_signs >= 2, "two road signs show village distances (%d)" % distant_signs)

	# --- the mine ---------------------------------------------------------
	var cave_scene := load("res://features/world/cave/mine_cave.tscn") as PackedScene
	_check(cave_scene != null, "the mine scene loads")
	if cave_scene != null:
		var cave := cave_scene.instantiate()
		add_child(cave)
		await get_tree().process_frame
		await get_tree().process_frame

		var iron := cave.get_node_or_null("IronSeam0") as GatherNode
		_check(iron != null, "the mine has an iron seam")
		if iron != null:
			_check(iron.save_id.begins_with("gather.cave.iron"), "iron seam has a cave save id")
			_check(iron.drop_item == &"item.iron_ore", "iron seam drops iron ore")
			_check(iron.proxy_visual != null, "iron seam has visible art")
		var gem := cave.get_node_or_null("GemSeam0") as GatherNode
		_check(gem != null, "the mine has a gemstone seam")
		if gem != null:
			_check(gem.drop_item == &"item.gemstone", "gem seam drops a pale gemstone")
		var glass := cave.get_node_or_null("GlassSeam0") as GatherNode
		_check(glass != null, "the mine has a sea glass seam")
		if glass != null:
			_check(glass.drop_item == &"item.seaglass", "the glass seam drops sea glass")
			_check(glass.save_id == &"gather.cave.glass_0", "the glass seam has a cave save id")
		_check(cave.get_node_or_null("ExitDoor") != null, "the mine has one exit")
		_check(DiscoveryLog.has(DiscoveryLog.OLD_ADIT), "entering the mine unlocks its discovery")
		cave.queue_free()
		await get_tree().process_frame

	# --- the first magic target -------------------------------------------
	var stone := town.get_node_or_null("Realm/CaveMemoryStone") as MemoryStone
	_check(stone != null, "a memory stone stands beside the cave")
	if stone != null:
		_check(stone.is_in_group(&"memory"), "the memory stone is a Recall target")
		_check(not stone.get_memory_text().is_empty(), "the memory stone holds text")

	# --- the unlabelled machine in the square -----------------------------
	var machine := town.get_node_or_null("VendingMachine") as VendingMachine
	_check(machine != null, "the unlabelled machine stands in the square")
	if machine != null:
		_check(machine.is_in_group(&"interactable"), "the machine can be used with E")
		_check(machine.save_id == &"machine.market_square", "the machine has a stable save id")
		_check(machine.get_offers().size() == 6, "the machine has six unlabelled slots")
		_check(not machine.is_unlocked(), "the machine starts asleep")
		_check(
			machine.get_interaction_text() == "Look at the machine",
			"an asleep machine only offers a look"
		)

		var stub := Stub.new()
		add_child(stub)
		await get_tree().process_frame

		_check(not machine.unlock_with(stub), "the machine refuses without the odd coin")
		stub.inventory.add_item(ItemDatabase.get_item(&"item.spider_coin"), 1)
		_check(machine.unlock_with(stub), "the odd coin wakes the machine")
		_check(
			stub.inventory.get_amount(&"item.spider_coin") == 0,
			"the coin is spent once, not kept"
		)
		_check(machine.is_unlocked(), "the machine stays awake")

		stub.inventory.add_item(ItemDatabase.get_item(&"item.seaglass"), 3)
		var offers := machine.get_offers()
		_check(offers[0]["pay"] == &"item.seaglass", "the first slot takes sea glass")
		_check(machine.buy(0, stub), "sea glass buys a moss-covered rock")
		_check(stub.inventory.get_amount(&"item.moss_rock") == 1, "the goods reach the bag")
		_check(stub.inventory.get_amount(&"item.seaglass") == 1, "the machine keeps its price")
		_check(machine.get_remaining(0) == 3, "one vend empties one slot space")

		_check(offers[4]["pay"] == &"item.gemstone", "the brooch slot takes a gemstone")
		_check(not machine.buy(4, stub), "a slot refuses without its payment")
		_check(stub.inventory.get_amount(&"item.gemstone") == 0, "a refused vend takes nothing")

		var saved_machine := machine.save_data()
		machine.load_data({"unlocked": false, "remaining": {}})
		_check(not machine.is_unlocked(), "a blank load puts the machine to sleep")
		machine.load_data(saved_machine)
		_check(machine.is_unlocked(), "a saved machine stays awake")
		_check(machine.get_remaining(0) == 3, "a saved machine keeps its stock")

		stub.queue_free()
		await get_tree().process_frame

		# The panel itself: opens on E, lists the slots, and closes again.
		var town_walker := town.get_node_or_null("Player") as PlayerController
		if town_walker != null:
			machine.interact(town_walker)
			await get_tree().process_frame
			_check(machine.is_open(), "E opens the machine's slot list")
			var rows := machine.get_node_or_null("MachineUI")
			_check(rows != null and rows.visible, "the machine panel is on screen")
			_check(machine.get_interaction_text() == "", "an open machine offers no prompt")
			machine.close_panel()
			await get_tree().process_frame
			_check(not machine.is_open(), "E closes the machine again")

	# --- the odd coin waits in Rowan's own house --------------------------
	var room_scene := load("res://features/world/interiors/rooms/rowans_house.tscn") as PackedScene
	_check(room_scene != null, "Rowan's house scene loads")
	if room_scene != null:
		var state := room_scene.get_state()
		var coin_node := -1
		for i in state.get_node_count():
			if state.get_node_name(i) == "OddCoin":
				coin_node = i
		_check(coin_node >= 0, "the odd coin sits in Rowan's house")
		if coin_node >= 0:
			var coin_id: Variant = &""
			var coin_save: Variant = &""
			for p in state.get_node_property_count(coin_node):
				var prop := String(state.get_node_property_name(coin_node, p))
				if prop == "item_id":
					coin_id = state.get_node_property_value(coin_node, p)
				elif prop == "save_id":
					coin_save = state.get_node_property_value(coin_node, p)
			_check(coin_id == &"item.spider_coin", "the family coin is the machine's key")
			_check(
				coin_save == &"pickup.town.rowans_house.odd_coin",
				"the coin has a stable save id"
			)

	# --- map fast travel --------------------------------------------------
	var town_player := town.get_node_or_null("Player") as PlayerController
	var map := town.get_node_or_null("HUD/MapScreen") as Control
	_check(town_player != null and map != null, "the town has a player and a map")
	if town_player != null and map != null:
		_check(town_player.get_spell_caster() != null, "the town player can cast Recall")
		var arrival := TownRealm.arrival_for(&"ashfall")
		_check(arrival != Vector3.ZERO, "Ashfall has a fast-travel arrival point")

		QuestLog.set_flag(&"visited.ashfall")
		var dialogue := town.get_node_or_null("HUD/DialogueWindow")
		if dialogue != null and dialogue.has_method("close"):
			dialogue.call("close")
		map.call("open")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var card := map.find_child("AshfallCard", true, false) as Control
		var travel_button: Button = null
		if card != null:
			travel_button = card.find_child("TravelButton", true, false) as Button
		_check(travel_button != null, "the Ashfall card has a travel button")
		if travel_button != null:
			_check(not travel_button.disabled, "a visited village can be travelled to")
			travel_button.pressed.emit()
			await get_tree().process_frame
			_check(
				town_player.global_position.distance_to(arrival) < 0.5,
				"pressing travel moves the player to the village"
			)
			_check(not map.visible, "travelling closes the map")

	# --- dirt paths, flowers, and the workbench asset -----------------------
	for texture_path in [
		"res://assets/from_2d/materials/path_dirt.png",
		"res://assets/from_2d/materials/path_cobble.png",
		"res://assets/from_2d/sprites/flower_cluster_a.png",
		"res://assets/from_2d/sprites/flower_cluster_b.png",
		"res://assets/from_2d/sprites/flower_cluster_c.png",
	]:
		_check(load(texture_path) is Texture2D, "path art exists: %s" % texture_path)

	for lane in [
		"PathToBakery", "PathToRowans", "PathToChapel", "PathNorthGate",
		"PathEastGate", "LaneNorthRow", "LaneEastRow", "LaneRuins",
	]:
		var strip := town.get_node_or_null("Realm/%s" % lane)
		_check(strip != null, "the realm has a dirt lane: %s" % lane)

	_check(not _uses_texture(town, "fern.png"), "no fern billboards outside town")

	var bench := town.get_node_or_null("Crafting/MarketBench")
	_check(bench != null, "the market has a crafting bench")
	if bench != null:
		_check(bench.get_node_or_null("Bench") != null, "the bench has a built workbench visual")

	# --- the wells remember the town --------------------------------------
	var well := town.get_node_or_null("WellCounting") as LoreWell
	_check(well != null, "the Counting Well stands in town")
	if well != null and town_player != null:
		QuestLog.clear_flag(&"well.counting")
		var silk_before := town_player.get_stats_component().get_silk()
		town_player.get_stats_component().set_silk(50.0)
		well.interact(town_player)
		_check(
			town_player.get_stats_component().get_silk() > 50.0,
			"the Counting Well repairs silk once"
		)
		_check(well.get_interaction_text() == "Remember the well", "a paid well is quiet after")
		town_player.get_stats_component().set_silk(silk_before)

	# --- the notice board pays for foraged goods --------------------------
	var board := town.get_node_or_null("BountyBoard") as BountyBoard
	_check(board != null, "the market has a notice board")
	if board != null and town_player != null:
		var bag := town_player.get_inventory_component()
		bag.add_item(ItemDatabase.get_item(&"item.stone"), 5)
		_check(board.pay(0, town_player), "a filled bounty is paid out")
		_check(board.get_bounty_count(0) == 1, "the board remembers which bounty was done")

	# --- the communal garden plants and grows -----------------------------
	var plot := town.get_node_or_null("GardenPlot") as GardenPlot
	_check(plot != null, "the communal garden plot is placed")
	if plot != null and town_player != null:
		var garden_bag := town_player.get_inventory_component()
		garden_bag.add_item(ItemDatabase.get_item(&"item.planting_mushroom"), 1)
		garden_bag.add_item(ItemDatabase.get_item(&"item.dirt_sack"), 1)
		_check(plot.plant(town_player), "a mushroom and a dirt sack can be planted")
		var kept_day := WorldClock.get_day()
		WorldClock.day += plot.grow_days
		_check(plot.is_ready(), "the crop is ready after its growing days")
		_check(plot.harvest(town_player), "a grown crop can be harvested")
		_check(plot.get_harvests() == 1, "the plot counts the harvest")
		WorldClock.day = kept_day

	# --- the vended trinkets do something ---------------------------------
	if town_player != null:
		var trinket_stats := town_player.get_stats_component()
		var trinket_bag := town_player.get_inventory_component()
		trinket_stats.set_silk(40.0)
		trinket_bag.add_item(ItemDatabase.get_item(&"item.small_opal"), 1)
		_check(town_player.use_item(&"item.small_opal"), "a small opal is usable")
		_check(trinket_stats.get_silk() > 40.0, "the opal repairs silk")

		trinket_stats.set_anchoring(0)
		trinket_bag.add_item(ItemDatabase.get_item(&"item.faux_ivory_brooch"), 1)
		_check(town_player.use_item(&"item.faux_ivory_brooch"), "a faux ivory brooch is usable")
		_check(trinket_stats.get_anchoring() == 1, "the brooch pretends to be an anchor")

	# --- hidden memories keep rewards -------------------------------------
	for entry in [
		["HiddenMemoryMill", &"memory.mill"],
		["HiddenMemoryFerry", &"memory.ferry"],
		["HiddenMemorySwarm", &"memory.swarm"],
		["HiddenMemoryNames", &"memory.names"],
	]:
		var memory_stone_node := town.get_node_or_null("Realm/%s" % entry[0]) as MemoryStone
		_check(memory_stone_node != null, "a hidden memory waits: %s" % entry[0])
		if memory_stone_node != null:
			_check(
				memory_stone_node.reward_flag == entry[1],
				"%s knows its reward flag" % entry[0]
			)

	# --- rivers are felt, not walls ---------------------------------------
	var wade := _find_prefix(town.get_node_or_null("Realm"), "SouthRiverWestWade")
	_check(wade != null and wade is RiverWade, "the south river has a wading area")
	if town_player != null:
		town_player.set_environment_speed(0.55)
		_check(
			is_equal_approx(town_player.get_environment_speed(), 0.55),
			"the player can be slowed by water"
		)
		town_player.set_environment_speed(1.0)
		_check(
			is_equal_approx(town_player.get_environment_speed(), 1.0),
			"the player returns to normal speed"
		)

	# --- the map reveals itself as it is walked ---------------------------
	WorldMap.reset()
	var cell := WorldMap.cell_of(Vector3(4.0, 0.0, 6.0))
	_check(not WorldMap.is_seen(cell.x, cell.y), "the map starts fogged")
	_check(WorldMap.reveal(Vector3(4.0, 0.0, 6.0)), "walking reveals map squares")
	_check(WorldMap.is_seen(cell.x, cell.y), "the walked square is seen")
	var map_blob := WorldMap.save_data()
	WorldMap.reset()
	_check(WorldMap.get_seen_count() == 0, "a new game clears the map")
	WorldMap.load_data(map_blob)
	_check(WorldMap.is_seen(cell.x, cell.y), "the map survives a save round-trip")

	var minimap := town.get_node_or_null("HUD/Minimap")
	_check(minimap is Minimap, "the HUD carries the minimap")

	# --- the villages keep their own stories ------------------------------
	var ashfall_well := town.get_node_or_null("Realm/AshfallWell") as LoreWell
	_check(ashfall_well != null, "Ashfall has a well of its own")
	if ashfall_well != null and town_player != null:
		QuestLog.clear_flag(&"well.ashfall")
		var bog_silk := town_player.get_stats_component().get_silk()
		town_player.get_stats_component().set_silk(40.0)
		ashfall_well.interact(town_player)
		_check(
			town_player.get_stats_component().get_silk() > 40.0,
			"the Bog Well pays once"
		)
		town_player.get_stats_component().set_silk(bog_silk)

	var thorn_well := town.get_node_or_null("Realm/ThornridgeWell") as LoreWell
	_check(thorn_well != null, "Thornridge has a well of its own")

	for entry in [
		["HiddenMemoryAshfallCount", &"memory.ashfall_flake"],
		["HiddenMemoryAshfallLantern", &"memory.ashfall_lantern"],
		["HiddenMemoryThornBridge", &"memory.thorn_bridge"],
		["HiddenMemoryThornQuarry", &"memory.thorn_quarry"],
	]:
		var village_stone := town.get_node_or_null("Realm/%s" % entry[0]) as MemoryStone
		_check(village_stone != null, "a village memory waits: %s" % entry[0])
		if village_stone != null:
			_check(
				village_stone.reward_flag == entry[1],
				"%s has its reward flag" % entry[0]
			)

	# --- ambience and the river loop --------------------------------------
	for audio_path in [
		"res://assets/audio/ambience/wind_soft.wav",
		"res://assets/audio/ambience/night_hum.wav",
		"res://assets/audio/ambience/river_flow.wav",
		"res://assets/audio/ambience/bell_distant.wav",
	]:
		_check(load(audio_path) is AudioStream, "ambience exists: %s" % audio_path)

	var ambient := town.get_node_or_null("AmbientAudio") as AmbientAudio
	_check(ambient != null, "the town has an ambience node")
	if ambient != null:
		var kept_hour := WorldClock.get_hour()
		WorldClock.hour = 12.0
		ambient.refresh_now()
		_check(not ambient.is_night_playing(), "day selects the wind loop")
		WorldClock.hour = 23.0
		ambient.refresh_now()
		_check(ambient.is_night_playing(), "night selects the drone loop")
		WorldClock.hour = kept_hour
		if wade != null:
			_check(
				wade.get_node_or_null("RiverSound") != null,
				"the wading area carries a river loop"
			)

	# --- the bench is a real workbench ------------------------------------
	if bench != null:
		var bench_body := bench.get_node_or_null("Bench")
		_check(
			bench_body != null and bench_body.get_child_count() >= 20,
			"the bench has a full set of parts"
		)
		_check(
			bench_body != null and bench_body.get_node_or_null("BenchLight") != null,
			"the bench carries its own lantern light"
		)

	# --- the coin is hand-painted art -------------------------------------
	var coin_texture := load("res://assets/from_2d/sprites/odd_coin.png") as Texture2D
	_check(coin_texture != null, "the odd coin has a painted sprite")
	if coin_texture != null:
		var coin_image := coin_texture.get_image()
		_check(
			coin_image != null and coin_image.detect_alpha() != Image.ALPHA_NONE,
			"the coin sprite has a transparent edge"
		)

	# --- field notes: places and stride -----------------------------------
	_check(InputMap.has_action(&"field_notes"), "C is bound in the Input Map")
	_check(ExplorationLog.get_total() >= 14, "the checklist knows the Hollow and beyond")
	ExplorationLog.reset()
	_check(ExplorationLog.get_seen_count() == 0, "the checklist starts empty")
	var fresh_places := ExplorationLog.check(Vector3(17.0, 0.0, -9.0))
	_check(not fresh_places.is_empty(), "standing in the market ticks a place")
	_check(ExplorationLog.has(&"place.market"), "the market is recorded by id")
	var places_blob := ExplorationLog.save_data()
	ExplorationLog.reset()
	ExplorationLog.load_data(places_blob)
	_check(ExplorationLog.has(&"place.market"), "visited places survive a save")

	MovementStats.reset()
	MovementStats.record_jump()
	MovementStats.record_landing(0.0, 1.6, 0.0, 0.6)
	_check(MovementStats.get_jumps() == 1, "a jump is counted")
	_check(
		is_equal_approx(MovementStats.get_best_jump(), 1.6),
		"the highest jump is measured"
	)
	MovementStats.record_landing(3.0, 3.4, 0.8, 0.9)
	_check(
		is_equal_approx(MovementStats.get_best_drop(), 2.2),
		"a drop below the takeoff is measured"
	)
	var stride_blob := MovementStats.save_data()
	MovementStats.reset()
	MovementStats.load_data(stride_blob)
	_check(MovementStats.get_jumps() == 1, "stride records survive a save")

	var notes := town.get_node_or_null("HUD/FieldNotes")
	_check(notes != null, "the HUD carries Field Notes")
	if notes != null:
		var notes_dialogue := town.get_node_or_null("HUD/DialogueWindow")
		if notes_dialogue != null and notes_dialogue.visible:
			notes_dialogue.call("close")
		notes.call("open")
		await get_tree().process_frame
		_check(notes.visible, "C opens the Field Notes")
		var flags_blob := QuestLog.save_data()
		QuestLog.reset()
		QuestLog.set_flag(&"teach.thatch.0")
		notes.call("_refresh")
		_check(
			_has_label_text(notes, "Lessons learned"),
			"Field Notes records lessons learned"
		)
		_check(
			_has_label_text(notes, "1 of %d" % MagicLessons.get_total()),
			"the lessons row counts a learned lesson"
		)
		QuestLog.load_data(flags_blob)
		notes.call("_refresh")
		notes.call("close")
		await get_tree().process_frame
		_check(not notes.visible, "C closes them again")

	# --- rooms and the line written on a first visit ----------------------
	ExplorationLog.reset()
	_check(ExplorationLog.get_room_count() == 0, "Field Notes starts with no rooms")
	var room_id: StringName = ExplorationLog.note_scene(
		"res://features/world/interiors/rooms/rowans_house.tscn", "RowansHouseInterior"
	)
	_check(room_id == &"room.rowans_house", "an interior is noted by its scene, not its position")
	_check(
		ExplorationLog.get_room_title(room_id) == "Rowan's House",
		"a listed room takes its title from the table"
	)
	_check(
		ExplorationLog.note_scene(
			"res://features/world/interiors/rooms/rowans_house.tscn", "RowansHouseInterior"
		).is_empty(),
		"a room is only counted once"
	)
	_check(
		ExplorationLog.note_scene("res://scenes/town.tscn", "Town").is_empty(),
		"the open town is not counted as a room"
	)
	var untitled: StringName = ExplorationLog.note_scene(
		"res://features/world/interiors/rooms/ford_cottage.tscn", "FordCottageInterior"
	)
	_check(not untitled.is_empty(), "a room with no table entry is still counted")
	_check(
		ExplorationLog.get_room_title(untitled) == "Ford Cottage",
		"an unlisted room falls back to a prettified name (%s)"
		% ExplorationLog.get_room_title(untitled)
	)
	_check(ExplorationLog.get_room_count() == 2, "two rooms are remembered")
	var room_blob := ExplorationLog.save_data()
	ExplorationLog.reset()
	_check(ExplorationLog.get_room_count() == 0, "reset clears the rooms")
	ExplorationLog.load_data(room_blob)
	_check(ExplorationLog.get_room_count() == 2, "rooms survive a save round-trip")

	_check(
		not ExplorationLog.get_line(&"place.market").is_empty(),
		"the market has a line written about it"
	)
	_check(
		ExplorationLog.get_line(&"place.not_a_place").is_empty(),
		"an unknown place has no line"
	)

	# --- three benches, one frame ----------------------------------------
	var station_scene := load("res://features/crafting/crafting_station.tscn") as PackedScene
	for kind: StringName in [&"market", &"forge", &"loom"]:
		var sample := station_scene.instantiate()
		sample.set("station_kind", kind)
		add_child(sample)
		await get_tree().process_frame

		var dressed := sample.get_node_or_null("Bench") as Node3D
		_check(dressed != null, "the %s bench dresses itself" % kind)
		var plain := sample.get_node_or_null("Mesh") as MeshInstance3D
		_check(
			plain != null and not plain.visible,
			"the %s bench hides its plain box instead of deleting it" % kind
		)
		_check(
			dressed != null and dressed.find_child("BenchLight", true, false) != null,
			"the %s bench carries its own lamp" % kind
		)

		var marker := "Vice"
		match kind:
			&"forge":
				marker = "AnvilBody"
			&"loom":
				marker = "LoomBeam"
		_check(
			dressed != null and dressed.find_child(marker, true, false) != null,
			"the %s bench builds its own tools (%s)" % [kind, marker]
		)
		sample.free()

	# Every bench shares the frame, so a bench is recognisable anywhere.
	_check(bench != null and String(bench.get("station_kind")) == "market", "the town bench is the market kind")

	# --- weather comes from the calendar ---------------------------------
	_check(Weather.kind_for_day(1) == Weather.CLEAR, "an ordinary day is clear")
	_check(Weather.kind_for_day(3) == Weather.CLEAR, "another ordinary day is clear too")
	_check(Weather.kind_for_day(7) == Weather.RAIN, "every seventh day rains")
	_check(Weather.kind_for_day(11) == Weather.RAIN, "the eleventh day rains as well")
	_check(Weather.kind_for_day(9) == Weather.FOG, "the ninth day is misty")
	var weather := town.get_node_or_null("Weather") as Weather
	_check(weather != null, "the town owns a weather node")
	if weather != null:
		_check(
			weather.is_raining() == (Weather.kind_for_day(WorldClock.get_day()) == Weather.RAIN),
			"the town's weather matches today's calendar entry"
		)
		var rain := weather.get_node_or_null("Rain") as CPUParticles3D
		_check(rain != null, "weather owns one rain emitter")
		if rain != null:
			_check(rain.emitting == weather.is_raining(), "rain only falls on a wet day")

	# --- regional ambience and the music bed -----------------------------
	var ambience := town.get_node_or_null("AmbientAudio")
	_check(ambience != null, "the town still owns its ambience")
	if ambience != null:
		var region_player := ambience.get_node_or_null("Region") as AudioStreamPlayer
		_check(region_player != null, "ambience owns a regional player")
		ambience.call("_set_region", &"snow")
		_check(ambience.call("get_region") == &"snow", "a regional bed can be selected")
		if region_player != null:
			_check(region_player.stream != null, "the snow bed has a stream")
		ambience.call("_set_region", &"marsh")
		_check(ambience.call("get_region") == &"marsh", "the marsh bed can be selected")
		ambience.call("_set_region", &"")
		_check(ambience.call("get_region") == &"", "the town itself has no regional bed")

	var music := town.get_node_or_null("Music") as MusicPlayer
	_check(music != null, "the town has a music bed")
	if music != null:
		_check(music.is_playing(), "the town theme is playing")
		var track := music.get_node_or_null("Track") as AudioStreamPlayer
		_check(track != null, "the music bed owns one player")
		if track != null:
			_check(track.bus == &"Music", "music rides the Music bus")
			_check(track.stream != null, "the town theme has a stream")
	_check(_scene_has_node("res://scenes/main_menu.tscn", "Music"), "the main menu has a music bed")

	# --- sound lives in the pause menu -----------------------------------
	_check(
		is_equal_approx(float(Settings.get_setting("audio/ambience_volume", -1.0)), 0.8),
		"there is an ambience volume setting"
	)
	_check(AudioServer.get_bus_index("Ambience") >= 0, "there is an Ambience bus to ride")
	var pause := town.get_node_or_null("PauseMenu")
	_check(pause != null, "the town still has a pause menu")
	if pause != null:
		var found_rows := 0
		for row_name in ["MusicRow", "AmbienceRow", "EffectsRow"]:
			if pause.find_child(row_name, true, false) != null:
				found_rows += 1
		_check(
			found_rows == 3,
			"the pause menu has three sound sliders (%d)" % found_rows
		)
		_check(
			pause.find_child("AmbienceSlider", true, false) != null,
			"the ambience slider is the one this batch added"
		)
		_check(
			pause.find_child("SoundHeading", true, false) != null,
			"the sound rows sit under a heading"
		)
		_check(
			pause.find_child("SoundRule", true, false) != null,
			"a rule separates sound from the buttons"
		)

	# --- Bell's counter --------------------------------------------------
	var vendor_scene := load("res://features/interaction/vendor_counter.tscn") as PackedScene
	var vendor := vendor_scene.instantiate() as VendorCounter
	add_child(vendor)
	await get_tree().process_frame
	_check(vendor.get_offers().size() == 4, "Bell's counter lists four things")
	Progression.reset()
	_check(vendor.get_price(0) == 6, "a stranger pays the full six coins")
	_check(not vendor.buy(0, null), "a counter with no customer sells nothing")

	var shopper := Stub.new()
	add_child(shopper)
	await get_tree().process_frame
	Progression.add_coins(100)
	var purse_before := Progression.get_coins()
	_check(vendor.buy(0, shopper), "coins buy the bread")
	_check(
		Progression.get_coins() == purse_before - 6,
		"the counter takes its six coins"
	)
	_check(shopper.inventory.has_item(&"item.sporebread"), "the bread reaches the bag")
	_check(
		Progression.get_favor(&"npc.auntie_bell") == 1,
		"buying once earns a little favor"
	)
	for i in 4:
		vendor.buy(0, shopper)
	_check(vendor.get_price(0) < 6, "a regular customer is charged less")

	Progression.spend_coins(Progression.get_coins())
	var empty_purse := Progression.get_coins()
	_check(not vendor.buy(0, shopper), "an empty purse buys nothing")
	_check(
		Progression.get_coins() == empty_purse,
		"a refused sale costs nothing"
	)

	Progression.add_coins(100)
	var stuffed := Stub.new()
	add_child(stuffed)
	await get_tree().process_frame
	# A bag with no room: the stub already carries one axe, so one slot is full.
	stuffed.inventory.capacity = stuffed.inventory.get_used_slots()
	_check(stuffed.inventory.is_full(), "the test bag can be made full")
	var full_purse := Progression.get_coins()
	_check(not vendor.buy(0, stuffed), "a full bag stops the sale")
	_check(Progression.get_coins() == full_purse, "a full bag costs nothing")
	_check(
		not stuffed.inventory.has_item(&"item.sporebread"),
		"no bread appears in a bag with no room"
	)

	vendor.queue_free()
	shopper.queue_free()
	stuffed.queue_free()
	await get_tree().process_frame

	# --- the Seamstress teaches magic ------------------------------------
	var seamstress := town.get_node_or_null("Villagers/BlindSeamstress") as MagicTeacher
	_check(seamstress != null, "the Seamstress on the street is a magic teacher")
	if seamstress != null:
		_check(
			seamstress.offers_quest == &"quest.seamstress_thread",
			"the teacher keeps her thread quest"
		)
		_check(
			seamstress.get_lesson_title(4) == "What I know of Fern",
			"the teacher carries the whole curriculum"
		)
		_check(
			seamstress.get_lesson_index() == 0,
			"the curriculum starts untaught"
		)
	_check(
		ResourceLoader.get_dependencies(
			"res://features/world/interiors/rooms/seamstress_cottage.tscn"
		).has("res://features/npc/magic_teacher.gd"),
		"the cottage Seamstress is the same teacher at night"
	)

	# --- the other named teachers ----------------------------------------
	var thatch_teacher := town.get_node_or_null("Villagers/Thatch") as MagicTeacher
	_check(thatch_teacher != null, "Thatch on the street is a magic teacher")
	if thatch_teacher != null:
		_check(
			thatch_teacher.curriculum == &"thatch",
			"Thatch teaches the hive curriculum"
		)
		_check(
			thatch_teacher.offers_quest == &"quest.thatch_hive",
			"Thatch keeps his flower quest"
		)
		_check(
			thatch_teacher.get_lesson_count() == 3,
			"Thatch's curriculum has three lessons"
		)

	var corin_teacher := town.get_node_or_null("Villagers/CorinVale") as MagicTeacher
	_check(corin_teacher != null, "Corin Vale on the street is a magic teacher")
	if corin_teacher != null:
		_check(
			corin_teacher.curriculum == &"corin",
			"Corin Vale teaches the tooth curriculum"
		)
		_check(
			corin_teacher.get_lesson_title(0) == "A tooth is a name",
			"Corin Vale's first lesson is about names"
		)
		_check(
			corin_teacher.scheduled
			and corin_teacher.active_from_hour == 8
			and corin_teacher.active_to_hour == 18,
			"the street Corin is a daytime placement"
		)

	var silas_teacher := town.get_node_or_null("Villagers/SilasGraye") as MagicTeacher
	_check(silas_teacher != null, "Silas Graye on the street is a magic teacher")
	if silas_teacher != null:
		_check(
			silas_teacher.curriculum == &"silas",
			"Silas Graye teaches the Ledger curriculum"
		)
		_check(
			silas_teacher.get_lesson_title(2) == "Who keeps the account",
			"Silas Graye ends on who keeps the Ledger"
		)

	_check(
		ResourceLoader.get_dependencies(
			"res://features/world/interiors/rooms/beekeeper_cottage.tscn"
		).has("res://features/npc/magic_teacher.gd"),
		"the cottage Thatch is the same teacher at night"
	)
	_check(
		ResourceLoader.get_dependencies(
			"res://features/world/interiors/rooms/toothkeepers_house.tscn"
		).has("res://features/npc/magic_teacher.gd"),
		"Corin Vale keeps the tooth house at night"
	)

	# --- ground lanes are one welded strip --------------------------------
	var lane := town.get_node_or_null("Realm/PathToBakery") as TownRibbon
	_check(lane != null, "the market lane exists as a ribbon")
	if lane != null:
		var meshes := 0
		var welded := 0
		for child in lane.get_children():
			var drawn := child as MeshInstance3D
			if drawn != null and drawn.mesh != null:
				meshes += 1
				if String(child.name).begins_with("Strip") and drawn.mesh is ArrayMesh:
					welded += 1
		_check(meshes == 1, "a lane is one mesh, not a chain of tiles (%d)" % meshes)
		_check(welded == 1, "the lane strip is a welded ArrayMesh")

	# --- every town villager walks the square -----------------------------
	for walker_name in [
		"AuntieBell", "SilasGraye", "CorinVale", "ElowenThistle", "SisterHolloway",
		"CrowCollector", "BakeryGirl", "GlassEyedJune", "MothDancer",
	]:
		var walker := town.get_node_or_null("Villagers/" + walker_name) as Npc
		_check(
			walker != null and walker.wander and walker.wander_points.size() >= 4,
			"%s walks the market square" % walker_name
		)

	var village_wanderers := 0
	var realm_node := town.get_node_or_null("Realm")
	if realm_node != null:
		for node in realm_node.get_children():
			var village_npc := node as Npc
			if village_npc == null:
				continue
			if village_npc.wander and village_npc.wander_points.size() >= 4:
				village_wanderers += 1
	_check(
		village_wanderers >= 4,
		"village folk wander their own green (%d)" % village_wanderers
	)

	# --- the Spider Mother moved below the old houses ---------------------
	_check(
		town.get_node_or_null("Villagers/SpiderMother") == null,
		"the Spider Mother no longer waits in the street"
	)
	var lair_gate := town.get_node_or_null("Realm/LairGate") as AreaGate
	_check(lair_gate != null, "a stair down to the lair stands under the old houses")
	if lair_gate != null:
		_check(
			lair_gate.target_scene == "res://features/world/cave/spider_lair.tscn",
			"the stair opens into the lair"
		)
		_check(lair_gate.interior, "the lair remembers the doorstep it was entered from")

	var wild_gate := town.get_node_or_null("Realm/WildCaveGate") as AreaGate
	_check(wild_gate != null, "a cleft out past the old cottages opens into the wild caves")
	if wild_gate != null:
		_check(
			wild_gate.target_scene == "res://features/world/cave/wild_caves.tscn",
			"the cleft opens into the random caves, not the Old Adit"
		)
		_check(wild_gate.interior, "the wild caves return the player to the cleft")

	# --- fog surges bite ---------------------------------------------------
	var fog = town.get_node_or_null("FogSurge")
	_check(fog != null, "the town has fog surges")
	if fog != null and town_player != null:
		_check(fog.is_dangerous(), "a fog surge is dangerous now")
		_check(
			fog.get("summon_scene") is PackedScene,
			"the mist can call something out of the white"
		)
		_check(
			float(fog.get("memory_drain_per_second")) > 0.0, "the mist drinks memory"
		)
		_check(
			float(fog.get("silk_drain_per_second")) > 0.0, "the mist frays silk"
		)

		var fog_stats := town_player.get_stats_component()
		fog_stats.set_memory(60.0)
		fog_stats.set_silk(60.0)
		fog.set("fade_time", 0.02)
		fog.set("hold_time", 0.3)
		fog.set("memory_drain_per_second", 200.0)
		fog.set("silk_drain_per_second", 100.0)
		fog.set("summon_interval", 0.05)
		fog.set("max_summons", 1)
		# A bare Node3D stands in for a fog creature, so the check proves the
		# summon path without putting a hostile enemy into a long test.
		var probe_scene := PackedScene.new()
		var probe_root := Node3D.new()
		probe_root.name = "FogSummonProbe"
		probe_scene.pack(probe_root)
		probe_root.free()
		fog.set("summon_scene", probe_scene)
		fog.force_surge()
		await get_tree().create_timer(0.35).timeout
		_check(fog_stats.get_memory() < 60.0, "the mist drains memory while it holds")
		_check(fog_stats.get_silk() < 60.0, "the mist frays silk while it holds")
		_check(fog.get_summon_count() >= 1, "the mist sends something walking")
		fog.set("memory_drain_per_second", 0.0)
		fog.set("silk_drain_per_second", 0.0)
		fog.set("summon_interval", 9999.0)

	# --- the lair under the houses ----------------------------------------
	var lair_scene := load("res://features/world/cave/spider_lair.tscn") as PackedScene
	_check(lair_scene != null, "the lair scene loads")
	if lair_scene != null:
		var lair := lair_scene.instantiate() as WildCaves
		add_child(lair)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(lair.is_lair, "the lair is dressed as a lair")
		_check(lair.fixed_seed == 20261114, "the lair keeps one seed, so it cannot move")
		_check(
			lair.get_wall_count() > 20,
			"the lair is a room in the rock (%d wall blocks)" % lair.get_wall_count()
		)
		_check(lair.get_node_or_null("ExitDoor") != null, "the lair has a way back up")
		var mother := lair.get_node_or_null("SpiderMother") as SpiderMother
		_check(mother != null, "the Spider Mother keeps her lair")
		if mother != null:
			_check(
				mother.get_node_or_null("Model/Abdomen") != null,
				"the Spider Mother has a spider's abdomen"
			)
			_check(
				mother.get_node_or_null("Model/LegUpper0_0") != null,
				"the Spider Mother stands on spider legs"
			)
			_check(
				mother.get_node_or_null("Model/Head") != null,
				"the Spider Mother keeps a woman's head"
			)
		lair.queue_free()
		await get_tree().process_frame

	# --- the wild caves are never the same twice --------------------------
	var wild_scene := load("res://features/world/cave/wild_caves.tscn") as PackedScene
	_check(wild_scene != null, "the wild cave scene loads")
	if wild_scene != null:
		var first := wild_scene.instantiate() as WildCaves
		add_child(first)
		await get_tree().process_frame
		await get_tree().process_frame
		var first_seed := first.get_cave_seed()
		_check(
			first.get_wall_count() > 20,
			"a wild cave is carved from rock (%d wall blocks)" % first.get_wall_count()
		)
		_check(first.get_node_or_null("ExitDoor") != null, "a wild cave has a way out")
		_check(first.get_node_or_null("Music") != null, "a wild cave has its own music")
		first.queue_free()
		await get_tree().process_frame

		var second := wild_scene.instantiate() as WildCaves
		add_child(second)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(
			second.get_cave_seed() != first_seed,
			"two visits to the wild caves are different caves"
		)
		second.queue_free()
		await get_tree().process_frame

	# --- Mister Rabbit ----------------------------------------------------
	var cottage_scene := load(
		"res://features/world/interiors/rooms/garden_cottage.tscn"
	) as PackedScene
	_check(cottage_scene != null, "the garden cottage loads")
	if cottage_scene != null:
		var cottage := cottage_scene.instantiate()
		add_child(cottage)
		await get_tree().process_frame
		await get_tree().process_frame
		var rabbit := cottage.get_node_or_null("MisterRabbit") as StuffedRabbit
		_check(rabbit != null, "Mister Rabbit sits in the garden cottage")
		if rabbit != null:
			_check(rabbit.is_in_group(&"interactable"), "Mister Rabbit can be looked at")
			_check(
				rabbit.get_interaction_text().contains("Mister Rabbit"),
				"the rabbit is named when you look at it"
			)
			_check(rabbit.notice_distance > 0.0, "the rabbit turns to face whoever is near")
			var stitched := rabbit.get_node_or_null("RabbitBody")
			_check(
				stitched != null and stitched.get_child_count() > 8,
				"the rabbit is stitched from more than one part"
			)
		cottage.queue_free()
		await get_tree().process_frame

	# --- the fern billboards are gone -------------------------------------
	_check(not _uses_texture(town, "fern.png"), "no fern billboards outside town")

	print("GATHERING_CHECKS=%d FAILURES=%d" % [_fail_total, _failures])
	print("GATHERING_SMOKE_OK" if _failures == 0 else "GATHERING_SMOKE_FAILED")
	town.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + label)
	if not ok:
		_failures += 1
	_fail_total += 1


var _failures := 0
var _fail_total := 0


## Reads a scene's saved node list without instantiating it, so checking that a
## menu owns a music bed does not build a second main menu (which would change
## the game state out from under the test).
func _scene_has_node(scene_path: String, node_name: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var state := packed.get_state()
	for i in state.get_node_count():
		if String(state.get_node_name(i)) == node_name:
			return true
	return false


func _find_drop(root: Node, item: StringName) -> GatherNode:
	for node in root.find_children("*", "StaticBody3D", true, false):
		var gather := node as GatherNode
		if gather != null and gather.drop_item == item and gather.save_id != &"":
			return gather
	return null


func _find_prefix(root: Node, prefix: String) -> Node:
	for node in root.find_children(prefix + "*", "", true, false):
		return node
	return null


## True when any Label under `root` contains `needle`. Field Notes is built in
## code, so its rows have no unique names to look up.
func _has_label_text(root: Node, needle: String) -> bool:
	var label := root as Label
	if label != null and label.text.contains(needle):
		return true
	for child in root.get_children():
		if _has_label_text(child, needle):
			return true
	return false


func _uses_texture(root: Node, needle: String) -> bool:
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		var mat := batch.material_override as StandardMaterial3D
		if mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.contains(needle):
			return true
	for node in root.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		if sprite.texture != null and sprite.texture.resource_path.contains(needle):
			return true
	return false
