class_name RecipeDatabase
extends RefCounted
## Lookup from recipe id to its `RecipeData` definition.
##
## Mirrors `ItemDatabase`: explicit preloads so a renamed file fails loudly.
## Add new recipes here as well as in `data/recipes/`.

const RECIPES: Dictionary = {
	&"recipe.sporebread": preload("res://data/recipes/sporebread.tres"),
	&"recipe.hearth_silk_thread": preload("res://data/recipes/hearth_silk_thread.tres"),
	&"recipe.memory_honey": preload("res://data/recipes/memory_honey.tres"),
	&"recipe.axe": preload("res://data/recipes/axe.tres"),
	&"recipe.pickaxe": preload("res://data/recipes/pickaxe.tres"),
	&"recipe.iron_sword": preload("res://data/recipes/iron_sword.tres"),
	&"recipe.iron_dagger": preload("res://data/recipes/iron_dagger.tres"),
}


static func get_recipe(id: StringName) -> RecipeData:
	return RECIPES.get(id) as RecipeData


static func all() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for recipe in RECIPES.values():
		out.append(recipe as RecipeData)
	return out
