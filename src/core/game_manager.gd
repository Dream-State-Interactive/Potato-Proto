# =============================================================================
# game_manager.gd - The Global State and Event Hub
# =============================================================================
#
# WHAT IT IS:
# This is an Autoload Singleton. It exists once, globally, from the moment the
# game launches until it closes. It acts as the "brain" of the game, managing
# persistent data and allowing disconnected systems (like the Player and the UI)
# to communicate without needing direct references to each other.
#
# ARCHITECTURE:
# - It is a pure data and logic manager. It does NOT create scenes.
# - It holds the "source of truth" for player data (stats, currency).
# - It acts as a signal bus: other nodes emit signals, and the GameManager
#   connects those signals to the appropriate listeners.
# - It manages the high-level game state, such as whether the next scene load
#   is for a "New Game" or a "Load Game".
#
# =============================================================================
extends Node

# --- Global Signals ---
## Emitted whenever a scene is going to be changed
signal scene_changed
## Emitted whenever the player's health changes. The HUD listens to this.
signal player_health_updated(current, max)
## Emitted whenever the starch point total changes. The HUD listens to this.
signal starch_changed(new_amount)
## Emitted whenever stats are being upgraded via Level Up Menu
signal stat_upgraded(stat_name)
## Emitted whenever the player is registered
signal player_is_ready(player_node)
signal ability1_cooldown_updated(progress)
signal ability2_cooldown_updated(progress)


# --- Game State Variables ---
## Flag for indicating starting the Main Game (Menu & Stuff)
var _initial_boot: bool = true
## The player's current currency.
var current_starch_points: int = 0
## A flag set by the Main Menu to tell this manager how to handle the next scene load.
var next_scene_is_new_game: bool = true
## The save slot to use when loading a game.
var slot_to_load: int = 1

# --- Node References ---
# These variables hold references to the single, active instances of key nodes.
# They are set to `null` when a scene changes and are re-assigned by the
# nodes themselves when they become ready.
var player_instance = null
var player_stats: StatBlock = null # The "source of truth" StatBlock for the current game.
var level_path_to_load: String = ""

@export var game_paused: bool = false

# --- Constants ---
## Preloading the default stats resource ensures we always have a clean template
## to create new StatBlocks from for a "New Game".
const DEFAULT_STATS = preload("res://src/player/default_potato_stats.tres")

# --- Godot Functions ---
# _ready() on an Autoload runs ONCE when the game first launches.
func _ready():
	# We create a fresh duplicate of the default stats right at the start.
	# This becomes the initial 'player_stats' for the first new game.
	player_stats = DEFAULT_STATS.duplicate(true)

# --- Public API (Called from other scripts) ---

func pause():
	game_paused = true
	get_tree().paused = true
	
func resume():
	game_paused = false
	get_tree().paused = false
	
func quit():
	get_tree().quit()

## This is called by the Main Menu before changing scenes to tell us what to do.
func set_next_game_state(is_new: bool, slot: int):
	next_scene_is_new_game = is_new
	slot_to_load = slot

## This is called by our safe SceneLoader BEFORE a scene change.
func prepare_for_scene_change():
	# This is a critical step to prevent "previously freed" crashes.
	# We clear all references to nodes from the old scene that is about to be destroyed.
	print("GameManager: Clearing all node references before scene change.")
	player_instance = null
	scene_changed.emit()

## This is called by the main game scene (Main.tscn) when it becomes ready.
func on_game_scene_ready():
	print("GameManager: Game scene is ready. Checking game state.")
	if _initial_boot:
		_initial_boot = false
		# On the first boot, always show main menu.
		SceneLoader.change_scene("res://src/ui/menus/MainMenu.tscn")
		return 
	# Subsequent calls focus on actualy gameplay, not the Main Menu
	if next_scene_is_new_game:
		reset_game_state()
		SceneLoader.change_scene(level_path_to_load)
	else:
		load_game_after_player_ready()

	# Now we can safely execute our logic.
	if next_scene_is_new_game:
		reset_game_state()
		# --- THIS IS THE MISSING LINE ---
		# After resetting the state, we tell the now-existing Main node
		# to load the level whose path we stored earlier.
		SceneLoader.change_scene(level_path_to_load)
	else:
		# The load logic should also be here.
		load_game_after_player_ready()

## NEW GAME
func start_new_game_at_level(level_path: String):
	# 1. Set the flags for what to do AFTER Main.tscn loads.
	set_next_game_state(true, 1) # true = is a new game
	level_path_to_load = level_path
	
	# 2. Prepare for the scene change and load Main.tscn.
	prepare_for_scene_change()
	get_tree().change_scene_to_file(SceneLoader.MAIN_GAME_SCENE)

## LOAD GAME
func start_loaded_game(slot: int):
	set_next_game_state(false, slot) # false = is NOT a new game
	prepare_for_scene_change()
	SceneLoader.change_scene(SceneLoader.MAIN_GAME_SCENE)

## This function ensures we don't try to load data into a player that doesn't exist yet.
func load_game_after_player_ready():
	# We wait until both the Player and HUD have registered themselves.
	while not is_instance_valid(player_instance):
		await get_tree().process_frame # Wait one frame and check again.

	# Now that we know they exist, it's safe to load.
	SaveManager.load_game(slot_to_load)
	player_instance.apply_stats_from_resource()

## This resets all persistent data for a "New Game".
func reset_game_state():
	print("Game state is being reset for a new game.")
	current_starch_points = 0
	# We create a fresh, clean copy of the default stats. This prevents stats
	# from a previous game from "leaking" into the new one.
	player_stats = DEFAULT_STATS.duplicate(true)
	
	# If the player already exists (e.g., from reloading the scene),
	# we must force it to adopt this new, clean stat block.
	if is_instance_valid(player_instance):
		player_instance.stats = player_stats
		player_instance.apply_stats_from_resource()

# --- Registration Callbacks (Called by nodes from their _ready() functions) ---

func register_player(player, health_comp: CHealth):
	print("GameManager: Player has registered.")
	player_instance = player
	
	# The Player MUST use the GameManager's "source of truth" stat block.
	# This ensures consistency between saves, loads, and new games.
	player.stats = player_stats
	player.apply_stats_from_resource()

	# Wire up the health component signals.
	health_comp.max_health = player_stats.max_health
	health_comp.current_health = player_stats.max_health
	health_comp.health_changed.connect(on_player_health_updated)
	
	if player.ability1_slot.get_child_count() > 0:
		var ability1 = player.ability1_slot.get_child(0) as Ability
		ability1.cooldown_updated.connect(on_ability1_cooldown_updated)
			
	if player.ability2_slot.get_child_count() > 0:
		var ability2 = player.ability2_slot.get_child(0) as Ability
		ability2.cooldown_updated.connect(on_ability2_cooldown_updated)
	
	player_is_ready.emit(player)

# --- Game Logic Functions ---
## This is a "setter" function. It's the one safe way to change starch points.
func set_starch_points(amount: int):
	current_starch_points = amount
	# By emitting the signal here, we guarantee the UI always updates.
	starch_changed.emit(current_starch_points)

func add_starch_points(amount: int):
	# We call our own setter to ensure the signal is always emitted.
	set_starch_points(current_starch_points + amount)

func on_player_health_updated(current: float, max: float):
	# The GameManager acts as a middleman, re-broadcasting the signal to listeners.
	player_health_updated.emit(current, max)

func on_ability1_cooldown_updated(progress: float):
	ability1_cooldown_updated.emit(progress)

func on_ability2_cooldown_updated(progress: float):
	ability2_cooldown_updated.emit(progress)

func spend_starch_points(amount: int):
	current_starch_points -= amount
	starch_changed.emit(current_starch_points)

func upgrade_stat(stat_name: String, amount: float):
	if player_instance and player_stats:
		var current_value = player_stats.get(stat_name)
		player_stats.set(stat_name, current_value + amount)
		var new_value = player_stats.get(stat_name)
		print("Upgraded '%s' from %s to %s" % [stat_name, current_value, new_value])
		player_instance.apply_stats_from_resource()
		stat_upgraded.emit(stat_name)
	else:
		print("Upgrade failed: Player or stats not found.")
