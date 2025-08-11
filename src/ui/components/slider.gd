@tool
extends Slider

@onready var slider = $"."
@onready var button = $MarginContainer/StandardButton
@onready var settingName = get_meta("settingName")

# Cache the value so the Inspector shows/serializes it even if the child isn't ready yet.
var _button_text := "" as String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	 # Apply cached value when the node enters the tree (needed for editor + runtime).
	var btn := button as Button
	if btn:
		btn.text = _button_text

	var slider_value = SettingsService.getSettingValue(settingName)
	set_value_no_signal(slider_value)

@export var button_text: String:
	set(value):
		_button_text = value
		if is_inside_tree():
			var btn := button as Button
			if btn:
				btn.text = value
	get:
				return _button_text

func _on_drag_ended(value_changed: bool) -> void:
	if(value_changed):
		SettingsService.setSettingValue(settingName, get_value())
