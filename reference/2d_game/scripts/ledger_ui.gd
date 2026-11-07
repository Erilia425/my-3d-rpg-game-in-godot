
extends CanvasLayer


# Find the nodes by name, even if they are nested differently.
@onready var ledger_panel: Panel = find_child("LedgerPanel", true, false) as Panel
@onready var heading: Label = find_child("Heading", true, false) as Label
@onready var entry_text: RichTextLabel = find_child("EntryText", true, false) as RichTextLabel
@onready var previous_button: Button = find_child("PreviousButton", true, false) as Button
@onready var next_button: Button = find_child("NextButton", true, false) as Button
@onready var close_button: Button = find_child("CloseButton", true, false) as Button


# Ledger data.
var entries: Array[String] = []
var current_entry: int = 0


func _ready() -> void:
	print("LEDGER UI SCRIPT IS RUNNING!")

	# Check that all required nodes were found.
	if ledger_panel == null:
		push_error("LedgerUI: Could not find LedgerPanel!")
		return

	if heading == null:
		push_error("LedgerUI: Could not find Heading!")
		return

	if entry_text == null:
		push_error("LedgerUI: Could not find EntryText!")
		return

	if previous_button == null:
		push_error("LedgerUI: Could not find PreviousButton!")
		return

	if next_button == null:
		push_error("LedgerUI: Could not find NextButton!")
		return

	if close_button == null:
		push_error("LedgerUI: Could not find CloseButton!")
		return

	# Hide the ledger when the game starts.
	ledger_panel.visible = false
	heading.visible = false
	entry_text.visible = false
	previous_button.visible = false
	next_button.visible = false
	close_button.visible = false

	# Connect the buttons.
	previous_button.pressed.connect(show_previous_entry)
	next_button.pressed.connect(show_next_entry)
	close_button.pressed.connect(close_ledger)

	# Load unlocked ledger entries.
	refresh_entries()


func _input(event: InputEvent) -> void:
	# Detect when J is pressed.
	if event is InputEventKey:
		if event.pressed and not event.echo and event.is_action_pressed("open_ledger"):
			print("J KEY PRESSED - LEDGER INPUT RECEIVED!")

			if ledger_panel.visible:
				close_ledger()
				print("Ledger closed!")
			else:
				open_ledger()
				print("Ledger opened!")


func refresh_entries() -> void:
	entries.clear()

	# Rowan's Ledger Page unlocks the first entry.
	if GlobalInventory.inventory.get("Ledger Page", 0) > 0:
		entries.append("rowan_record")

	# Auntie Bell's favor unlocks The Fungal Record.
	if GlobalInventory.has_discovery("fungal_record"):
		entries.append("fungal_record")

	# Keep the current entry within the available range.
	if current_entry >= entries.size():
		current_entry = maxi(0, entries.size() - 1)

	# Update the display if the ledger is already open.
	if ledger_panel.visible:
		if entries.is_empty():
			heading.text = "The Ledger"
			entry_text.text = "The pages are blank. Find a page or make a discovery."
			previous_button.disabled = true
			next_button.disabled = true
		else:
			display_current_entry()


func open_ledger() -> void:
	refresh_entries()

	# Show all ledger elements.
	ledger_panel.visible = true
	heading.visible = true
	entry_text.visible = true
	previous_button.visible = true
	next_button.visible = true
	close_button.visible = true

	if entries.is_empty():
		heading.text = "The Ledger"
		entry_text.text = "The pages are blank. Find a page or make a discovery."

		previous_button.disabled = true
		next_button.disabled = true
	else:
		current_entry = clampi(current_entry, 0, entries.size() - 1)
		display_current_entry()


func close_ledger() -> void:
	# Hide all ledger elements.
	ledger_panel.visible = false
	heading.visible = false
	entry_text.visible = false
	previous_button.visible = false
	next_button.visible = false
	close_button.visible = false


func display_current_entry() -> void:
	if entries.is_empty():
		return

	var entry_id: String = entries[current_entry]

	match entry_id:
		"rowan_record":
			heading.text = "Rowan's Ledger Page"
			entry_text.text = "The ledger holds more than names.\n\nSome exchanges cannot be undone."

		"fungal_record":
			heading.text = GlobalInventory.get_discovery_title("fungal_record")
			entry_text.text = GlobalInventory.get_discovery_description("fungal_record")

	# Update navigation buttons.
	previous_button.disabled = current_entry <= 0
	next_button.disabled = current_entry >= entries.size() - 1


func show_previous_entry() -> void:
	if current_entry > 0:
		current_entry -= 1
		display_current_entry()


func show_next_entry() -> void:
	if current_entry < entries.size() - 1:
		current_entry += 1
		display_current_entry()
