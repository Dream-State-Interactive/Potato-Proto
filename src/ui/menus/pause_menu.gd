# src/ui/pause_menu.gd
extends CanvasLayer

@onready var resume_button: Button = $ColorRect/ResumeButton
@onready var save_load_button: Button = $ColorRect/SaveLoadButton
@onready var settings_button: Button = $ColorRect/SettingsButton
@onready var quit_button: Button = $ColorRect/MainMenuButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(hide_menu)
	save_load_button.pressed.connect(on_saveload_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	await get_tree().process_frame
	GameManager.on_pause_menu_ready(self)
	hide()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause") and event.pressed:
		if is_visible(): 
			hide_menu()
		else: 
			open_menu()
		get_viewport().set_input_as_handled()

func open_menu():
	show()
	get_tree().paused = true	

func hide_menu():
	hide()
	get_tree().paused = false

func on_saveload_pressed():
	hide()
	GameManager.open_saveload_menu()
	
func on_settings_pressed():
	print("Settings to be implemented")

func on_quit_pressed():
	get_tree().paused = false
	SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn") # Use the new loader
