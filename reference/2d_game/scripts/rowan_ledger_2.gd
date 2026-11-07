
extends Area2D

var player = null
var ledger_panel = null
var ledger_open = false
var current_page = 0

var pages = [
	"""ROWAN'S LEDGER

Names. Exchanges. Debts.

The handwriting changes halfway through the page.

E — Continue""",

	"""ENTRY 47

Name: Thimble
Payment: Hearth-Silk
Debt: UNPAID

The name has been crossed out.

Someone has written underneath:

They were never supposed to be counted.

E — Close"""
]

func _ready():
	player = get_tree().get_root().find_child("player", true, false)
	ledger_panel = get_tree().get_root().find_child("LedgerPanel", true, false)

	print("Ledger player found: ", player != null)
	print("Ledger panel found: ", ledger_panel != null)

	if ledger_panel:
		ledger_panel.hide()

func _input(event):
	if player == null or ledger_panel == null:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("interact"):
		print("E key detected by ledger")

		var distance = global_position.distance_to(player.global_position)
		print("Distance from ledger: ", distance)

		if distance < 180:
			if not ledger_open:
				ledger_open = true
				current_page = 0
				ledger_panel.show()
				print("Ledger panel visible: ", ledger_panel.visible)
				ledger_panel.get_node("LedgerText").text = pages[current_page]

			elif current_page == 0:
				current_page = 1
				ledger_panel.get_node("LedgerText").text = pages[current_page]

			else:
				ledger_open = false
				current_page = 0
				ledger_panel.hide()
