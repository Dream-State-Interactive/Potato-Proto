# src/ui/pause_menu.gd
extends BaseMenu

@onready var button_container: VBoxContainer = $MarginContainer/ButtonContainer
@onready var resume_button: Button = $MarginContainer/ButtonContainer/ResumeButton
@onready var save_load_button: Button = $MarginContainer/ButtonContainer/SaveLoadButton
@onready var settings_button: Button = $MarginContainer/ButtonContainer/SettingsButton
@onready var menu_button: Button = $MarginContainer/ButtonContainer/MainMenuButton

func _ready():
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(resume_game)
	menu_button.pressed.connect(on_quit_pressed)
	
	await get_tree().process_frame


func resume_game():
	MenuManager.hide_current_menu() # Use the manager to hide self and clear stack
	GameManager.resume()
func on_quit_pressed():
	SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn") # Use the new loader
