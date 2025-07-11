# src/ui/pause_menu.gd
extends BaseMenu

@onready var resume_button: Button = $MarginContainer/VBoxContainer/ResumeButton
@onready var save_load_button: Button = $MarginContainer/VBoxContainer/SaveLoadButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var menu_button: Button = $MarginContainer/VBoxContainer/MainMenuButton

func _ready():
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(resume_game)
	save_load_button.pressed.connect(on_saveload_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	menu_button.pressed.connect(on_quit_pressed)
	
	await get_tree().process_frame
	GameManager.on_pause_menu_ready(self)

func _unhandled_input(event: InputEvent):
	# FIX: Guard against the action firing on both key press and release.
	if event.is_action_pressed("pause") and event.is_pressed():
		get_viewport().set_input_as_handled()
		
		# Instead of checking visibility, let the MenuManager decide.
		# If the current menu is this one, we resume. Otherwise, we open it.
		if MenuManager._current_menu_path == self.scene_file_path:
			resume_game()
		else:
			# If another menu (like settings) is open, we don't want the pause
			# key to do anything. We only open the pause menu if NO menu is open.
			if MenuManager._current_menu_path == "":
				MenuManager.replace_menu(self.scene_file_path)

func open_menu():
	show()
	get_tree().paused = true	

func resume_game():
	MenuManager.hide_all_menus() # Use the manager to hide self and clear stack
	get_tree().paused = false

func _exit_tree():
	MenuManager.unregister_menu(self)

func on_saveload_pressed():
	MenuManager.replace_menu("res://src/ui/menus/save_load_menu.tscn")

func on_settings_pressed():
	open_menu() # Make sure pause menu is visible
	await get_tree().process_frame
	MenuManager.replace_menu("res://src/ui/menus/settings_menu.tscn")

func on_quit_pressed():
	get_tree().paused = false
	SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn") # Use the new loader
