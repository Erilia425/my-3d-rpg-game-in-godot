extends Node
## Save/load service.
##
## Phase 0: slot checks and file locations only. The versioned save format,
## saveable collection, and migrations arrive in Phase 3.
## See AGENTS.md section 8.

const SAVE_ROOT := "user://saves"
const SAVE_VERSION := 1


func save_slot(slot: int) -> bool:
	push_warning("SaveManager.save_slot(): saving is planned for Phase 3.")
	return false


func load_slot(slot: int) -> bool:
	push_warning("SaveManager.load_slot(): loading is planned for Phase 3.")
	return false


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var absolute_path := ProjectSettings.globalize_path(path)
	return DirAccess.remove_absolute(absolute_path) == OK


func _slot_path(slot: int) -> String:
	return "%s/slot_%d/save.json" % [SAVE_ROOT, slot]
