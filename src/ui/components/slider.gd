extends Slider

@onready var slider = $"."
@onready var description = get_meta("description")
@onready var settingName = get_meta("settingName")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#$MarginContainer/StandardButton.text = description

	var slider_value = SettingsService.getSettingValue(settingName)
	set_value_no_signal(slider_value)

func _on_drag_ended(value_changed: bool) -> void:
	if(value_changed):
		SettingsService.setSettingValue(settingName, get_value())
