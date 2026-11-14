class_name MagicLessons
extends RefCounted
## Every named teacher's curriculum, and the progress helpers that read it.
##
## A static service like `QuestLog` and `Ledger`: the project keeps its six
## approved autoloads, so curricula are constants and progress lives in
## `QuestLog` flags. The flag format is unchanged from the first teacher pass:
## `teach.<teacher_id>.<n>`, where `teacher_id` is a stable save namespace.
##
## Lesson order is technique first, story second, in every curriculum:
##
## - **seamstress** — honey, silk, teeth, the Ledger, what she knows of Fern.
## - **thatch** — the hive's fuel, preparing honey, what the swarm remembers.
## - **corin** — a tooth is a name, do not improvise, what is filed stays filed.
## - **silas** — the Ledger records, debt is not evil, who keeps the account.
##
## A lesson may carry one reward: `item`/`amount` (a gift), `silk`, `anchors`,
## `memory`, or `relieve`. A gift lesson is never marked taught when the bag is
## full, so no reward can be lost. See AGENTS.md sections 4.6 and 15.

## Curriculum used when a teacher does not name one.
const DEFAULT_CURRICULUM := &"seamstress"

## The Blind Seamstress: the first named teacher. Canon already gives her these
## actions (stir honey clockwise, add a Threadkeeper's thread, ask for a tooth),
## so the lessons are technique, then the account, then what she suspects.
const SEAMSTRESS_LESSONS: Array = [
	{
		"title": "Honey moves",
		"lines": [
			"Magic in the Hollow is not a thing you hold. It is an exchange, and every exchange leaves a mark.",
			"Prepared honey carries a memory. Ordinary honey is only food. Do not confuse the two.",
			"Here. Two doses. Eat one before you cast, or the memory will have nothing to travel on.",
		],
		"item": &"item.memory_honey",
		"amount": 2,
	},
	{
		"title": "Silk holds",
		"lines": [
			"Memory is borrowed. Silk is what keeps it from leaking back into the wrong account.",
			"Thin silk still casts. It simply leaves a spill, and the Ledger is very good at noticing spills.",
			"Let me mend what the fog frayed. Stand still.",
		],
		"silk": 30.0,
	},
	{
		"title": "Teeth anchor",
		"lines": [
			"A tooth is an anchor, not coin. It holds an identity where it was put.",
			"Three anchors is what a person can carry without becoming a shelf. Here is one more.",
			"You do not spend a tooth on Recall. You spend it when something must stay itself.",
		],
		"anchors": 1,
	},
	{
		"title": "The Ledger keeps the account",
		"lines": [
			"The Ledger does not punish. It records. Balanced, Thin, Watched — those are its words for how loudly your debts are speaking.",
			"Every spell you cannot contain adds imbalance. Every debt left unpaid is a door left ajar.",
			"Twenty-seven years old, and the cottage already answers to you. It waited longer than that for someone.",
			"I have left one account open all my life. I do not recommend it, and I will not close it for you.",
		],
		"relieve": 10.0,
	},
	{
		"title": "What I know of Fern",
		"lines": [
			"The fog that took the lane when I was new here was not the Surge. They are two different hungers, and the Ledger has never learned to count either of them properly.",
			"Before your family came to the Hollow, a scout found a child under the old loom tower. The scout called them Thimble. I fed them silk so they would not unravel.",
			"Later the Ledger gave them a safer name, and then another, and another. Thimble. Fern. Thistlewind. Between. Patch. All of them are filed under the same open account.",
			"I know what Fern is not. I do not know what they are. Neither does the Ledger, whatever it claims.",
			"Perhaps the First Child was never only one child. That is the question I would ask, if I still asked questions.",
		],
	},
]

## Thatch, the beekeeper: the hive is where memory fuel comes from. He teaches
## the fuel, not the containment; silk and teeth belong to other teachers.
const THATCH_LESSONS: Array = [
	{
		"title": "The hive makes the fuel",
		"lines": [
			"Bees do not make magic. They make honey, and honey is what memory rides on. There is a difference, and it matters.",
			"Ordinary honey fills a belly. Prepared honey fills a memory. Bell stirs hers clockwise and adds a thread; I just keep the bees honest.",
			"Open your hands. The swarm owes the Hollow a favour, and I am paying it to you.",
		],
		"memory": 30.0,
	},
	{
		"title": "Honey must be prepared",
		"lines": [
			"Raw honey spoils a working. It has to be cut with Hearth-Silk before it will hold a memory steady.",
			"The bench by the market will do it. One ordinary honey, one thread. Do not skip the thread.",
			"Take two I prepared earlier. When they are gone, the recipe is yours.",
		],
		"item": &"item.memory_honey",
		"amount": 2,
	},
	{
		"title": "What the swarm remembers",
		"lines": [
			"A hive remembers a field for years after the flowers are gone. People call that instinct. The Ledger calls it an account.",
			"The bees were here before the first house and they will be here after the last one. They do not file anything, and nothing they do is ever lost.",
			"That is why the Threadkeepers leave me thread. Not for the honey. So the hive keeps answering.",
		],
		"silk": 20.0,
	},
]

## Corin Vale, the Toothkeeper: teeth are anchors and names, never currency.
const CORIN_LESSONS: Array = [
	{
		"title": "A tooth is a name",
		"lines": [
			"Every tooth is a name. Not a souvenir, not a fee. A name that agreed to stay where it was put.",
			"That is why we file them and do not spend them. A tooth in a pocket is a person arguing with themselves.",
			"Take one anchor. Keep it until something needs holding.",
		],
		"anchors": 1,
	},
	{
		"title": "Do not improvise",
		"lines": [
			"Ritual wants exactness. Say the words in the order they were given to you, or do not say them.",
			"An improvised anchor still anchors. It simply anchors the wrong thing, and then it is my desk that has to file the mess.",
			"Another tooth. Three is what a person can carry without becoming a shelf.",
		],
		"anchors": 1,
	},
	{
		"title": "What is filed stays filed",
		"lines": [
			"I do not decide what a name means. I decide where it is kept, and I keep it where it was put.",
			"There is one account in this square with more names than the person has faces. I have filed every one of them, and I have not been asked to choose.",
			"Take the third anchor. If you ever need a fourth, that is a conversation with the Ledger, not with me.",
		],
		"anchors": 1,
	},
]

## Silas Graye, the debt enforcer: the Ledger records, it does not punish.
const SILAS_LESSONS: Array = [
	{
		"title": "The Ledger records",
		"lines": [
			"The Ledger does not punish. It records. People hear that and think it is a comfort. It is not.",
			"Balanced, Thin, Watched. Those are not moods. They are how loudly an account is speaking.",
			"Here. I will quiet one small entry. Do not mistake that for forgiveness.",
		],
		"relieve": 5.0,
	},
	{
		"title": "Debt is not evil",
		"lines": [
			"Debt is not evil. Ignoring it is. A village runs on favours it has not paid yet.",
			"Every spell you cannot contain writes itself into the same book. Magic and money are the same shape here; only the ink differs.",
			"Another entry quieted. You are learning the shape of it.",
		],
		"relieve": 5.0,
	},
	{
		"title": "Who keeps the account",
		"lines": [
			"Nobody wrote the Ledger. It was already keeping accounts when the first house went up, and it will keep them after the last one comes down.",
			"A scout read it once, long before your family came, and wrote a line in the margin that the book has never accepted. The margin is still there. So is the line.",
			"I keep the village's entries straight. I do not keep the book, and I would not want to. Take this, and stop asking me to close your account for you.",
		],
		"relieve": 10.0,
	},
]

## Curricula by teacher id. `name` is the speaker, `repeat` is what a finished
## teacher still says, and `discovery` is unlocked when the curriculum ends.
const TEACHERS: Dictionary = {
	&"seamstress": {
		"name": "The Blind Seamstress",
		"lessons": SEAMSTRESS_LESSONS,
		"repeat": [
			"You have all I can teach, dear. The rest is yours to account for.",
			"Bring me thread if your coat needs mending. That is a different kind of lesson.",
		],
		"discovery": &"discovery.what_she_knows",
	},
	&"thatch": {
		"name": "Thatch",
		"lessons": THATCH_LESSONS,
		"repeat": [
			"The bees have told you everything I know. Mind the smoke, and mind the honey.",
		],
		"discovery": &"",
	},
	&"corin": {
		"name": "Corin Vale",
		"lessons": CORIN_LESSONS,
		"repeat": [
			"Nothing more to file. Keep what you carry, and do not improvise.",
		],
		"discovery": &"",
	},
	&"silas": {
		"name": "Silas Graye",
		"lessons": SILAS_LESSONS,
		"repeat": [
			"The account is open. It always is. Keep yours quiet and we will not need to speak again.",
		],
		"discovery": &"",
	},
}


## The entry for a curriculum, falling back to the Seamstress so an older scene
## or a test that names an unknown teacher still gets a working conversation.
static func get_entry(curriculum_id: StringName) -> Dictionary:
	var entry: Dictionary = TEACHERS.get(curriculum_id, TEACHERS[DEFAULT_CURRICULUM])
	return entry


static func has_curriculum(curriculum_id: StringName) -> bool:
	return TEACHERS.has(curriculum_id)


static func get_teacher_name(curriculum_id: StringName) -> String:
	return String(get_entry(curriculum_id).get("name", ""))


static func get_lessons(curriculum_id: StringName) -> Array:
	var lessons: Array = get_entry(curriculum_id).get(
		"lessons", SEAMSTRESS_LESSONS
	)
	return lessons


static func get_lesson_count(curriculum_id: StringName) -> int:
	return get_lessons(curriculum_id).size()


static func get_lesson(curriculum_id: StringName, index: int) -> Dictionary:
	var lessons := get_lessons(curriculum_id)
	if index < 0 or index >= lessons.size():
		return {}
	var lesson: Dictionary = lessons[index]
	return lesson


static func get_lesson_title(curriculum_id: StringName, index: int) -> String:
	return String(get_lesson(curriculum_id, index).get("title", ""))


static func get_repeat_lines(curriculum_id: StringName) -> PackedStringArray:
	return PackedStringArray(get_entry(curriculum_id).get("repeat", []))


## Discovery unlocked at the end of a curriculum. Empty means the teacher has
## no lore entry of their own.
static func get_discovery(curriculum_id: StringName) -> StringName:
	return StringName(get_entry(curriculum_id).get("discovery", &""))


## The save flag for one lesson. `flag_id` is the teacher's save namespace, which
## is normally the curriculum id but can differ when a scene overrides it.
static func flag(flag_id: StringName, index: int) -> StringName:
	return StringName("teach.%s.%d" % [flag_id, index])


## Lessons learned in order. A gap stops the count, so a curriculum can never
## skip ahead even if a flag is set out of sequence.
static func get_taught(curriculum_id: StringName, flag_id: StringName = &"") -> int:
	var flag_namespace := flag_id if not flag_id.is_empty() else curriculum_id
	var count := get_lesson_count(curriculum_id)
	var taught := 0
	while taught < count and QuestLog.has_flag(flag(flag_namespace, taught)):
		taught += 1
	return taught


static func has_taught_all(curriculum_id: StringName, flag_id: StringName = &"") -> bool:
	return get_taught(curriculum_id, flag_id) >= get_lesson_count(curriculum_id)


## Lessons learned across every named teacher. Field Notes reads this pair.
static func get_taught_total() -> int:
	var total := 0
	for id in TEACHERS.keys():
		total += get_taught(StringName(id))
	return total


static func get_total() -> int:
	var total := 0
	for id in TEACHERS.keys():
		total += get_lesson_count(StringName(id))
	return total


## True when every named teacher has finished their curriculum.
static func has_taught_everything() -> bool:
	return get_taught_total() >= get_total()
