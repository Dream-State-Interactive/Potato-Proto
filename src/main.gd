# =============================================================================
# main.gd - The Persistent In-Game World and Level Manager
# =============================================================================
#
# WHAT IT IS:
# This script is attached to the root node of your 'Main.tscn' scene. This scene
# acts as a persistent hub that stays loaded while the player is actively playing
# the game.
#
# ARCHITECTURE:
# - It holds the permanent UI elements (HUD, Pause Menu, etc.).
# - It contains an empty 'LevelContainer' node.
# - Its primary job is to load and unload individual level scenes (level_01.tscn,
#   level_02.tscn) as children of the 'LevelContainer'.
# - This pattern allows the UI to persist across level changes and cleanly
#   separates the "game world" from the "gameplay level".
#
# =============================================================================
extends Node

var FPS

# --- Node References ---
## A reference to the empty node that will hold our currently loaded level.
@onready var level_container = $LevelContainer

# --- Godot Functions ---
func _ready():
	# As soon as the main game scene is ready, it tells the GameManager.
	# The GameManager then checks if this is a "New Game" or a "Load Game"
	# and handles the data initialization accordingly.
	GameManager.on_game_scene_ready()
	SettingsService.initializeSettings()
	SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn")
	MenuManager.push_menu("res://src/ui/menus/home_menu.tscn")
