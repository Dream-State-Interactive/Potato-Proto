extends Node

@onready var WINDOW = get_window()
@onready var VIEWPORT = get_viewport()

var target_resolution: Vector2i = Vector2i(1920, 1080)

@export var display_mode: DisplayServer.WindowMode:
	set(mode):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, 0)
		WINDOW.size = target_resolution
		
		var final_mode = mode
		if(mode == DisplayServer.WINDOW_MODE_FULLSCREEN):
			final_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			
		DisplayServer.window_set_mode(final_mode, 0)
		
		if(final_mode == DisplayServer.WINDOW_MODE_WINDOWED):
			WINDOW.move_to_center()
	get:
		var mode = DisplayServer.window_get_mode(0)
		if(mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
			return DisplayServer.WINDOW_MODE_FULLSCREEN
		return mode
		
@export var display_resolution: Vector2i:
	set(display_resolution):
		target_resolution = display_resolution
		self.display_mode = self.display_mode
	get():
		return target_resolution

func _ready() -> void:
	if(WINDOW == null):
		print("Error: Window not found")
	if(VIEWPORT == null):
		print("Error: Viewport not found")
	
	display_resolution = SettingsService.getSettingValue("display", "display_resolution")
	display_mode = SettingsService.getSettingValue("display", "display_mode")
