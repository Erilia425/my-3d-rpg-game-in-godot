class_name MagicTeacher
extends QuestNpc
## A villager who teaches the rules of Hollow magic, one lesson per conversation.
##
## `MagicLessons` holds every curriculum; this class is the conversation in front
## of it. The Blind Seamstress was the first named teacher and teaches honey,
## silk, teeth, the Ledger and what she knows of Fern. Thatch teaches the hive's
## fuel, Corin Vale teaches that a tooth is a name, and Silas Graye teaches what
## the Ledger records. All of them are villagers first: a teacher keeps any quest
## their `QuestNpc` placement already had.
##
## Progress is stored as `QuestLog` flags (`teach.<teacher_id>.<n>`), so a
## curriculum is remembered across saves and both placements of the same person
## teach from one list. A teacher with lessons left wears a small floating marker
## so they can be found; a finished teacher repeats one line instead of going
## silent. See AGENTS.md section 4 and Shared_Lore/OPEN_QUESTIONS.md.

const DEFAULT_CURRICULUM := MagicLessons.DEFAULT_CURRICULUM
## The Seamstress curriculum, kept as a constant for callers that read it here.
const LESSONS: Array = MagicLessons.SEAMSTRESS_LESSONS
## Number of lessons in the Seamstress curriculum (the first one written).
const LESSON_COUNT := 5

## Which lesson list this teacher recites. Defaults to the Seamstress so a scene
## or test that sets only `teacher_id` still has a working curriculum.
@export var curriculum: StringName = MagicLessons.DEFAULT_CURRICULUM
## Save namespace for the lesson flags. Empty means "use the curriculum id", so
## two placements of the same teacher never hand out the same lesson twice.
@export var teacher_id: StringName = &""

var _lesson_marker: Label3D


func _ready() -> void:
	super()
	_build_lesson_marker()


func interact(interactor: Node) -> void:
	if interactor is Node3D:
		_face(interactor as Node3D)

	var inventory := _inventory_of(interactor)
	# Quest lines first: a fetch quest still starts, waits and turns in exactly
	# as it did before this class existed.
	var lines := _respond(inventory)

	var lesson := get_lesson_index()
	if lesson >= get_lesson_count():
		lines.append_array(MagicLessons.get_repeat_lines(get_curriculum()))
		Events.dialogue_requested.emit(npc_name, role, lines)
		return

	if _apply_lesson(lesson, interactor, inventory):
		lines.append_array(_lesson_lines(lesson))
		QuestLog.set_flag(_lesson_flag(lesson))
		_announce_curriculum_complete()
	else:
		# The only way a lesson refuses is a full bag on a gift lesson. Do not
		# mark it, so the player can come back and still receive it.
		lines.append("Not with that bag so full. Come back when you can carry it.")

	_refresh_lesson_marker()
	Events.dialogue_requested.emit(npc_name, role, lines)


# --- curriculum ------------------------------------------------------------


func get_curriculum() -> StringName:
	if not curriculum.is_empty():
		return curriculum
	return MagicLessons.DEFAULT_CURRICULUM


## The save namespace for this teacher's lesson flags.
func get_flag_id() -> StringName:
	if not teacher_id.is_empty():
		return teacher_id
	return get_curriculum()


func get_lesson_count() -> int:
	return MagicLessons.get_lesson_count(get_curriculum())


## How many lessons have been learned, in order. A gap stops the count so the
## curriculum can never skip ahead.
func get_lesson_index() -> int:
	return MagicLessons.get_taught(get_curriculum(), get_flag_id())


func has_taught_all() -> bool:
	return get_lesson_index() >= get_lesson_count()


func get_lesson_title(index: int) -> String:
	return MagicLessons.get_lesson_title(get_curriculum(), index)


func get_lesson_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for index in get_lesson_count():
		titles.append(get_lesson_title(index))
	return titles


func _lesson_lines(index: int) -> PackedStringArray:
	var lesson := MagicLessons.get_lesson(get_curriculum(), index)
	return PackedStringArray(lesson.get("lines", PackedStringArray()))


func _lesson_flag(index: int) -> StringName:
	return MagicLessons.flag(get_flag_id(), index)


## Applies a lesson's reward. Returns false only when a requested gift could not
## fit, in which case nothing is marked and the lesson can be heard again.
func _apply_lesson(index: int, interactor: Node, inventory: InventoryComponent) -> bool:
	var lesson := MagicLessons.get_lesson(get_curriculum(), index)
	if lesson.is_empty():
		return true

	var item_id: StringName = lesson.get("item", &"")
	if item_id != &"":
		if not _give(inventory, item_id, int(lesson.get("amount", 1))):
			return false

	var stats := _stats_of(interactor)
	if stats != null:
		var mended: float = float(lesson.get("silk", 0.0))
		if mended > 0.0:
			stats.repair_silk(mended)

		var anchors: int = int(lesson.get("anchors", 0))
		if anchors > 0:
			stats.grant_anchoring(anchors)

		var memory: float = float(lesson.get("memory", 0.0))
		if memory > 0.0:
			stats.restore_memory(memory)

	var calm: float = float(lesson.get("relieve", 0.0))
	if calm > 0.0:
		Ledger.relieve_imbalance(calm)

	return true


## The player owns the stats; the teacher asks for the component through the
## same public API the HUD uses.
func _stats_of(interactor: Node) -> StatsComponent:
	if interactor == null:
		return null
	if interactor.has_method("get_stats_component"):
		return interactor.call("get_stats_component") as StatsComponent
	return interactor.get_node_or_null("StatsComponent") as StatsComponent


# --- lesson marker ---------------------------------------------------------


## A small label above the name so an untaught villager reads as a teacher from
## across the square. It is a child of the villager, so a scheduled placement
## that hides itself hides the marker too.
func _build_lesson_marker() -> void:
	_lesson_marker = Label3D.new()
	_lesson_marker.name = "LessonMarker"
	var rise := 0.38 if hat_style != Npc.HatStyle.NONE else 0.0
	_lesson_marker.position = Vector3(0, (2.66 + rise) * model_scale, 0)
	_lesson_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lesson_marker.font_size = 26
	_lesson_marker.pixel_size = 0.003
	_lesson_marker.outline_size = 12
	_lesson_marker.outline_modulate = Color(0.09, 0.06, 0.04, 0.9)
	_lesson_marker.modulate = Color(1.0, 0.88, 0.55, 1)
	add_child(_lesson_marker)
	_refresh_lesson_marker()


func _refresh_lesson_marker() -> void:
	if _lesson_marker == null:
		return
	var remaining := get_lesson_count() - get_lesson_index()
	_lesson_marker.visible = remaining > 0
	if remaining <= 0:
		return
	_lesson_marker.text = "%d %s" % [
		remaining, "lesson" if remaining == 1 else "lessons"
	]


## The last lesson of a curriculum may leave one lore discovery behind. It is
## unlocked only after the flag is set, so a full bag cannot skip it.
func _announce_curriculum_complete() -> void:
	if not has_taught_all():
		return
	var discovery := MagicLessons.get_discovery(get_curriculum())
	if discovery.is_empty():
		return
	if DiscoveryLog.unlock(discovery):
		Events.notification_requested.emit(
			"Discovery: %s" % DiscoveryLog.get_title(discovery)
		)
