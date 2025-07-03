# src/ui/main_menu.gd (Final Corrected Version)
extends Control

# Get references to your buttons.
@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

func _ready():
	new_game_button.pressed.connect(on_new_game_pressed)
	load_game_button.pressed.connect(on_load_game_pressed)
	exit_button.pressed.connect(get_tree().quit)
	
	# Check for any save file to enable the button. You can add more slots here.
	load_game_button.disabled = not SaveManager.save_file_exists(1)

func on_new_game_pressed():
	GameManager.set_next_game_state(true, 1)
	SceneLoader.change_scene("res://src/main.tscn") # Use the new loader

func on_load_game_pressed():
	GameManager.set_next_game_state(false, 1)
	SceneLoader.change_scene("res://src/main.tscn") # Use the new loader
