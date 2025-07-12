# src/ui/main_menu.gd (Final Corrected Version)
extends CanvasLayer

@onready var button_container: VBoxContainer = $ButtonContainer
@onready var standard_button_play: Button = $ButtonContainer/StandardButtonPlay
@onready var standard_button_save_load: Button = $ButtonContainer/StandardButtonSaveLoad
@onready var standard_button_level_select: Button = $ButtonContainer/StandardButtonLevelSelect
@onready var standard_button_settings: Button = $ButtonContainer/StandardButtonSettings

# --- GODOT FUNCTIONS ---
func _ready():
	# hide submenus at start
	MenuManager.register_menu(self)
	#save_load_menu.visible  = false
	#settings_menu.visible   = false

func _exit_tree():
	# When this scene is being destroyed, it tells the manager to remove it.
	MenuManager.unregister_menu(self)
	
func open_menu():
	# show just the main-button container
	button_container.show()

func hide_menu():
	# hide just the main-button container
	button_container.hide()
	
# Increase the button scale slightly when the mouse enters.
func _on_button_mouse_entered(button: Button) -> void:
	button.scale = Vector2(1.1, 1.1)

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited(button: Button) -> void:
	button.scale = Vector2(1, 1)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func on_load_game_pressed():
	GameManager.set_next_game_state(false, 1)
	SceneLoader.change_scene("res://src/levels/level_proto/level_proto.tscn") # Use the new loader
