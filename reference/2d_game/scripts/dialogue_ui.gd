extends CanvasLayer

@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_text = $DialoguePanel/DialogueText

var dialogue_lines = []
var current_line = 0
var dialogue_active = false
var closing = false

func _ready():
	dialogue_panel.hide()

func start_dialogue(lines):
	if closing:
		return

	dialogue_lines = lines
	current_line = 0
	dialogue_active = true
	dialogue_text.text = dialogue_lines[current_line]
	dialogue_panel.show()

func _input(event):
	if not dialogue_active:
		return

	if event is InputEventKey:
		if event.is_action_pressed("interact") and event.pressed and not event.echo:

			if current_line == dialogue_lines.size() - 1:
				end_dialogue()
			else:
				current_line += 1
				dialogue_text.text = dialogue_lines[current_line]

			get_viewport().set_input_as_handled()

func end_dialogue():
	dialogue_active = false
	closing = true
	dialogue_panel.hide()

	await get_tree().create_timer(0.2).timeout

	closing = false
