
extends Camera2D

@export var third_person_zoom: Vector2 = Vector2.ONE
@export var first_person_zoom: Vector2 = Vector2(2.5, 2.5)
@export var transition_speed: float = 8.0

var first_person: bool = false

var fern: Node2D = null
var fern_sprite: Sprite2D = null
var overlay: CanvasLayer = null
var tint: ColorRect = null
var view_label: Label = null


func _ready() -> void:
	enabled = true
	zoom = third_person_zoom

	# Find the player safely.
	fern = get_parent() as Node2D

	if fern == null:
		push_error("Camera2D must be a direct child of the player node.")
		set_process(false)
		set_process_input(false)
		return

	# Find Fern's sprite.
	fern_sprite = fern.get_node_or_null("Sprite2D") as Sprite2D

	# Find the first-person overlay.
	overlay = fern.get_node_or_null("FirstPersonOverlay") as CanvasLayer

	if fern_sprite == null:
		push_error("Missing Sprite2D under player. Check the node name.")

	if overlay == null:
		push_error("Missing FirstPersonOverlay under player.")
		return

	tint = overlay.get_node_or_null("Tint") as ColorRect
	view_label = overlay.get_node_or_null("ViewLabel") as Label

	if tint == null:
		push_error("Missing Tint under FirstPersonOverlay.")
	else:
		tint.visible = false
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if view_label == null:
		push_error("Missing ViewLabel under FirstPersonOverlay.")
	else:
		view_label.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.is_action_pressed("toggle_view"):
			toggle_view()


func _process(delta: float) -> void:
	var target_zoom: Vector2 = third_person_zoom

	if first_person:
		target_zoom = first_person_zoom

	zoom = zoom.lerp(
		target_zoom,
		clampf(delta * transition_speed, 0.0, 1.0)
	)


func toggle_view() -> void:
	first_person = not first_person

	if is_instance_valid(fern_sprite):
		fern_sprite.visible = not first_person

	if is_instance_valid(tint):
		tint.visible = first_person

	if is_instance_valid(view_label):
		view_label.visible = first_person

	if first_person:
		print("First-person-style view enabled.")
	else:
		print("Third-person view enabled.")
