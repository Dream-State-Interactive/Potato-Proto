# src/abilities/ability_icon.gd"
class_name AbilityIcon
extends PanelContainer

## Emitted when the mouse enters the icon's bounds, passing its data up.
signal hovered(resource: AbilityInfo)
## Emitted when the mouse leaves the icon's bounds.
signal unhovered

@onready var icon_visual: TextureRect = $IconVisual

var ability_info: AbilityInfo


## Sets the ability data for this icon and updates its texture.
func set_ability(resource: AbilityInfo):
	if resource:
		self.ability_info = resource
		icon_visual.texture = resource.icon


# This function is called by the engine when a drag is initiated on this control.
func _get_drag_data(_at_position: Vector2) -> Variant:
	# We pass the entire AbilityInfo as the data payload for the drag.
	# This gives the drop target all the info it needs.
	if not ability_info:
		return null

	# Create a preview for the drag operation (a copy of our icon).
	var preview = TextureRect.new()
	preview.texture = icon_visual.texture
	preview.size = self.size
	set_drag_preview(preview)
	
	# Return the data.
	return ability_info


# Called automatically when the mouse enters the control's rect.
func _on_mouse_entered():
	if ability_info:
		hovered.emit(ability_info)

# Called automatically when the mouse leaves the control's rect.
func _on_mouse_exited():
	unhovered.emit()
