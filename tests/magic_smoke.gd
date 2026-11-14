extends Node
## Magic smoke test: the Ledger service, memory/silk/anchoring on the player,
## the memory-honey item and recipe, the HUD's Memory display, and one full
## Recall cast against a real memory stone.
##
## Loads the real player, HUD and memory-stone scenes into a bare test scene so
## the check does not depend on the town being rebuilt. Prints `MAGIC_SMOKE_OK`
## like the phase suites.

const HONEY := &"item.memory_honey"

var _failures := 0
var _fail_total := 0

var _player: PlayerController
var _hud: CanvasLayer
var _stone: MemoryStone
var _dialogue: Control


func _ready() -> void:
	await get_tree().process_frame

	_check_items()
	_check_ledger()
	await _build_scene()
	_check_stats()
	_check_hud()
	await _check_recall()
	await _check_anchor()
	await _check_teacher()
	await _check_other_teachers()
	await _check_ledger_guests()
	_check_persistence()

	print("MAGIC_CHECKS=%d FAILURES=%d" % [_fail_total, _failures])
	print("MAGIC_SMOKE_OK" if _failures == 0 else "MAGIC_SMOKE_FAILED")

	if _player != null:
		_player.queue_free()
	if _hud != null:
		_hud.queue_free()
	if _stone != null:
		_stone.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


# --- items and recipes -----------------------------------------------------


func _check_items() -> void:
	var item := ItemDatabase.get_item(HONEY)
	_check(item != null, "memory-honey is in the item database")
	if item != null:
		_check(item.icon != null, "memory-honey has an icon")
		_check(item.is_consumable(), "memory-honey is consumable")
		_check(item.restore_mana > 0.0, "memory-honey restores memory charge")
		_check(item.tags.has("memory"), "memory-honey carries the memory tag")
		_check(item.tags.has("honey"), "memory-honey is still honey")

	var recipe := RecipeDatabase.get_recipe(&"recipe.memory_honey")
	_check(recipe != null, "the memory-honey recipe exists")
	if recipe != null:
		_check(recipe.output_id == HONEY, "the recipe makes memory-honey")
		_check(recipe.ingredient_ids.has(&"item.honey"), "the recipe uses ordinary honey")
		_check(
			recipe.ingredient_ids.has(&"item.hearth_silk_thread"),
			"the recipe uses Hearth-Silk for containment"
		)

	var station := CraftingStation.new()
	_check(
		station.recipe_ids.has(&"recipe.memory_honey"),
		"the crafting bench offers memory-honey by default"
	)
	station.free()


# --- the Ledger service ----------------------------------------------------


func _check_ledger() -> void:
	Ledger.reset()
	_check(Ledger.get_imbalance() == 0.0, "the Ledger starts balanced")
	_check(Ledger.get_state_word() == "Balanced", "balanced is the starting word")

	Ledger.add_imbalance(25.0)
	_check(Ledger.get_state_word() == "Thin", "25 imbalance reads as Thin")
	Ledger.add_imbalance(40.0)
	_check(Ledger.get_state_word() == "Watched", "65 imbalance reads as Watched")
	Ledger.add_imbalance(100.0)
	_check(Ledger.get_imbalance() == Ledger.MAX_IMBALANCE, "imbalance tops out at the cap")

	Ledger.relieve_imbalance(5.0)
	_check(
		is_equal_approx(Ledger.get_imbalance(), Ledger.MAX_IMBALANCE - 5.0),
		"relieving imbalance lowers it"
	)

	Ledger.reset()
	Ledger.add_debt(&"debt.test", 2)
	_check(Ledger.has_debt(&"debt.test"), "a debt can be recorded")
	_check(Ledger.get_debt(&"debt.test") == 2, "a debt keeps its amount")
	_check(not Ledger.pay_debt(&"debt.test", 1), "a part payment leaves the debt open")
	_check(Ledger.pay_debt(&"debt.test", 1), "the final payment settles the debt")
	_check(not Ledger.has_debt(&"debt.test"), "a settled debt is removed")

	Ledger.set_imbalance(35.0)
	Ledger.add_debt(&"debt.roundtrip", 1)
	var saved := Ledger.save_data()
	Ledger.reset()
	Ledger.load_data(saved)
	_check(Ledger.get_imbalance() == 35.0, "the Ledger round-trips imbalance")
	_check(Ledger.has_debt(&"debt.roundtrip"), "the Ledger round-trips debts")
	_check(Ledger.get_state_word() == "Thin", "the round-trip keeps the word")

	# --- escalation: how loudly the record speaks ------------------------
	Ledger.reset()
	_check(Ledger.get_escalation() == 0, "a balanced Ledger has no escalation")
	_check(
		is_equal_approx(Ledger.get_escalation_scale(), 1.0),
		"a balanced Ledger changes nothing in the world"
	)
	_check(Ledger.get_escalation_line(0) == "", "a balanced Ledger says nothing")

	Ledger.set_imbalance(Ledger.THRESHOLD_THIN)
	_check(Ledger.get_escalation() == 1, "thin imbalance escalates once")
	_check(
		Ledger.get_escalation_scale() > 1.0,
		"a thin Ledger already hardens its answers"
	)
	_check(
		not Ledger.get_escalation_line(1).is_empty(),
		"a rising Ledger has something to say"
	)

	Ledger.set_imbalance(Ledger.THRESHOLD_WATCHED)
	_check(Ledger.get_escalation() == 2, "watched imbalance escalates twice")
	_check(
		Ledger.get_escalation_scale() > 1.0 + Ledger.ESCALATION_STEP,
		"each tier hardens further"
	)

	Ledger.set_imbalance(Ledger.MAX_IMBALANCE)
	_check(Ledger.get_escalation() == 3, "a full Ledger escalates fully")
	_check(
		is_equal_approx(Ledger.get_escalation_scale(), 1.0 + 3.0 * Ledger.ESCALATION_STEP),
		"the full Ledger scale is the sum of its tiers"
	)

	Ledger.reset()
	_check(Ledger.get_escalation() == 0, "relief walks the escalation back")

	Ledger.reset()


# --- scene ----------------------------------------------------------------


func _build_scene() -> void:
	Game.set_state(Game.State.PLAYING)

	_player = (load("res://features/player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	# No floor exists in a bare test scene; stop gravity so the cast stays in
	# range of the stone.
	_player.set_physics_process(false)
	_player.global_position = Vector3.ZERO

	_stone = (load("res://features/magic/memory_stone.tscn") as PackedScene).instantiate()
	_stone.memory_title = "The Nail Count"
	_stone.memory_text = "Nine nails, and a tenth in his boot."
	_stone.position = Vector3(0, 0, 3)
	add_child(_stone)

	_hud = (load("res://features/ui/hud.tscn") as PackedScene).instantiate()
	add_child(_hud)
	await get_tree().process_frame
	await get_tree().process_frame

	_dialogue = _hud.get_node_or_null("DialogueWindow") as Control


# --- stats ----------------------------------------------------------------


func _check_stats() -> void:
	var stats := _player.get_stats_component()
	_check(stats != null, "the player has a StatsComponent")

	stats.set_memory(50.0)
	_check(stats.get_memory() == 50.0, "memory and mana are the same pool")
	_check(stats.get_max_memory() == stats.get_max_mana(), "the memory cap matches")
	_check(stats.spend_memory(20.0), "memory can be spent")
	_check(is_equal_approx(stats.get_memory(), 30.0), "spending memory lowers it")

	stats.set_silk(40.0)
	_check(stats.get_silk() == 40.0, "silk can hold a value")
	_check(not stats.can_contain(50.0), "thin silk cannot contain a large spell")
	_check(stats.can_contain(30.0), "thin silk can contain a small spell")
	_check(is_equal_approx(stats.damage_silk(10.0), 10.0), "silk can be damaged")
	_check(is_equal_approx(stats.get_silk(), 30.0), "damaged silk is reduced")
	_check(is_equal_approx(stats.repair_silk(5.0), 5.0), "silk can be repaired")
	_check(is_equal_approx(stats.get_silk(), 35.0), "repaired silk rises")

	stats.set_anchoring(2)
	_check(stats.get_anchoring() == 2, "anchoring counts teeth")
	_check(stats.spend_anchoring(1), "a tooth can be spent")
	_check(stats.get_anchoring() == 1, "spending a tooth lowers the count")
	_check(not stats.spend_anchoring(2), "two teeth cannot be spent with one held")
	_check(stats.grant_anchoring(5) == 2, "anchoring fills the remaining slots")
	_check(stats.get_anchoring() == stats.get_max_anchoring(), "anchoring respects its cap")

	stats.set_memory(stats.get_max_memory())
	stats.set_silk(stats.get_max_silk())
	stats.set_anchoring(0)


# --- HUD ------------------------------------------------------------------


func _check_hud() -> void:
	var bar := _hud.get_node_or_null("%MemoryBar") as ProgressBar
	var label := _hud.get_node_or_null("%MemoryLabel") as Label
	var silk_label := _hud.get_node_or_null("%SilkLabel") as Label
	var anchor_label := _hud.get_node_or_null("%AnchorLabel") as Label
	var ledger_label := _hud.get_node_or_null("%LedgerLabel") as Label

	_check(bar != null, "the HUD has a MemoryBar")
	_check(label != null, "the HUD has a MemoryLabel")
	_check(silk_label != null, "the HUD has a silk symbol")
	_check(anchor_label != null, "the HUD has an anchor symbol")
	_check(ledger_label != null, "the HUD has a Ledger word")
	_check(_hud.get_node_or_null("%ManaBar") == null, "the old mana bar is gone")

	var stats := _player.get_stats_component()
	if bar == null or label == null or silk_label == null or anchor_label == null or ledger_label == null:
		return

	_check(bar.max_value == stats.get_max_memory(), "the memory bar uses the memory cap")

	stats.set_memory(45.0)
	_check(is_equal_approx(bar.value, 45.0), "the bar follows memory")
	_check(label.text.contains("45"), "the label names the current memory")

	stats.set_silk(60.0)
	_check(silk_label.text.contains("60"), "the silk symbol follows silk")

	stats.set_anchoring(2)
	_check(anchor_label.text.contains("2"), "the anchor symbol follows anchoring")

	Ledger.add_imbalance(70.0)
	_hud.call("_refresh_clock")
	_check(ledger_label.text.contains("Watched"), "the Ledger word follows imbalance")
	Ledger.reset()
	_hud.call("_refresh_clock")
	_check(ledger_label.text.contains("Balanced"), "the Ledger word returns to balanced")

	stats.set_silk(stats.get_max_silk())
	stats.set_anchoring(0)


# --- Recall ---------------------------------------------------------------


func _check_recall() -> void:
	var stats := _player.get_stats_component()
	var inventory := _player.get_inventory_component()
	var caster := _player.get_spell_caster()
	_check(caster != null, "the player has a SpellCaster")

	if caster == null:
		return

	_check(_stone.is_in_group(&"memory"), "the memory stone is a Recall target")
	_check(_stone.get_memory_title() == "The Nail Count", "the stone keeps its title")

	# --- contained cast ---------------------------------------------------
	Ledger.reset()
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))
	_player.add_item(ItemDatabase.get_item(HONEY), 2)
	stats.set_memory(stats.get_max_memory())
	stats.set_silk(stats.get_max_silk())
	var before := stats.get_memory()

	_check(caster.try_recall(_stone), "a prepared player casts Recall")
	_check(
		is_equal_approx(stats.get_memory(), before - SpellCaster.RECALL_MEMORY_COST),
		"Recall spends its memory cost"
	)
	_check(inventory.get_amount(HONEY) == 1, "Recall consumes one memory-honey")
	_check(Ledger.get_imbalance() == 0.0, "contained Recall leaves no imbalance")
	_check(_dialogue != null and _dialogue.visible, "Recall shows its memory")
	if _dialogue != null and _dialogue.visible:
		var speaker := _dialogue.get_node_or_null("%SpeakerLabel") as Label
		_check(speaker != null and speaker.text == "The Nail Count", "the memory keeps its title")
		_dialogue.call("close")

	# --- the stone's own E interaction ------------------------------------
	stats.set_memory(stats.get_max_memory())
	_stone.interact(_player)
	_check(_dialogue != null and _dialogue.visible, "pressing E on a stone also Recalls")
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- leaking cast -----------------------------------------------------
	stats.set_memory(stats.get_max_memory())
	stats.set_silk(5.0)
	# The first two casts spent the starting doses; add one back for the leak.
	_player.add_item(ItemDatabase.get_item(HONEY), 1)
	var honey_before := inventory.get_amount(HONEY)
	_check(caster.try_recall(_stone), "thin silk still casts Recall")
	_check(inventory.get_amount(HONEY) == honey_before - 1, "the leaking cast pays its dose")
	_check(
		Ledger.get_imbalance() == SpellCaster.RECALL_LEAK_IMBALANCE,
		"thin silk records imbalance"
	)
	if _dialogue != null and _dialogue.visible:
		var hint := _dialogue.get_node_or_null("%HintLabel") as Label
		_check(hint != null and hint.text.contains("/ 2"), "a leak adds the warning page")
		_dialogue.call("close")

	# --- refusals ---------------------------------------------------------
	stats.set_silk(stats.get_max_silk())
	stats.set_memory(5.0)
	var before_refusal := inventory.get_amount(HONEY)
	_check(not caster.try_recall(_stone), "Recall refuses without enough memory")
	_check(inventory.get_amount(HONEY) == before_refusal, "a refused cast eats no dose")

	stats.set_memory(stats.get_max_memory())
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))
	_check(not caster.try_recall(_stone), "Recall refuses without memory-honey")
	_check(Ledger.get_imbalance() == SpellCaster.RECALL_LEAK_IMBALANCE, "refusals leave the Ledger alone")

	Ledger.reset()
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))
	stats.set_memory(stats.get_max_memory())
	stats.set_silk(stats.get_max_silk())


# --- Anchor ---------------------------------------------------------------


## Anchor is the first spell that spends a tooth. It is only worth a tooth if it
## makes a cast the silk cannot hold safe, so the test drives a real thin-silk
## Recall through it rather than checking the numbers alone.
func _check_anchor() -> void:
	var stats := _player.get_stats_component()
	var inventory := _player.get_inventory_component()
	var caster := _player.get_spell_caster()
	var anchor_label := _hud.get_node_or_null("%AnchorLabel") as Label

	_check(InputMap.has_action(&"cast_anchor"), "T is bound to cast_anchor")
	_check(caster != null, "the player has a SpellCaster for Anchor")
	if caster == null:
		return

	stats.clear_anchor_guard()
	stats.set_silk(5.0)
	stats.set_memory(stats.get_max_memory())
	Ledger.reset()
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))

	# --- refusals ---------------------------------------------------------
	stats.set_anchoring(0)
	_check(not caster.try_anchor(), "Anchor refuses without a tooth")
	_check(not stats.is_anchored(), "a refused Anchor does not hold")

	stats.set_anchoring(SpellCaster.ANCHOR_TOOTH_COST)
	stats.set_memory(5.0)
	_check(not caster.try_anchor(), "Anchor refuses without enough memory")
	_check(
		stats.get_anchoring() == SpellCaster.ANCHOR_TOOTH_COST,
		"a refused Anchor spends no tooth"
	)

	# --- the anchor holds -------------------------------------------------
	stats.set_memory(stats.get_max_memory())
	var memory_before := stats.get_memory()
	_check(caster.try_anchor(), "a tooth and some memory start an Anchor")
	_check(stats.is_anchored(), "the anchor holds")
	_check(
		is_equal_approx(
			stats.get_memory(), memory_before - SpellCaster.ANCHOR_MEMORY_COST
		),
		"Anchor spends its memory cost"
	)
	_check(stats.get_anchoring() == 0, "Anchor spends a tooth")
	_check(
		stats.can_contain(SpellCaster.RECALL_SILK_REQUIRED),
		"an anchor contains a spell the silk cannot"
	)
	_check(
		anchor_label != null and anchor_label.text.contains("held"),
		"the HUD shows the anchor holding"
	)

	_check(not caster.try_anchor(), "a second Anchor is refused while one holds")
	_check(stats.get_anchoring() == 0, "the refused second Anchor spends no tooth")

	# --- a held anchor stops a leak --------------------------------------
	_player.add_item(ItemDatabase.get_item(HONEY), 1)
	stats.set_memory(stats.get_max_memory())
	_check(caster.try_recall(_stone), "Recall casts while anchored")
	_check(
		Ledger.get_imbalance() == 0.0,
		"a held anchor stops the thin-silk leak"
	)
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- the guard lapses -------------------------------------------------
	stats.clear_anchor_guard()
	_check(not stats.is_anchored(), "the anchor can be ended")
	_check(
		anchor_label != null and not anchor_label.text.contains("held"),
		"the HUD drops the held mark"
	)

	stats.hold_anchor(0.02)
	_check(stats.is_anchored(), "a short anchor holds to begin with")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not stats.is_anchored(), "an anchor lapses on its own")

	# Leave the player in a plain state for the teacher checks.
	Ledger.reset()
	stats.set_silk(stats.get_max_silk())
	stats.set_memory(stats.get_max_memory())
	stats.set_anchoring(0)
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))


# --- the named teacher ----------------------------------------------------


## The Blind Seamstress teaches the rules of magic one lesson per conversation.
## This drives a real `MagicTeacher` against the real player and HUD, because the
## lesson is only useful if it reaches the bag, the stats and the Ledger.
func _check_teacher() -> void:
	QuestLog.reset()
	DiscoveryLog.reset()
	var teacher := MagicTeacher.new()
	teacher.npc_name = "The Blind Seamstress"
	teacher.role = "Seamstress"
	teacher.teacher_id = &"test_teacher"
	add_child(teacher)
	teacher.set_physics_process(false)
	await get_tree().process_frame

	_check(teacher.get_lesson_index() == 0, "the teacher starts with no lessons given")
	_check(MagicTeacher.LESSON_COUNT == 5, "the curriculum has five lessons")
	_check(
		MagicTeacher.LESSON_COUNT
		== MagicLessons.get_lesson_count(&"seamstress"),
		"the curriculum count matches the shared registry"
	)
	_check(teacher.get_lesson_title(0) == "Honey moves", "the first lesson is about honey")

	var marker := teacher.get_node_or_null("LessonMarker") as Label3D
	_check(marker != null, "a teacher builds a lesson marker")
	_check(
		marker != null and marker.visible and marker.text.contains("5"),
		"a teacher with lessons left shows how many"
	)

	var inventory := _player.get_inventory_component()
	var stats := _player.get_stats_component()
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))

	# --- lesson one: honey moves -----------------------------------------
	teacher.interact(_player)
	_check(teacher.get_lesson_index() == 1, "the first conversation teaches one lesson")
	_check(inventory.get_amount(HONEY) == 2, "the first lesson hands over two doses")
	_check(
		marker != null and marker.text.contains("4"),
		"the lesson marker counts down"
	)
	_check(
		QuestLog.has_flag(&"teach.test_teacher.0"),
		"the lesson is remembered in the save"
	)
	if _dialogue != null and _dialogue.visible:
		var speaker := _dialogue.get_node_or_null("%SpeakerLabel") as Label
		_check(
			speaker != null and speaker.text == "The Blind Seamstress",
			"the teacher speaks through the dialogue window"
		)
		_dialogue.call("close")

	# --- lesson two: silk holds ------------------------------------------
	stats.set_silk(10.0)
	teacher.interact(_player)
	_check(teacher.get_lesson_index() == 2, "the second conversation teaches the next lesson")
	_check(is_equal_approx(stats.get_silk(), 40.0), "the silk lesson mends thirty")
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- lesson three: teeth anchor --------------------------------------
	stats.set_anchoring(0)
	teacher.interact(_player)
	_check(teacher.get_lesson_index() == 3, "the third conversation teaches the next lesson")
	_check(stats.get_anchoring() == 1, "the tooth lesson grants one anchor")
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- lesson four: the Ledger keeps the account -----------------------
	Ledger.set_imbalance(50.0)
	teacher.interact(_player)
	_check(teacher.get_lesson_index() == 4, "the fourth conversation teaches the next lesson")
	_check(
		is_equal_approx(Ledger.get_imbalance(), 40.0),
		"the Ledger lesson relieves ten imbalance"
	)
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- lesson five: what she knows of Fern -----------------------------
	teacher.interact(_player)
	_check(teacher.has_taught_all(), "the fifth conversation completes the curriculum")
	_check(
		marker != null and not marker.visible,
		"a finished teacher puts the marker away"
	)
	_check(
		DiscoveryLog.has(&"discovery.what_she_knows"),
		"the last lesson files what she knows"
	)
	_check(
		String(MagicTeacher.LESSONS[4]["lines"][2]).contains("Thistlewind"),
		"the last lesson keeps all of Fern's names canon"
	)
	_check(
		String(MagicTeacher.LESSONS[4]["lines"][4]).contains("First Child"),
		"the last lesson leaves the First Child open"
	)
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- a finished teacher still speaks --------------------------------
	teacher.interact(_player)
	_check(
		_dialogue != null and _dialogue.visible,
		"a finished teacher repeats a line instead of going silent"
	)
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- a full bag never loses the gift ---------------------------------
	var strict := MagicTeacher.new()
	strict.npc_name = "The Blind Seamstress"
	strict.teacher_id = &"test_full"
	add_child(strict)
	strict.set_physics_process(false)
	await get_tree().process_frame

	inventory.remove_item(HONEY, inventory.get_amount(HONEY))
	var capacity := inventory.capacity
	inventory.capacity = inventory.get_used_slots()
	_check(inventory.is_full(), "the test bag can be made full")
	strict.interact(_player)
	_check(strict.get_lesson_index() == 0, "a full bag does not mark the lesson taught")
	_check(inventory.get_amount(HONEY) == 0, "a full bag receives no gift")
	_check(
		not QuestLog.has_flag(&"teach.test_full.0"),
		"a refused lesson leaves its flag alone"
	)
	inventory.capacity = capacity

	strict.interact(_player)
	_check(strict.get_lesson_index() == 1, "the lesson can be collected once there is room")
	_check(inventory.get_amount(HONEY) == 2, "the retried gift arrives")

	# --- the curriculum survives a save ---------------------------------
	var blob := QuestLog.save_data()
	QuestLog.reset()
	_check(teacher.get_lesson_index() == 0, "reset clears the lessons")
	QuestLog.load_data(blob)
	_check(teacher.get_lesson_index() == 5, "the curriculum survives a save round-trip")

	teacher.queue_free()
	strict.queue_free()
	await get_tree().process_frame


## The other three named teachers. Each is driven once through the real player so
## the shared registry, the reward types and the per-teacher save flags are all
## exercised, not just the Seamstress's list.
func _check_other_teachers() -> void:
	QuestLog.reset()
	var stats := _player.get_stats_component()
	var inventory := _player.get_inventory_component()

	_check(MagicLessons.TEACHERS.size() == 4, "four named teachers hold curricula")
	_check(MagicLessons.get_total() == 14, "the curricula hold fourteen lessons")
	_check(
		MagicLessons.get_taught_total() == 0,
		"a fresh log has no lessons learned"
	)

	var broken := 0
	for id in MagicLessons.TEACHERS.keys():
		var curriculum := StringName(id)
		if MagicLessons.get_teacher_name(curriculum).is_empty():
			broken += 1
		if MagicLessons.get_repeat_lines(curriculum).is_empty():
			broken += 1
		for lesson in MagicLessons.get_lessons(curriculum):
			if String(lesson.get("title", "")).is_empty():
				broken += 1
			if PackedStringArray(lesson.get("lines", [])).is_empty():
				broken += 1
	_check(broken == 0, "every lesson has a teacher, a title, lines and a repeat")

	# --- Thatch: the hive feeds memory -----------------------------------
	var thatch := MagicTeacher.new()
	thatch.npc_name = "Thatch"
	thatch.role = "Beekeeper"
	thatch.curriculum = &"thatch"
	add_child(thatch)
	thatch.set_physics_process(false)
	await get_tree().process_frame

	_check(thatch.get_lesson_count() == 3, "Thatch teaches three lessons")
	stats.set_memory(0.0)
	thatch.interact(_player)
	_check(thatch.get_lesson_index() == 1, "Thatch teaches one lesson per conversation")
	_check(stats.get_memory() > 0.0, "the first hive lesson restores memory")
	_check(
		QuestLog.has_flag(&"teach.thatch.0"),
		"Thatch's lesson is saved under his own id"
	)
	if _dialogue != null and _dialogue.visible:
		_dialogue.call("close")

	# --- Corin Vale: a tooth is a name -----------------------------------
	var corin := MagicTeacher.new()
	corin.npc_name = "Corin Vale"
	corin.role = "Toothkeeper"
	corin.curriculum = &"corin"
	add_child(corin)
	corin.set_physics_process(false)
	await get_tree().process_frame

	stats.set_anchoring(0)
	corin.interact(_player)
	_check(corin.get_lesson_index() == 1, "Corin Vale teaches the tooth lesson")
	_check(stats.get_anchoring() == 1, "the first tooth lesson grants an anchor")

	# --- Silas Graye: the Ledger records ---------------------------------
	var silas := MagicTeacher.new()
	silas.npc_name = "Silas Graye"
	silas.role = "Debt Enforcer"
	silas.curriculum = &"silas"
	add_child(silas)
	silas.set_physics_process(false)
	await get_tree().process_frame

	Ledger.set_imbalance(30.0)
	silas.interact(_player)
	_check(silas.get_lesson_index() == 1, "Silas Graye teaches the Ledger lesson")
	_check(
		is_equal_approx(Ledger.get_imbalance(), 25.0),
		"the first Ledger lesson quiets five imbalance"
	)

	_check(
		MagicLessons.get_taught_total() == 3,
		"Field Notes counts every teacher's lessons"
	)
	_check(
		not MagicLessons.has_taught_everything(),
		"the record is not finished after three lessons"
	)

	thatch.queue_free()
	corin.queue_free()
	silas.queue_free()
	Ledger.reset()
	QuestLog.reset()
	inventory.remove_item(HONEY, inventory.get_amount(HONEY))
	await get_tree().process_frame


# --- the escalation reaches the Guests ------------------------------------


## The Ledger's escalation is only a consequence if something in the world reads
## it. A Guest reads it once, on arrival.
func _check_ledger_guests() -> void:
	Ledger.reset()
	var packed := load("res://features/combat/guest.tscn") as PackedScene
	_check(packed != null, "the Guest scene loads for the escalation check")
	if packed == null:
		return

	var calm := packed.instantiate() as Guest
	calm.set_physics_process(false)
	add_child(calm)
	await get_tree().process_frame
	var calm_health := calm.get_health_component().get_max_health()
	var calm_damage := calm.attack_damage
	_check(
		is_equal_approx(calm_health, 3.0),
		"a balanced Ledger leaves the Guest as it was"
	)

	Ledger.set_imbalance(Ledger.THRESHOLD_WATCHED)
	var roused := packed.instantiate() as Guest
	roused.set_physics_process(false)
	add_child(roused)
	await get_tree().process_frame
	_check(
		roused.get_health_component().get_max_health() > calm_health,
		"a watched Ledger makes its Guests harder to put down"
	)
	_check(
		roused.attack_damage > calm_damage,
		"a watched Ledger makes its Guests hit harder"
	)
	_check(
		roused.detection_range > 9.0,
		"a watched Ledger makes its Guests notice you sooner"
	)

	# A fixed encounter can opt out, so authored difficulty cannot drift with
	# whatever the player has been doing to their record.
	var fixed := packed.instantiate() as Guest
	fixed.answers_the_ledger = false
	fixed.set_physics_process(false)
	add_child(fixed)
	await get_tree().process_frame
	_check(
		is_equal_approx(fixed.get_health_component().get_max_health(), calm_health),
		"a fixed Guest ignores the Ledger"
	)

	calm.queue_free()
	roused.queue_free()
	fixed.queue_free()
	Ledger.reset()
	await get_tree().process_frame


# --- persistence ----------------------------------------------------------


func _check_persistence() -> void:
	var stats := _player.get_stats_component()
	stats.set_silk(37.0)
	stats.set_anchoring(2)

	var saved := _player.save_data()
	stats.set_silk(stats.get_max_silk())
	stats.set_anchoring(0)
	_player.load_data(saved)
	_check(is_equal_approx(stats.get_silk(), 37.0), "silk survives a save round-trip")
	_check(stats.get_anchoring() == 2, "anchoring survives a save round-trip")

	Ledger.set_imbalance(33.0)
	var dict := SaveManager.build_save_dict()
	var world: Dictionary = dict.get("world", {})
	_check(world.has("ledger"), "a save carries the Ledger")
	if world.has("ledger"):
		Ledger.reset()
		Ledger.load_data(world["ledger"])
		_check(is_equal_approx(Ledger.get_imbalance(), 33.0), "the saved Ledger restores")

	Ledger.reset()


func _check(ok: bool, label_text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + label_text)
	if not ok:
		_failures += 1
	_fail_total += 1
