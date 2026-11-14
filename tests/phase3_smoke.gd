extends Node
## Phase 3 smoke test.
##
## Run from a terminal:
##   godot --headless --path . tests/phase3_smoke.tscn
## Or open this scene in the editor and press F6.
##
## Covers the world clock, the save format, the slot model, autosave and quick
## save, the saveable contract on the player, chests, the door and the enemy, a
## full write/read/apply round trip, corrupt and future-version saves, chunk
## streaming through the fixture chunks, chunk-origin placement, the town scene
## wiring and its wider-world Realm node, the HUD clock, and the pause-menu
## save/load buttons. Prints PHASE3_SMOKE_OK on success.

const EPSILON := 0.02
## Slot 9 is reserved for this test and is always deleted again.
const TEST_SLOT := 9
const PLAYER_ID := &"player"
const CHUNK_DIRECTORY := "res://tests/fixtures/chunks"
const CHUNK_SIZE := 32.0
const TOWN_SCENE := "res://scenes/town.tscn"

var _failures: PackedStringArray = []
var _room: Node3D
var _player: PlayerController
var _hud: CanvasLayer
var _pause: CanvasLayer
## Raw JSON of slots 0 and 1, so a test run never destroys a real save.
var _slot_backup: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_backup_slots()
	SaveManager.delete_slot(TEST_SLOT)

	_check_clock()
	_check_save_manager_api()
	_check_slot_model()

	var packed := load("res://scenes/test_room.tscn") as PackedScene
	_check(packed != null, "test room scene loads")
	if packed == null:
		await _finish()
		return

	_room = packed.instantiate() as Node3D
	add_child(_room)
	await _physics_frames(4)

	_check_saveable_contract()
	await _check_round_trip()
	_check_storage_errors()
	await _check_chunk_manager()
	_check_chunk_origins()
	_check_hud_and_pause_menu()
	_check_game_save()
	_check_quick_save_and_autosave()
	_check_exterior_scene()
	_check_slot_selection()

	SaveManager.delete_slot(TEST_SLOT)
	await _finish()


# --- world clock ----------------------------------------------------------


func _check_clock() -> void:
	WorldClock.reset()
	_check(WorldClock.get_day() == 1, "the clock starts on day 1")
	_check(is_equal_approx(WorldClock.get_hour(), 8.0), "the clock starts at 08:00")
	_check(WorldClock.get_clock_string() == "08:00", "the clock formats as HH:MM")
	_check(WorldClock.get_time_string() == "Day 1 · 08:00", "the clock formats a day stamp")

	WorldClock.advance(60.0)
	_check(
		is_equal_approx(WorldClock.get_hour(), 9.0),
		"60 real seconds advance one game hour (%.3f)" % WorldClock.get_hour()
	)

	WorldClock.advance(15.0 * 60.0)
	_check(WorldClock.get_day() == 2, "crossing midnight rolls the day over")
	_check(WorldClock.get_hour() < EPSILON, "midnight resets the hour to 0")
	_check(WorldClock.get_clock_string() == "00:00", "midnight formats as 00:00")

	var saved := WorldClock.save_data()
	WorldClock.reset()
	WorldClock.load_data(saved)
	_check(WorldClock.get_day() == 2, "the clock round-trips its day")
	_check(WorldClock.get_hour() < EPSILON, "the clock round-trips its hour")

	WorldClock.load_data({"day": -5, "hour": 99.0})
	_check(WorldClock.get_day() == 1, "a nonsense day is clamped to 1")
	_check(WorldClock.get_hour() < 24.0, "a nonsense hour is clamped below 24")

	WorldClock.reset()


# --- save manager API -----------------------------------------------------


func _check_save_manager_api() -> void:
	_check(SaveManager.SAVE_VERSION == 1, "the save format starts at version 1")
	_check(not SaveManager.has_slot(TEST_SLOT), "the test slot starts empty")
	_check(
		SaveManager.read_slot(TEST_SLOT).is_empty(),
		"reading a missing slot returns an empty dictionary"
	)
	_check(
		not SaveManager.get_last_error().is_empty(),
		"a missing slot records a reason in get_last_error()"
	)


# --- slot model -----------------------------------------------------------


func _check_slot_model() -> void:
	_check(Game.MANUAL_SLOT == 0, "slot 0 is the manual/quicksave slot")
	_check(Game.AUTOSAVE_SLOT == 1, "slot 1 is the autosave slot")
	_check(
		Game.SAVE_SLOTS.has(Game.MANUAL_SLOT) and Game.SAVE_SLOTS.has(Game.AUTOSAVE_SLOT),
		"the known slot list covers manual and autosave"
	)
	_check(
		Game.PLAYER_ENTRY_ID == String(PlayerController.SAVE_ID),
		"the player entry id matches the player's save id"
	)
	_check(InputMap.has_action(&"quick_save"), "F5 quicksave is an input action")
	_check(InputMap.has_action(&"quick_load"), "F9 quickload is an input action")


## Uses slots 7 and 8 so the real slots 0 and 1 are never consulted here.
func _check_slot_selection() -> void:
	const OLD_SLOT := 7
	const NEW_SLOT := 8
	SaveManager.delete_slot(OLD_SLOT)
	SaveManager.delete_slot(NEW_SLOT)

	var base := {
		"version": SaveManager.SAVE_VERSION,
		"scene": "res://scenes/test_room.tscn",
		"world": {},
		"saveables": {},
	}
	var old := base.duplicate(true)
	old["saved_at"] = "2026-01-01T10:00:00"
	var fresh := base.duplicate(true)
	fresh["saved_at"] = "2026-11-02T22:00:00"

	_check(SaveManager.write_save_dict(OLD_SLOT, old), "an older save writes to slot 7")
	_check(SaveManager.write_save_dict(NEW_SLOT, fresh), "a newer save writes to slot 8")
	_check(
		Game.newest_slot([OLD_SLOT, NEW_SLOT]) == NEW_SLOT,
		"newest_slot() picks the later timestamp"
	)
	_check(Game.has_any_save([OLD_SLOT, NEW_SLOT]), "has_any_save() sees the test slots")

	SaveManager.delete_slot(NEW_SLOT)
	_check(
		Game.newest_slot([OLD_SLOT, NEW_SLOT]) == OLD_SLOT,
		"newest_slot() falls back to the remaining save"
	)

	SaveManager.delete_slot(OLD_SLOT)
	_check(
		not Game.has_any_save([OLD_SLOT, NEW_SLOT]),
		"has_any_save() is false with no saves"
	)
	_check(
		Game.newest_slot([OLD_SLOT, NEW_SLOT]) == -1,
		"newest_slot() returns -1 with no saves"
	)


# --- saveable contract ----------------------------------------------------


func _check_saveable_contract() -> void:
	_player = _room.get_node_or_null("Player") as PlayerController
	_check(_player != null, "the room has a player")
	if _player == null:
		return

	var expected := {
		"Player": PLAYER_ID,
		"Door": &"door.test_room.main",
		"Chest": &"chest.test_room.sword",
		"ChestPotion": &"chest.test_room.potion",
		"ChestArmor": &"chest.test_room.armor",
		"Enemy": &"enemy.test_room.grunt",
	}

	for node_name in expected.keys():
		var node := _room.get_node_or_null(String(node_name))
		_check(node != null, "%s exists in the test room" % node_name)
		if node == null:
			continue

		_check(node.is_in_group(&"saveable"), "%s joins the saveable group" % node_name)
		_check(
			node.has_method("get_save_id")
			and node.has_method("save_data")
			and node.has_method("load_data"),
			"%s implements the saveable contract" % node_name
		)
		_check(
			StringName(node.call("get_save_id")) == expected[node_name],
			"%s has the expected save id" % node_name
		)

	var seen: Dictionary = {}
	var duplicates := false
	for node in get_tree().get_nodes_in_group("saveable"):
		var id := String(node.call("get_save_id"))
		if seen.has(id):
			duplicates = true
		seen[id] = true
	_check(not duplicates, "no two saveables share an id")


# --- round trip -----------------------------------------------------------


func _check_round_trip() -> void:
	var chest := _room.get_node("Chest") as Node3D
	var door := _room.get_node("Door") as Node3D
	var enemy := _room.get_node("Enemy") as Node3D
	var lid := chest.get_node("LidPivot") as Node3D
	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	var inventory := _player.get_inventory_component()
	var equipment := _player.get_equipment_component()
	var health := _player.get_health_component()
	var stats := _player.get_stats_component()

	# The clock is driven by `Game` while the state is PLAYING.
	var clock_before := WorldClock.get_hour()
	await _frames(3)
	_check(
		WorldClock.get_hour() > clock_before,
		"the world clock advances while the game is playing"
	)

	# --- a distinctive state to save
	_player.global_position = Vector3(2.0, 0.2, 3.0)
	_player.rotation.y = 0.5
	inventory.clear()
	inventory.add_item(_item(&"item.iron_sword"), 1)
	_check(_player.try_equip(&"item.iron_sword"), "the player equips the sword before saving")
	inventory.add_item(_item(&"item.health_potion"), 3)
	health.set_health(55.0)
	stats.set_stamina(40.0)
	WorldClock.day = 3
	WorldClock.hour = 21.5

	chest.call("interact", _player)
	_check(bool(chest.get("is_open")), "the sword chest opens before saving")
	door.call("interact", null)
	_check(bool(door.get("is_open")), "the door opens before saving")
	enemy_health.take_damage(999.0)
	_check(enemy.call("get_state_name") == &"DEAD", "the enemy is defeated before saving")

	# Quest and discovery progress live in the save's `world` block beside the
	# clock, not on a node, so they are checked in the same round trip.
	QuestLog.reset()
	DiscoveryLog.reset()
	_check(QuestLog.start(QuestLog.THATCH_HIVE), "the Thatch quest starts before saving")
	_check(QuestLog.complete(QuestLog.ROWAN_LEDGER), "the Rowan quest completes before saving")
	_check(
		DiscoveryLog.unlock(DiscoveryLog.FUNGAL_RECORD),
		"the fungal record unlocks before saving"
	)

	var data := SaveManager.build_save_dict()
	_check(
		int(data.get("version", 0)) == SaveManager.SAVE_VERSION,
		"the built save carries the format version"
	)
	_check(
		String(data.get("scene", "")) == get_tree().current_scene.scene_file_path,
		"the save records the running scene path"
	)
	var world: Dictionary = data.get("world", {})
	var time: Dictionary = world.get("time", {})
	_check(int(time.get("day", 0)) == 3, "the save records the world day")
	var saved_quests: Dictionary = world.get("quests", {})
	_check(
		saved_quests.has("active") and saved_quests.has("completed"),
		"the save records the quest log"
	)
	var saved_discoveries: Dictionary = world.get("discoveries", {})
	_check(
		saved_discoveries.has("unlocked"),
		"the save records the discovery log"
	)

	var entries: Dictionary = data.get("saveables", {})
	for id in [
		PLAYER_ID,
		&"chest.test_room.sword",
		&"chest.test_room.potion",
		&"chest.test_room.armor",
		&"door.test_room.main",
		&"enemy.test_room.grunt",
	]:
		_check(entries.has(String(id)), "the save contains %s" % id)

	var player_entry: Dictionary = entries.get(String(PLAYER_ID), {})
	_check(
		is_equal_approx(float(player_entry.get("health", 0.0)), 55.0),
		"the player entry records the current health"
	)

	_check(
		SaveManager.write_save_dict(TEST_SLOT, data),
		"the save writes to slot %d" % TEST_SLOT
	)
	_check(SaveManager.has_slot(TEST_SLOT), "the slot exists after writing")
	_check(
		not FileAccess.file_exists("user://saves/slot_%d/save.json.tmp" % TEST_SLOT),
		"the atomic write leaves no temp file behind"
	)

	var reread := SaveManager.read_slot(TEST_SLOT)
	_check(not reread.is_empty(), "the written save reads back")

	# --- disturb every piece of saved state
	_player.global_position = Vector3(0.0, 0.1, 7.0)
	_player.rotation.y = 0.0
	inventory.clear()
	equipment.load_data({"slots": []})
	health.set_health(100.0)
	stats.set_stamina(100.0)
	WorldClock.reset()
	QuestLog.reset()
	DiscoveryLog.reset()

	chest.set("is_open", false)
	lid.rotation.x = 0.0
	door.set("is_open", false)
	door.rotation.y = 0.0
	enemy.call("_apply_alive")
	enemy_health.set_health(40.0)

	# --- restore
	_check(SaveManager.apply_save(reread), "the save applies")
	_check(
		SaveManager.last_applied_count >= 6,
		"the save touches all six saveables (%d)" % SaveManager.last_applied_count
	)

	_check(
		_player.global_position.distance_to(Vector3(2.0, 0.2, 3.0)) < EPSILON,
		"the player position is restored (%.2f, %.2f, %.2f)" % [
			_player.global_position.x, _player.global_position.y, _player.global_position.z
		]
	)
	_check(
		is_equal_approx(_player.rotation.y, 0.5),
		"the player yaw is restored (%.3f)" % _player.rotation.y
	)
	_check(is_equal_approx(health.get_health(), 55.0), "the player health is restored")
	_check(is_equal_approx(stats.get_stamina(), 40.0), "the player stamina is restored")
	_check(
		inventory.get_amount(&"item.health_potion") == 3,
		"the potion stack is restored (%d)" % inventory.get_amount(&"item.health_potion")
	)
	_check(
		inventory.get_amount(&"item.iron_sword") == 1,
		"the spare sword is restored (%d)" % inventory.get_amount(&"item.iron_sword")
	)

	var weapon := equipment.get_weapon()
	_check(
		weapon != null and weapon.id == &"item.iron_sword",
		"the equipped sword is restored"
	)

	_check(bool(chest.get("is_open")), "the opened chest is restored")
	_check(
		is_equal_approx(lid.rotation.x, deg_to_rad(-105.0)),
		"the restored chest lid is open (%.3f rad)" % lid.rotation.x
	)
	_check(bool(door.get("is_open")), "the opened door is restored")
	_check(
		is_equal_approx(door.rotation.y, deg_to_rad(-100.0)),
		"the restored door is open (%.3f rad)" % door.rotation.y
	)
	_check(enemy.call("get_state_name") == &"DEAD", "the defeated enemy stays defeated")
	_check(WorldClock.get_day() == 3, "the world day is restored")
	_check(
		absf(WorldClock.get_hour() - 21.5) < EPSILON,
		"the world hour is restored (%.3f)" % WorldClock.get_hour()
	)
	_check(
		QuestLog.is_active(QuestLog.THATCH_HIVE),
		"the in-progress quest is restored"
	)
	_check(
		not QuestLog.is_active(QuestLog.ROWAN_LEDGER)
		and QuestLog.is_completed(QuestLog.ROWAN_LEDGER),
		"the completed quest is restored as completed"
	)
	_check(
		DiscoveryLog.has(DiscoveryLog.FUNGAL_RECORD),
		"the unlocked discovery is restored"
	)

	# A save that mentions an object this scene does not have is harmless.
	var with_unknown := reread.duplicate(true)
	with_unknown["saveables"]["unknown.thing"] = {"open": true}
	_check(SaveManager.apply_save(with_unknown), "a save with an unknown id still applies")
	_check(
		SaveManager.last_applied_count >= 6,
		"the unknown id is skipped (%d applied)" % SaveManager.last_applied_count
	)

	SaveManager.delete_slot(TEST_SLOT)
	# Leave the static logs clean for the checks that follow.
	QuestLog.reset()
	DiscoveryLog.reset()


# --- bad save files -------------------------------------------------------


func _check_storage_errors() -> void:
	var folder := "user://saves/slot_%d" % TEST_SLOT
	DirAccess.make_dir_recursive_absolute(folder)

	var file := FileAccess.open(folder + "/save.json", FileAccess.WRITE)
	_check(file != null, "a file can be written into the slot folder")
	if file != null:
		file.store_string("{ this is not json ")
		file.close()

	_check(SaveManager.read_slot(TEST_SLOT).is_empty(), "a corrupt save is rejected")
	_check(not SaveManager.get_last_error().is_empty(), "a rejected save explains why")

	_check(
		SaveManager.write_save_dict(TEST_SLOT, {"version": SaveManager.SAVE_VERSION + 1}),
		"a newer-format save can be written"
	)
	_check(
		SaveManager.read_slot(TEST_SLOT).is_empty(),
		"a save from a newer build is rejected"
	)

	_check(
		SaveManager.write_save_dict(TEST_SLOT, {
			"version": 0,
			"scene": "res://scenes/test_room.tscn",
			"world": {},
			"saveables": {},
		}),
		"a versionless save can be written"
	)
	_check(
		SaveManager.read_slot(TEST_SLOT).is_empty(),
		"a save without a version is rejected"
	)

	_check(SaveManager.delete_slot(TEST_SLOT), "the slot deletes")
	_check(not SaveManager.has_slot(TEST_SLOT), "a deleted slot is gone")


# --- chunk streaming ------------------------------------------------------


func _check_chunk_manager() -> void:
	var manager := ChunkManager.new()
	manager.chunk_directory = CHUNK_DIRECTORY
	manager.chunk_size = 10.0
	manager.load_radius = 0
	manager.update_interval = 0.05
	manager.auto_track_player = false

	var marker := Node3D.new()
	marker.name = "ChunkMarker"
	_room.add_child(marker)
	manager.set_track_node(marker)
	_room.add_child(manager)

	manager.refresh_now()
	var loaded := await _wait_for_chunk(manager, Vector2i(0, 0))
	_check(loaded, "chunk (0, 0) loads around the marker")
	_check(manager.is_chunk_loaded(Vector2i(0, 0)), "the manager reports chunk (0, 0) as loaded")
	_check(
		manager.get_loaded_chunk_count() == 1,
		"only the chunk under the marker is loaded (%d)" % manager.get_loaded_chunk_count()
	)
	_check(
		manager.find_child("Beacon", true, false) != null,
		"the loaded chunk scene is instantiated under the manager"
	)

	marker.position = Vector3(15.0, 0.0, 0.0)
	manager.refresh_now()
	loaded = await _wait_for_chunk(manager, Vector2i(1, 0))
	_check(loaded, "chunk (1, 0) loads after the marker moves")
	_check(manager.is_chunk_loaded(Vector2i(1, 0)), "the manager tracks the new chunk")
	_check(not manager.is_chunk_loaded(Vector2i(0, 0)), "the old chunk unloads")
	_check(
		manager.get_loaded_chunk_count() == 1,
		"exactly one chunk stays loaded (%d)" % manager.get_loaded_chunk_count()
	)

	marker.position = Vector3(999.0, 0.0, 999.0)
	manager.refresh_now()
	await _frames(5)
	_check(
		manager.get_loaded_chunk_count() == 0,
		"moving to an empty area unloads everything (%d)" % manager.get_loaded_chunk_count()
	)

	manager.unload_all()
	_check(manager.get_loaded_chunk_count() == 0, "unload_all() empties the manager")


func _wait_for_chunk(manager: ChunkManager, coord: Vector2i) -> bool:
	for _i in 120:
		if manager.is_chunk_loaded(coord):
			return true
		manager.refresh_now()
		await get_tree().process_frame
	return false


## The first streaming content is the shipped fixture set. The real world is no
## longer chunked: `scenes/town.tscn` grows its surroundings from a `TownRealm`
## node, so only the manager's own maths is checked here.
func _check_chunk_origins() -> void:
	var offset := ChunkManager.new()
	offset.chunk_size = CHUNK_SIZE
	offset.chunk_origin = Vector2i(-1, -4)
	offset.auto_track_player = false
	_check(
		offset.chunk_to_world(Vector2i(0, 0)).distance_to(Vector3(-32, 0, -128)) < EPSILON,
		"chunk_origin places a chunk set in world space"
	)
	_check(
		offset.world_to_chunk(Vector3(-32, 0, -128)) == Vector2i(0, 0),
		"world_to_chunk inverts chunk_to_world"
	)
	_check(
		offset.chunk_to_world(Vector2i(1, 2)).distance_to(Vector3(0, 0, -64)) < EPSILON,
		"chunks keep one chunk_size spacing in both axes"
	)
	offset.free()

	var plains := ChunkManager.new()
	plains.chunk_size = CHUNK_SIZE
	plains.auto_track_player = false
	_check(
		plains.chunk_to_world(Vector2i(0, 0)).distance_to(Vector3(0, 0, 0)) < EPSILON,
		"a zero origin keeps the world origin at chunk (0, 0)"
	)
	_check(
		plains.chunk_to_world(Vector2i(-1, -1)).distance_to(Vector3(-32, 0, -32)) < EPSILON,
		"a chunk set reaches one chunk west and north of the origin"
	)
	plains.free()


# --- HUD and pause menu ---------------------------------------------------


func _check_hud_and_pause_menu() -> void:
	_hud = _room.get_node_or_null("HUD") as CanvasLayer
	_pause = _room.get_node_or_null("PauseMenu") as CanvasLayer
	_check(_hud != null, "the room has a HUD")
	_check(_pause != null, "the room has a pause menu")

	if _hud != null:
		var time_label := _hud.find_child("TimeLabel", true, false) as Label
		_check(time_label != null, "the HUD has a clock label")
		if time_label != null:
			_hud.call("_refresh_clock")
			_check(
				time_label.text == WorldClock.get_time_string(),
				"the HUD clock matches the world clock (%s)" % time_label.text
			)

	if _pause != null:
		_check(
			_pause.find_child("SaveButton", true, false) is Button,
			"the pause menu has a Save Game button"
		)
		_check(
			_pause.find_child("LoadButton", true, false) is Button,
			"the pause menu has a Load Game button"
		)
		_check(
			_pause.find_child("AutosaveButton", true, false) is Button,
			"the pause menu can load the autosave"
		)
		_check(
			_pause.find_child("StatusLabel", true, false) is Label,
			"the pause menu has a save status label"
		)
		var slots := _pause.find_child("SlotOption", true, false) as OptionButton
		_check(slots != null, "the pause menu has a slot picker")
		if slots != null:
			_check(
				slots.item_count == Game.MANUAL_SLOTS.size(),
				"the slot picker lists every manual slot (%d)" % slots.item_count
			)
			_check(
				slots.get_item_id(0) == Game.MANUAL_SLOT,
				"the first picker row is the quicksave slot"
			)


# --- Game wiring ----------------------------------------------------------


func _check_game_save() -> void:
	Game.current_slot = TEST_SLOT
	_check(Game.save_game(TEST_SLOT), "Game.save_game(slot) writes the requested slot")
	_check(
		SaveManager.has_slot(TEST_SLOT),
		"the requested slot exists after Game.save_game()"
	)

	var data := SaveManager.read_slot(TEST_SLOT)
	_check(
		int(data.get("version", 0)) == SaveManager.SAVE_VERSION,
		"Game.save_game() writes a versioned save"
	)
	_check(
		String(data.get("scene", "")) == get_tree().current_scene.scene_file_path,
		"Game.save_game() records the running scene"
	)

	SaveManager.delete_slot(TEST_SLOT)
	Game.current_slot = 0


# --- autosave, quicksave, and the exterior scene ---------------------------


## Slots 0 and 1 are the real player's slots, so everything here is temporary
## and `_finish()` restores the raw files.
func _check_quick_save_and_autosave() -> void:
	_check(Game.state == Game.State.PLAYING, "the game is PLAYING before saving")
	SaveManager.delete_slot(Game.MANUAL_SLOT)
	SaveManager.delete_slot(Game.AUTOSAVE_SLOT)

	_check(Game.quick_save(), "quick_save() succeeds")
	_check(
		SaveManager.has_slot(Game.MANUAL_SLOT),
		"quick_save() writes the manual slot"
	)

	_check(Game.autosave(), "autosave() succeeds")
	_check(
		SaveManager.has_slot(Game.AUTOSAVE_SLOT),
		"autosave() writes the autosave slot"
	)

	# An autosave must never overwrite a deliberate save. Mark slot 0 with a
	# recognisable scene path, then autosave over it.
	SaveManager.write_save_dict(Game.MANUAL_SLOT, {
		"version": SaveManager.SAVE_VERSION,
		"saved_at": "2000-01-01T00:00:00",
		"scene": "res://manual.marker.tscn",
		"world": {},
		"saveables": {},
	})
	Game.autosave()
	var manual := SaveManager.read_slot(Game.MANUAL_SLOT)
	_check(
		String(manual.get("scene", "")) == "res://manual.marker.tscn",
		"autosave() leaves the manual save untouched"
	)

	# A quicksave must never write the autosave slot either.
	SaveManager.delete_slot(Game.AUTOSAVE_SLOT)
	Game.quick_save()
	_check(
		not SaveManager.has_slot(Game.AUTOSAVE_SLOT),
		"quick_save() leaves the autosave slot untouched"
	)

	# Autosave is a gameplay event, not a menu event.
	Game.set_state(Game.State.MAIN_MENU)
	_check(not Game.autosave(), "autosave() refuses to run outside PLAYING")
	Game.set_state(Game.State.PLAYING)

	SaveManager.delete_slot(Game.MANUAL_SLOT)
	SaveManager.delete_slot(Game.AUTOSAVE_SLOT)
	_check(not Game.quick_load(), "quick_load() reports failure when there is no save")
	_check(
		Game.state == Game.State.PLAYING,
		"a failed quick_load() leaves the game running in place"
	)


## The town is content, not a service, so this suite asserts its wiring through
## `PackedScene.get_state()`. Loading it here would pull a second player and HUD
## into the process and leave their resources alive at exit.
func _check_exterior_scene() -> void:
	_check(ResourceLoader.exists(TOWN_SCENE), "the town scene exists")

	var exit_gate := _room.get_node_or_null("ExitGate") as AreaGate
	_check(exit_gate != null, "the test room has an exit gate at the back door")
	if exit_gate == null:
		return

	_check(
		String(exit_gate.target_scene) == TOWN_SCENE,
		"the room's exit gate leads to the town"
	)
	_check(exit_gate.use_target_position, "the exit gate sets an arrival point")
	_check(
		exit_gate.target_position.distance_to(Vector3(-40, 0.2, -19)) < EPSILON,
		"the exit gate arrives outside the player's cottage"
	)

	_check_town_scene()


## Reads the town's saved scene state without instancing it.
func _check_town_scene() -> void:
	var packed := load(TOWN_SCENE) as PackedScene
	_check(packed != null, "the town scene loads")
	if packed == null:
		return

	var state := packed.get_state()
	_check(state.get_node_count() > 150, "the town scene holds its buildings and props")

	var player_index := _state_node(state, "Player")
	_check(player_index >= 0, "the town has a player")
	if player_index >= 0:
		var player_transform: Transform3D = _state_value(state, player_index, "transform")
		_check(
			player_transform.origin.distance_to(Vector3(-40, 0.2, -19)) < EPSILON,
			"the town starts the player outside their cottage"
		)
	_check(_state_node(state, "HUD") >= 0, "the town has the HUD")
	_check(_state_node(state, "PauseMenu") >= 0, "the town has the pause menu")
	_check(_state_node(state, "FallGuard") >= 0, "the town has a fall guard")
	_check(_state_node(state, "Ground") >= 0, "the town has walkable ground")

	var home_gate := _state_node(state, "Gates/HomeGate")
	_check(home_gate >= 0, "the cottage has a doorway back inside")
	_check(
		str(_state_value(state, home_gate, "target_scene")) == "res://scenes/test_room.tscn",
		"the cottage doorway leads to the interior"
	)
	var home_arrival: Vector3 = _state_value(state, home_gate, "target_position")
	_check(
		home_arrival.distance_to(Vector3(0, 0.2, -8)) < EPSILON,
		"the cottage doorway arrives inside the room"
	)

	var north_gate := _state_node(state, "Gates/NorthGate")
	_check(north_gate < 0, "the town has no gate out to a separate overworld scene")
	_check(
		_state_node(state, "Realm") >= 0,
		"the town grows the wider world from a Realm node"
	)

	var buildings := _direct_children(state, "Buildings")
	_check(buildings.size() >= 40, "the town has a full street of buildings")
	for building_name in [
		"Chapel", "BellTower", "AuntieBellsBakery", "RowansHouse",
		"ToothkeepersHouse", "ThreadkeepersHouse", "HiveTower",
		"SeamstressCottage", "OldLoomTower", "HomeCottage",
	]:
		_check(buildings.has(building_name), "the town places %s" % building_name)

	var props := _direct_children(state, "Props")
	_check(_count_prefix(props, "Bridge") == 4, "the town has four river bridges")
	_check(_count_prefix(props, "Stall") >= 4, "the market square has stalls")
	_check(_count_prefix(props, "Headstone") >= 15, "the cemetery has headstones")
	_check(_count_prefix(props, "GardenBed") >= 6, "the communal garden has beds")

	var river := _state_node(state, "Water/SouthRiver")
	_check(river >= 0, "the river runs through the town")
	_check(bool(_state_value(state, river, "transparent")), "the river is translucent water")

	var forest := _state_node(state, "Forest")
	_check(forest >= 0, "the town is ringed by forest")
	var forest_count: int = _state_value(state, forest, "count")
	_check(forest_count >= 100, "the forest ring is dense")
	var clumps: PackedVector3Array = _state_value(state, forest, "clumps")
	_check(clumps.size() >= 10, "the forest reaches into the town edge")


func _state_node(state: SceneState, path: String) -> int:
	for i in state.get_node_count():
		if String(state.get_node_path(i)).trim_prefix("./") == path:
			return i
	return -1


func _state_value(state: SceneState, node_index: int, property_name: String) -> Variant:
	if node_index < 0:
		return null
	for i in state.get_node_property_count(node_index):
		if String(state.get_node_property_name(node_index, i)) == property_name:
			return state.get_node_property_value(node_index, i)
	return null


func _direct_children(state: SceneState, parent_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var prefix := "./" + parent_path + "/"
	for i in state.get_node_count():
		var path := String(state.get_node_path(i))
		if not path.begins_with(prefix):
			continue
		var rest := path.substr(prefix.length())
		if rest.contains("/"):
			continue
		found.append(rest)
	return found


func _count_prefix(names: PackedStringArray, prefix: String) -> int:
	var total := 0
	for name in names:
		if name.begins_with(prefix):
			total += 1
	return total


# --- helpers --------------------------------------------------------------


## The suite writes to slots 0 and 1 (quicksave and autosave). Keep the player's
## real files as raw text so they can be restored exactly, timestamps included.
func _backup_slots() -> void:
	for slot in [Game.MANUAL_SLOT, Game.AUTOSAVE_SLOT]:
		_slot_backup[slot] = _read_slot_text(int(slot))


func _restore_slots() -> void:
	for slot in _slot_backup.keys():
		_write_slot_text(int(slot), String(_slot_backup[slot]))


func _read_slot_text(slot: int) -> String:
	var path := _slot_file(slot)
	if not FileAccess.file_exists(path):
		return ""

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_slot_text(slot: int, text: String) -> void:
	if text.is_empty():
		SaveManager.delete_slot(slot)
		return

	DirAccess.make_dir_recursive_absolute("user://saves/slot_%d" % slot)
	var file := FileAccess.open(_slot_file(slot), FileAccess.WRITE)
	if file == null:
		push_error("Phase 3 test: could not restore slot %d" % slot)
		return
	file.store_string(text)
	file.close()


func _slot_file(slot: int) -> String:
	return "user://saves/slot_%d/save.json" % slot


func _item(id: StringName) -> ItemData:
	return ItemDatabase.get_item(id)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


## Chunk scenes load on worker threads. If the test quits while a load is still
## in flight, the `ResourceLoader` still holds the resource and Godot reports it
## as a leaked object at exit. Waiting briefly, then disabling and clearing every
## manager under the room, lets those loads finish and release their resources
## before the process ends. This is a test-teardown detail, not a gameplay fix.
func _drain_chunk_streaming() -> void:
	if _room == null or not is_instance_valid(_room):
		return
	var managers: Array[ChunkManager] = []
	for child in _room.find_children("*", "", true, false):
		if child is ChunkManager:
			managers.append(child as ChunkManager)
	if managers.is_empty():
		return
	# Give in-flight threaded loads time to finish and be polled.
	await get_tree().create_timer(0.8).timeout
	for manager in managers:
		if is_instance_valid(manager):
			manager.enabled = false
			manager.unload_all()
	# Let the unloads settle across a few frames.
	await _frames(6)


func _finish() -> void:
	await _drain_chunk_streaming()
	_restore_slots()
	if _failures.is_empty():
		print("PHASE3_SMOKE_OK")
		get_tree().quit(0)
	else:
		push_error("PHASE3_SMOKE_FAILED: " + ", ".join(_failures))
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures.append(message)
		push_error("  FAIL: " + message)
