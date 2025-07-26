# =============================================================================
# save_load_menu.gd - The Save and Load Game UI
# =============================================================================
#
# WHAT IT IS:
# This script controls a sub-menu for saving and loading the game. It is opened
# from the main Pause Menu.
#
# ARCHITECTURE:
# - Like other menus, it is a pause-immune CanvasLayer with its process_mode
#   set to 'Always'.
# - It communicates with the 'SaveManager' singleton to perform the actual
#   save/load operations.
# - It uses the 'SceneLoader' singleton to safely reload the game world after
#   loading data, which is a critical step to apply loaded states correctly.
#
# =============================================================================
extends BaseMenu

# --- Node References ---
@onready var save_button_1: Button = $MarginContainer/PanelContainer/VBoxContainer/HBoxContainer/SaveSlot1Button
@onready var load_button_1: Button = $MarginContainer/PanelContainer/VBoxContainer/HBoxContainer2/LoadSlot1Button
@onready var back_button: Button = $MarginContainer/PanelContainer/VBoxContainer/BackButton
# ... (add references for slots 2 and 3 here)

# --- Godot Functions ---
func _ready():
	super() # calls BaseMenu._ready(self)
	
	# Connect buttons to their respective functions.
	save_button_1.pressed.connect(on_save_pressed.bind(1))
	load_button_1.pressed.connect(on_load_pressed.bind(1))
	back_button.pressed.connect(MenuManager.back)
	

# --- Public & Internal Functions ---
## Called when a "Save" button is pressed.
func on_save_pressed(slot_number: int):
	SaveManager.save_game(slot_number)
	update_buttons() # Refresh the UI to show the new save file (e.g., change text to "Overwrite").

## Called when a "Load" button is pressed.
func on_load_pressed(slot_number: int):
	# 1. "Peek" at the save data first to find out where we need to go.
	var save_data = SaveManager.get_save_data(slot_number)
	if save_data.is_empty():
		print("ERROR: Could not read save file for slot %d" % slot_number)
		return

	# 2. Extract the level path from the save data.
	# get() calls won't crash even if the keys don't exist.
	var level_to_load = save_data.get("game_state", {}).get("current_level_path")
	if not level_to_load or level_to_load.is_empty():
		print("ERROR: Save file for slot %d has no valid level path." % slot_number)
		return

	# 3. Now that we have a valid destination, set the GameManager state.
	GameManager.set_next_game_state(false, slot_number)
	
	# 4. Unpause the game.
	get_tree().paused = false
	
	# 5. Tell the SceneLoader to go to the level from the save file.
	print("Loading level '%s' from save slot %d" % [level_to_load, slot_number])
	SceneLoader.change_scene(level_to_load)

## Updates button text and disabled states based on whether save files exist.
func update_buttons():
	var save_exists = SaveManager.save_file_exists(1)
	load_button_1.disabled = not save_exists
	save_button_1.text = "Overwrite Slot 1" if save_exists else "Save Game 1"
	# ... (add logic for slots 2 and 3 here)
