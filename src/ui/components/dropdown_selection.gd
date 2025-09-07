extends OptionButton
class_name DropdownSelection

@onready var LINKED_SETTING = get_meta("linkedSettingName")
var section
var key

@export var linkedSettingValues: Dictionary:
	set(value):
		linkedSettingValues = value
		var i = 0
		for key in value.keys():
			add_item(key, i)
			i += 1
	get():
		return linkedSettingValues
		
func _ready() -> void:
	if(LINKED_SETTING):
		var settingArray = LINKED_SETTING.split('.')
		section = settingArray[0]
		key = settingArray[1]
		var initialTextValue = linkedSettingValues.find_key(SettingsService.getSettingValue(section, key))
		text = initialTextValue
		selected = linkedSettingValues.keys().find(initialTextValue)

func _on_item_selected(index: int) -> void:
	if(section && key):
		SettingsService.setSettingValue(section, key, linkedSettingValues[linkedSettingValues.keys()[index]])
