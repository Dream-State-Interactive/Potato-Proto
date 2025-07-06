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

# --- Exported Variables ---
## This allows you to choose which level scene (.tscn) will be loaded first
## when the game starts. You set this in the Inspector on the Main node.
@export var starting_level: PackedScene

# --- Node References ---
## A reference to the empty node that will hold our currently loaded level.
@onready var level_container = $LevelContainer

# --- Godot Functions ---
func _ready():
	# As soon as the main game scene is ready, it tells the GameManager.
	# The GameManager then checks if this is a "New Game" or a "Load Game"
	# and handles the data initialization accordingly.
	GameManager.on_game_scene_ready()

	# If a starting level has been assigned in the Inspector, load it.
	if starting_level:
		change_level(starting_level)
	else:
		print("ERROR: No starting level assigned to Main.tscn in the Inspector.")
		
func _process(delta: float):
	FPS = 1/delta
	$FPSLabel.text = str(FPS)

# --- Public API ---
## This function handles swapping between levels.
func change_level(level_scene: PackedScene):
	# --- 1. Clean up the old level ---
	# It's crucial to free the old level's nodes to prevent memory leaks.
	# This loop iterates through all children of the container and queues them
	# for safe deletion at the end of the frame.
	for child in level_container.get_children():
		child.queue_free()

	# --- 2. Instance and add the new level ---
	# We create a new instance from the provided scene file.
	var new_level = level_scene.instantiate()
	# We add the new level as a child of our container. It will now appear in the game.
	level_container.add_child(new_level)
