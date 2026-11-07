extends Node

var inventory = {
	"Mushroom": 0,
	"Flower": 0,
	"Hearth-Silk": 0
}

func add_item(item_name):
	if inventory.has(item_name):
		inventory[item_name] += 1
		print(item_name, " collected! Total: ", inventory[item_name])
