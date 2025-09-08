# src/ui/pause_menu.gd
extends BaseMenu

@onready var button_container: VBoxContainer = $MarginContainer/ButtonContainer
@onready var resume_button: Button = $MarginContainer/ButtonContainer/ResumeButton
@onready var restart_button: Button = $MarginContainer/ButtonContainer/RestartButton
@onready var save_load_button: Button = $MarginContainer/ButtonContainer/SaveLoadButton
@onready var settings_button: Button = $MarginContainer/ButtonContainer/SettingsButton
@onready var menu_button: Button = $MarginContainer/ButtonContainer/MainMenuButton

func _ready():
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(MenuManager.resume)
	restart_button.pressed.connect(SceneLoader.reload_current_scene)
	
	await get_tree().process_frame
