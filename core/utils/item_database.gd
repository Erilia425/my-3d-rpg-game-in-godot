class_name ItemDatabase
extends RefCounted
## Lookup from item id to its `ItemData` definition.
##
## A dictionary of preloaded resources rather than a directory scan: it is
## explicit, costs nothing at runtime, and fails loudly when a file is renamed.
## Add new items here as well as in `data/items/`.

const ITEMS: Dictionary = {
	&"item.iron_sword": preload("res://data/items/iron_sword.tres"),
	&"item.leather_armor": preload("res://data/items/leather_armor.tres"),
	&"item.health_potion": preload("res://data/items/health_potion.tres"),
	&"item.mushroom": preload("res://data/items/mushroom.tres"),
	&"item.flower": preload("res://data/items/flower.tres"),
	&"item.sporebread": preload("res://data/items/sporebread.tres"),
	&"item.hearth_silk": preload("res://data/items/hearth_silk.tres"),
	&"item.ledger_page": preload("res://data/items/ledger_page.tres"),
}


static func get_item(id: StringName) -> ItemData:
	return ITEMS.get(id) as ItemData


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)
