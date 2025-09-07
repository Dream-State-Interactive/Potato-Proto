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
		var settingArray = LINKED_SETTING.split('.')
		var section = settingArray[0]
		var key = settingArray[1]
		SettingsService.setSettingValue(section, key, linkedSettingValues[linkedSettingValues.keys()[index]])
