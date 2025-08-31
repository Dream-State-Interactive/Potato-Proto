extends Node

var WINDOW

@export var display_mode: DisplayServer.WindowMode:
	set(mode):
		DisplayServer.window_set_mode(mode, 0)
		# This doesn't work rn
		if(mode != DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_flag(DisplayServer.WindowFlags.WINDOW_FLAG_BORDERLESS, false, WINDOW.get_window_id())
	get:
		return DisplayServer.window_get_mode(0)
		
@export var display_resolution: Vector2i:
	set(display_resolution):
		DisplayServer.window_set_size(display_resolution)
	get():
		return WINDOW.size

func _ready() -> void:
	WINDOW = get_window()
	if(WINDOW == null):
		print("Error: Window not found")
	
	display_mode = SettingsService.getSettingValue("display.display_mode")
	display_resolution = SettingsService.getSettingValue("display.display_resolution")
