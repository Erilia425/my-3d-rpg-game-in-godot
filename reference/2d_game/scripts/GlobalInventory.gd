
extends Node

var inventory: Dictionary = {
	"Mushroom": 0,
	"Flower": 0,
	"Hearth-Silk": 0,
	"Sporebread": 0,
	"Hearth-Silk Thread": 0,
	"Ledger Page": 0
}

var favors: Dictionary = {
	"deliver_sporebread": false
}

var favor_messages: Dictionary = {
	"deliver_sporebread": "Deliver Sporebread to Auntie Bell"
}

# Discoveries unlocked by completing favors or exploring.
var discoveries: Dictionary = {
	"fungal_record": false
}

var discovery_titles: Dictionary = {
	"fungal_record": "The Fungal Record"
}

var discovery_descriptions: Dictionary = {
	"fungal_record": "The fungi used to make Sporebread grow near something old beneath the woods. Auntie Bell's favor revealed the first clue."
}


func add_item(item_name: String) -> void:
	if inventory.has(item_name):
		inventory[item_name] += 1
		print(item_name, " collected! Total: ", inventory[item_name])
	else:
		print("Unknown inventory item: ", item_name)


func complete_favor(favor_id: String) -> bool:
	if favors.has(favor_id) and not favors[favor_id]:
		favors[favor_id] = true
		print("Favor completed: ", favor_messages[favor_id])
		return true

	return false


func unlock_discovery(discovery_id: String) -> bool:
	if not discoveries.has(discovery_id):
		print("Unknown discovery: ", discovery_id)
		return false

	if discoveries[discovery_id]:
		print("Discovery already unlocked: ", discovery_id)
		return false

	discoveries[discovery_id] = true

	print("NEW DISCOVERY: ", discovery_titles[discovery_id])
	print(discovery_descriptions[discovery_id])

	return true


func has_discovery(discovery_id: String) -> bool:
	return discoveries.get(discovery_id, false)


func get_unlocked_discoveries() -> Array[String]:
	var unlocked: Array[String] = []

	for discovery_id in discoveries:
		if discoveries[discovery_id]:
			unlocked.append(discovery_id)

	return unlocked


func get_discovery_title(discovery_id: String) -> String:
	return discovery_titles.get(discovery_id, "Unknown Discovery")


func get_discovery_description(discovery_id: String) -> String:
	return discovery_descriptions.get(discovery_id, "")
