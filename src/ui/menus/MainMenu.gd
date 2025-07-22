# src/ui/main_menu.gd (Final Corrected Version)
extends CanvasLayer

@onready var button_container: VBoxContainer = $ButtonContainer

# --- GODOT FUNCTIONS ---
# Increase the button scale slightly when the mouse enters.
func _on_button_mouse_entered(button: Button) -> void:
	button.scale = Vector2(1.1, 1.1)

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited(button: Button) -> void:
	button.scale = Vector2(1, 1)
	
func _ready() -> void:
	MenuManager.replace_menu("res://src/ui/menus/home_menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func on_load_game_pressed():
	GameManager.set_next_game_state(false, 1)
	SceneLoader.change_scene("res://src/levels/level_proto/level_proto.tscn") # Use the new loader
