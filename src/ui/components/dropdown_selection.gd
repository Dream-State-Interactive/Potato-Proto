extends OptionButton
class_name DropdownSelection

@onready var LINKED_SETTING = get_meta("linkedSettingName")

@export var linkedSettingValues: Dictionary:
	set(value):
		linkedSettingValues = value
		var i = 0
		for key in value.keys():
			add_item(key, i)
			i += 1
	get():
		return linkedSettingValues

func _on_item_selected(index: int) -> void:
	if(LINKED_SETTING):
		SettingsService.setSettingValue(LINKED_SETTING, linkedSettingValues[linkedSettingValues.keys()[index]])
