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
	save_load_button.pressed.connect(on_saveload_pressed)
	settings_button.pressed.connect(on_settings_pressed)
	menu_button.pressed.connect(on_quit_pressed)
	
	await get_tree().process_frame
	GameManager.on_pause_menu_ready(self)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause") and event.is_pressed():
		get_viewport().set_input_as_handled()

		if not visible:
			# If no other menus are open, show the pause menu.
			# Using `replace_menu` ensures the stack starts clean.
			MenuManager.replace_menu(scene_file_path)
		elif MenuManager._menu_stack.is_empty():
			# If the pause menu is visible and is the only thing in the stack, resume.
			resume_game()
		else:
			# If another menu is on top (e.g., settings), act as a back button.
			MenuManager.back()

func open_menu():
	super.open_menu() # Calls show() from BaseMenu
	GameManager.is_game_explicitly_paused = true
	get_tree().paused = true
	# Ensure buttons are visible when this menu becomes the active top-level menu.
	button_container.show()

func hide_menu():
	super.hide_menu() # Calls hide() from BaseMenu
	GameManager.is_game_explicitly_paused = false
	get_tree().paused = false
	# When the whole menu is hidden, ensure its containers are also hidden.
	button_container.hide()

func on_child_menu_opened():
	button_container.hide()

func resume_game():
	MenuManager.hide_all_menus() # Use the manager to hide self and clear stack
	get_tree().paused = false

func _exit_tree():
	MenuManager.unregister_menu(self)

func on_saveload_pressed():
	MenuManager.push_menu("res://src/ui/menus/save_load_menu.tscn")

func on_settings_pressed():
	MenuManager.push_menu("res://src/ui/menus/settings_menu.tscn")

func on_quit_pressed():
	get_tree().paused = false
	SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn") # Use the new loader
