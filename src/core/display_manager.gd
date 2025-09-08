extends Node

@onready var WINDOW = get_window()
@onready var VIEWPORT = get_viewport()

@export var display_mode: DisplayServer.WindowMode:
	set(mode):
		DisplayServer.window_set_mode(mode, 0)
		
		if(mode != DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_flag(DisplayServer.WindowFlags.WINDOW_FLAG_BORDERLESS, false, WINDOW.get_window_id())
	get:
		return DisplayServer.window_get_mode(0)
		
@export var display_resolution: Vector2i:
	set(display_resolution):
		WINDOW.size = display_resolution
	get():
		return WINDOW.size

func _ready() -> void:
	if(WINDOW == null):
		print("Error: Window not found")
	if(VIEWPORT == null):
		print("Error: Viewport not found")
	
	display_mode = SettingsService.getSettingValue("display", "display_mode")
	display_resolution = SettingsService.getSettingValue("display", "display_resolution")
