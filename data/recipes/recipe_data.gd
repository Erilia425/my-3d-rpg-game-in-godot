class_name RecipeData
extends Resource
## Definition of one crafting recipe.
##
## Ingredients are two parallel arrays rather than a Dictionary so the resource
## stays readable in the inspector and serialises cleanly to `.tres`. The 2D
## game only ever used one or two ingredients per recipe.

## Namespaced id, e.g. `recipe.sporebread`. Never rename once content exists.
@export var id: StringName = &""
@export var display_name: String = ""
@export var output_id: StringName = &""
@export var output_amount: int = 1
@export var ingredient_ids: Array[StringName] = []
@export var ingredient_amounts: Array[int] = []
## Optional tag alternative, one entry per ingredient. When an entry is set, any
## item carrying that tag satisfies the ingredient instead of a single item id
## (for example `wood`, so spruce and birch logs are interchangeable).
@export var ingredient_tags: Array[StringName] = []


## Human-readable requirement line, e.g. "2 Mushroom + 1 Flower".
func ingredient_summary() -> String:
	var parts: PackedStringArray = []
	for i in ingredient_ids.size():
		var amount := ingredient_amounts[i] if i < ingredient_amounts.size() else 1
		var tag := ingredient_tags[i] if i < ingredient_tags.size() else &""
		if not tag.is_empty():
			parts.append("%d any %s" % [amount, String(tag).capitalize()])
			continue
		var data := ItemDatabase.get_item(ingredient_ids[i])
		var label := data.display_name if data != null else String(ingredient_ids[i])
		parts.append("%d %s" % [amount, label])
	return " + ".join(parts)


## The tag that satisfies ingredient `index`, or an empty name when the recipe
## names one exact item.
func tag_for(index: int) -> StringName:
	if index < 0 or index >= ingredient_tags.size():
		return &""
	return ingredient_tags[index]
