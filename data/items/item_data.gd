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
	TOOL,
}

enum EquipSlot {
	NONE,
	MAIN_HAND,
	BODY,
	TOOL,
}

## Namespaced id, e.g. `item.iron_sword`. Never rename once content exists.
@export var id: StringName = &""
@export var display_name: String = ""
## Optional inventory artwork. Items without an icon still list by name only.
@export var icon: Texture2D = null
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
@export var restore_mana: float = 0.0
## Repairs torn silk. Silk is a containment cap, not a pool, so this is one of
## the few ways to mend it. See AGENTS.md and the Ledger notes.
@export var restore_silk: float = 0.0
## Adds anchor slots up to `StatsComponent.max_anchoring`. Teeth are the honest
## anchors; this field exists for the odd trinket that pretends to be one.
@export var grant_anchoring: int = 0


func is_equipment() -> bool:
	return equip_slot != EquipSlot.NONE


func is_consumable() -> bool:
	return kind == Kind.CONSUMABLE
