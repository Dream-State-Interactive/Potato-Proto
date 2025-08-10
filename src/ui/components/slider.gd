extends Node2D

@onready var slider = $Slider
@onready var description = get_meta("Description")
@onready var settingName = get_meta("SettingName")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var slider_value = SettingsService.getSettingValue(settingName)
	slider.set_value_no_signal(slider_value)

func _on_h_slider_drag_ended(value_changed: bool) -> void:
	if(value_changed):
		SettingsService.setSettingValue(settingName, slider.get_value())
