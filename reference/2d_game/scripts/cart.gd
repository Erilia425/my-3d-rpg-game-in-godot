
extends StaticBody2D

@export var interact_range: float = 60.0

var player: Node2D = null
var was_interacting: bool = false
var storage: Dictionary = {}
var storage_open: bool = false

var storage_layer: CanvasLayer
var storage_panel: PanelContainer
var storage_list: VBoxContainer
var status_label: Label


func _ready():
	player = get_tree().get_root().find_child("player", true, false)
	create_storage_menu()


func _physics_process(_delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_root().find_child("player", true, false)

	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)
	var interacting = distance <= interact_range and Input.is_action_pressed("interact")

	if interacting and not was_interacting:
		if storage_open:
			close_storage()
		else:
			open_storage()

	was_interacting = interacting


func create_storage_menu():
	storage_layer = CanvasLayer.new()
	storage_layer.name = "CartStorageUI"
	add_child(storage_layer)

	storage_panel = PanelContainer.new()
	storage_panel.position = Vector2(250, 100)
	storage_panel.custom_minimum_size = Vector2(360, 300)
	storage_layer.add_child(storage_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	storage_panel.add_child(margin)

	var layout = VBoxContainer.new()
	margin.add_child(layout)

	var heading = Label.new()
	heading.text = "Hollow Cart Storage"
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)

	var instructions = Label.new()
	instructions.text = "Deposit or retrieve one item at a time."
	layout.add_child(instructions)

	var separator = HSeparator.new()
	layout.add_child(separator)

	storage_list = VBoxContainer.new()
	layout.add_child(storage_list)

	status_label = Label.new()
	status_label.text = "Your supplies are safe here."
	layout.add_child(status_label)

	var close_button = Button.new()
	close_button.text = "Close (E)"
	close_button.pressed.connect(close_storage)
	layout.add_child(close_button)

	storage_panel.visible = false


func open_storage():
	storage_open = true
	storage_panel.visible = true
	refresh_storage_menu()
	print("Hollow Cart: Storage opened.")


func close_storage():
	storage_open = false
	storage_panel.visible = false
	print("Hollow Cart: Storage closed.")


func refresh_storage_menu():
	for child in storage_list.get_children():
		child.queue_free()

	var items = ["Mushroom", "Flower", "Hearth-Silk"]

	for item in items:
		var row = HBoxContainer.new()
		storage_list.add_child(row)

		var inventory_count = int(GlobalInventory.inventory.get(item, 0))
		var stored_count = int(storage.get(item, 0))

		var item_label = Label.new()
		item_label.text = "%s  Bag: %d  Cart: %d" % [
			item, inventory_count, stored_count
		]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)

		var deposit_button = Button.new()
		deposit_button.text = "Deposit 1"
		deposit_button.pressed.connect(deposit_item.bind(item))
		row.add_child(deposit_button)

		var take_button = Button.new()
		take_button.text = "Take 1"
		take_button.pressed.connect(take_item.bind(item))
		row.add_child(take_button)


func deposit_item(item: String):
	var count = int(GlobalInventory.inventory.get(item, 0))

	if count <= 0:
		status_label.text = "You don't have any %s to deposit." % item
		return

	GlobalInventory.inventory[item] = count - 1
	storage[item] = int(storage.get(item, 0)) + 1

	status_label.text = "Deposited 1 %s." % item
	refresh_storage_menu()


func take_item(item: String):
	var count = int(storage.get(item, 0))

	if count <= 0:
		status_label.text = "There are no %s in the cart." % item
		return

	storage[item] = count - 1
	GlobalInventory.add_item(item)

	status_label.text = "Retrieved 1 %s." % item
	refresh_storage_menu()
