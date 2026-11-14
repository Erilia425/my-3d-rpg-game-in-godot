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
	&"item.hearth_silk_thread": preload("res://data/items/hearth_silk_thread.tres"),
	&"item.ledger_page": preload("res://data/items/ledger_page.tres"),
	&"item.ledger": preload("res://data/items/ledger.tres"),
	&"item.honey": preload("res://data/items/honey.tres"),
	&"item.memory_honey": preload("res://data/items/memory_honey.tres"),
	&"item.bakery_key": preload("res://data/items/bakery_key.tres"),
	&"item.axe": preload("res://data/items/axe.tres"),
	&"item.pickaxe": preload("res://data/items/pickaxe.tres"),
	&"item.wood": preload("res://data/items/wood.tres"),
	&"item.spruce_log": preload("res://data/items/spruce_log.tres"),
	&"item.birch_log": preload("res://data/items/birch_log.tres"),
	&"item.stone": preload("res://data/items/stone.tres"),
	&"item.iron_ore": preload("res://data/items/iron_ore.tres"),
	&"item.iron_dagger": preload("res://data/items/iron_dagger.tres"),
	&"item.gemstone": preload("res://data/items/gemstone.tres"),
	&"item.cabbage": preload("res://data/items/cabbage.tres"),
	&"item.spore_saffron": preload("res://data/items/spore_saffron.tres"),
	&"item.ghost_cap": preload("res://data/items/ghost_cap.tres"),
	&"item.mirror_thread": preload("res://data/items/mirror_thread.tres"),
	&"item.hollow_honey": preload("res://data/items/hollow_honey.tres"),
	&"item.seaglass": preload("res://data/items/seaglass.tres"),
	&"item.spider_coin": preload("res://data/items/spider_coin.tres"),
	&"item.moss_rock": preload("res://data/items/moss_rock.tres"),
	&"item.small_opal": preload("res://data/items/small_opal.tres"),
	&"item.faux_ivory_brooch": preload("res://data/items/faux_ivory_brooch.tres"),
	&"item.planting_mushroom": preload("res://data/items/planting_mushroom.tres"),
	&"item.dirt_sack": preload("res://data/items/dirt_sack.tres"),
	&"item.gnome_statue": preload("res://data/items/gnome_statue.tres"),
}


static func get_item(id: StringName) -> ItemData:
	return ITEMS.get(id) as ItemData


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)
