class_name ItemData
extends Resource
## Definition of one item type.
##
## A definition describes *what* an item is (name, kind, stats). How many the
## player owns lives in `InventoryComponent`. See AGENTS.md sections 4.5 and 4.6.

enum Kind {
	MISC,
	WEAPON,
	ARMOR,
	CONSUMABLE,
}

enum EquipSlot {
	NONE,
	MAIN_HAND,
	BODY,
}

## Namespaced id, e.g. `item.iron_sword`. Never rename once content exists.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MISC
@export var stack_size: int = 1
@export var value: int = 0
@export var tags: PackedStringArray = []

@export_group("Equipment")
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var damage: float = 0.0
@export var armor: float = 0.0

@export_group("Consumable")
@export var restore_health: float = 0.0
@export var restore_stamina: float = 0.0


func is_equipment() -> bool:
	return equip_slot != EquipSlot.NONE


func is_consumable() -> bool:
	return kind == Kind.CONSUMABLE
