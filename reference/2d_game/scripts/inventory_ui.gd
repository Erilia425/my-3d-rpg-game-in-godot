
extends CanvasLayer

@onready var inventory_panel = $InventoryPanel

@onready var mushroom_label = $InventoryPanel/ItemGrid/MushroomLabel
@onready var flower_label = $InventoryPanel/ItemGrid/FlowerLabel
@onready var hearth_silk_label = $InventoryPanel/ItemGrid/HearthSilkLabel
@onready var sporebread_label = $InventoryPanel/ItemGrid/SporebreadLabel
@onready var silk_thread_label = $InventoryPanel/ItemGrid/HearthSilkThreadLabel
@onready var ledger_page_label = get_node_or_null("InventoryPanel/ItemGrid/LedgerPageLabel")

@onready var crafting_panel = get_node_or_null("CraftingPanel")
@onready var sporebread_button = get_node_or_null("CraftingPanel/CraftingLayout/SporebreadButton")
@onready var silk_thread_button = get_node_or_null("CraftingPanel/CraftingLayout/SilkThreadButton")
@onready var crafting_message = get_node_or_null("CraftingPanel/CraftingLayout/CraftingMessage")

var inventory_open = false


func _ready():
	print("Inventory UI script is running!")
	print("Inventory UI node path: ", get_path())
	print("Inventory UI GlobalInventory instance ID: ", GlobalInventory.get_instance_id())

	inventory_panel.hide()

	if crafting_panel:
		crafting_panel.hide()

	if sporebread_button:
		sporebread_button.pressed.connect(craft_sporebread)

	if silk_thread_button:
		silk_thread_button.pressed.connect(craft_silk_thread)

	print("InventoryPanel children: ", inventory_panel.get_children())
	print("ItemGrid children: ", $InventoryPanel/ItemGrid.get_children())

	if ledger_page_label == null:
		print("ERROR: LedgerPageLabel was not found!")
	else:
		print("LedgerPageLabel found at: ", ledger_page_label.get_path())
		print("Initial Ledger Page count: ", GlobalInventory.inventory.get("Ledger Page", 0))


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("inventory"):
			inventory_open = not inventory_open
			inventory_panel.visible = inventory_open

			print("Inventory UI sees Ledger Page count: ", GlobalInventory.inventory.get("Ledger Page", -1))
			print("Inventory UI GlobalInventory instance ID: ", GlobalInventory.get_instance_id())

		elif event.is_action_pressed("crafting") and crafting_panel:
			crafting_panel.visible = not crafting_panel.visible

			if crafting_message:
				crafting_message.text = ""


func _process(_delta):
	mushroom_label.text = "Mushroom ×" + str(GlobalInventory.inventory["Mushroom"])
	flower_label.text = "Flower ×" + str(GlobalInventory.inventory["Flower"])
	hearth_silk_label.text = "Hearth-Silk ×" + str(GlobalInventory.inventory["Hearth-Silk"])
	sporebread_label.text = "Sporebread ×" + str(GlobalInventory.inventory["Sporebread"])
	silk_thread_label.text = "Hearth-Silk Thread ×" + str(GlobalInventory.inventory["Hearth-Silk Thread"])

	if ledger_page_label:
		var count = GlobalInventory.inventory.get("Ledger Page", 0)
		ledger_page_label.text = "Ledger Page ×" + str(count)

		# Temporary diagnostics: print only when the count changes.
		if not has_meta("last_ledger_count") or get_meta("last_ledger_count") != count:
			print("Ledger label text: ", ledger_page_label.text)
			print("Ledger count: ", count)
			set_meta("last_ledger_count", count)


func craft_sporebread():
	if GlobalInventory.inventory["Mushroom"] >= 2 and GlobalInventory.inventory["Flower"] >= 1:
		GlobalInventory.inventory["Mushroom"] -= 2
		GlobalInventory.inventory["Flower"] -= 1
		GlobalInventory.add_item("Sporebread")

		if crafting_message:
			crafting_message.text = "You crafted Sporebread!"
	else:
		if crafting_message:
			crafting_message.text = "Need 2 Mushrooms and 1 Flower."


func craft_silk_thread():
	if GlobalInventory.inventory["Hearth-Silk"] >= 1 and GlobalInventory.inventory["Flower"] >= 1:
		GlobalInventory.inventory["Hearth-Silk"] -= 1
		GlobalInventory.inventory["Flower"] -= 1
		GlobalInventory.add_item("Hearth-Silk Thread")

		if crafting_message:
			crafting_message.text = "You crafted Hearth-Silk Thread!"
	else:
		if crafting_message:
			crafting_message.text = "Need 1 Hearth-Silk and 1 Flower."
