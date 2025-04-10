extends Node2D

@onready var masterVolumeSlider = $MasterVolumeSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	masterVolumeSlider.set_value_no_signal(SettingsService.getSettingValue("audio", "master_volume"))

func _on_h_slider_drag_ended(value_changed: bool) -> void:
	if(value_changed):
		var new_master_val = masterVolumeSlider.get_value()
		SettingsService.setSettingValue("audio", "master_volume", masterVolumeSlider.get_value())
		AudioService.set_master_volume(new_master_val)
