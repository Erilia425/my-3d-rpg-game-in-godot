extends Node
## Central event bus for facts that cross feature boundaries.
##
## Rules (see AGENTS.md section 6):
## - Signals are past tense.
## - Signals never return values.
## - Events announce facts; they are not requests for data.
## - Do not add an event until at least one producer and one consumer exist.

signal game_state_changed(previous_state: int, current_state: int)
signal setting_changed(key: StringName, value: Variant)
