# src/abilities/ability_slot.gd"

class_name AbilitySlot
extends PanelContainer # Q/E boxes type

## Emitted when a valid ability is dropped onto this slot.
signal ability_assigned(resource: AbilityInfo)
## Emitted when the mouse enters the slot's bounds.
signal hovered(resource: AbilityInfo)
## Emitted when the mouse leaves the slot's bounds.
signal unhovered

@onready var icon_display: TextureRect = $IconDisplay # IMPORTANT: Add a TextureRect named "IconDisplay" inside your Q/E boxes

var current_ability: AbilityInfo


# This function tells Godot if this control can accept the data being dragged.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# We only accept drops if the data is an AbilityInfo.
	return data is AbilityInfo

# This function is called when compatible data is dropped onto this control.
func _drop_data(_at_position: Vector2, data: Variant):
	var resource = data as AbilityInfo
	if resource:
		current_ability = resource
		icon_display.texture = resource.icon
		ability_assigned.emit(resource)
		# Also emit hover so the description updates instantly on drop.
		hovered.emit(resource)


func _on_mouse_entered():
	if current_ability:
		hovered.emit(current_ability)

func _on_mouse_exited():
	if current_ability:
		unhovered.emit()
