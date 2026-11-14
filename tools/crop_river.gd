extends SceneTree
## Throwaway: crops river art from the source sheet into standalone textures.


func _initialize() -> void:
	var source := "res://assets/from_2d/source/Mycelgrove Hollow River Assets Map.png"
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(source))
	if sheet == null:
		print("CROP_FAIL could not load ", source)
		quit(1)
		return

	var crops := {
		"river_water": Rect2i(58, 128, 90, 165),
		"dirt_bank": Rect2i(571, 902, 84, 74),
		"grassy_bank": Rect2i(443, 902, 84, 74),
		"water_ripple": Rect2i(296, 740, 76, 66),
		"wooden_bridge": Rect2i(30, 898, 116, 78),
		"stone_bridge": Rect2i(160, 898, 116, 78),
	}
	for key in crops:
		var region: Rect2i = crops[key]
		var out := sheet.get_region(region)
		var path := "res://assets/from_2d/sprites/%s.png" % key
		var err := out.save_png(ProjectSettings.globalize_path(path))
		print("CROP %s %s -> %s (%s)" % [key, str(region), path, error_string(err)])
	quit(0)
