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
## Emitted whenever the player's health changes. The HUD listens to this.
signal player_health_updated(current, max)
## Emitted whenever the starch point total changes. The HUD listens to this.
signal starch_changed(new_amount)

# --- Game State Variables ---
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
var hud_instance = null
var level_up_menu_instance = null
var pause_menu_instance = null
var save_load_menu_instance = null

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
	hud_instance = null
	level_up_menu_instance = null
	pause_menu_instance = null
	save_load_menu_instance = null

## This is called by the main game scene (Main.tscn) when it becomes ready.
func on_game_scene_ready():
	print("GameManager: Game scene is ready. Checking game state.")
	if next_scene_is_new_game:
		reset_game_state()
	else:
		load_game_after_player_ready()

## This function ensures we don't try to load data into a player that doesn't exist yet.
func load_game_after_player_ready():
	# We wait until both the Player and HUD have registered themselves.
	while not is_instance_valid(player_instance) or not is_instance_valid(hud_instance):
		await get_tree().process_frame # Wait one frame and check again.

	# Now that we know they exist, it's safe to load.
	SaveManager.load_game(slot_to_load)
	player_instance.apply_stats_from_resource()
	hud_instance.update_starch_label(current_starch_points) # Force a final UI refresh.

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
	
	if hud_instance:
		hud_instance.update_starch_label(current_starch_points)

# --- Registration Callbacks (Called by nodes from their _ready() functions) ---
func on_hud_ready(hud):
	print("GameManager: Received 'hud_ready' confirmation. Wiring UI.")
	hud_instance = hud
	# Now that we have a safe reference, we connect our signals to its methods.
	starch_changed.connect(hud_instance.update_starch_label)
	player_health_updated.connect(hud_instance.update_health_bar)
	# Immediately sync the UI with current data.
	hud_instance.update_starch_label(current_starch_points)
	if player_instance:
		hud_instance.connect_ability_signals(player_instance)
		hud_instance.update_health_bar(player_instance.health_component.current_health, player_instance.health_component.max_health)

func on_level_up_menu_ready(menu):
	level_up_menu_instance = menu

func on_pause_menu_ready(menu):
	pause_menu_instance = menu

func on_saveload_menu_ready(menu):
	save_load_menu_instance = menu
	
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

	# If the HUD is already ready, connect the player to it.
	if hud_instance:
		hud_instance.connect_ability_signals(player)
		hud_instance.update_health_bar(health_comp.current_health, health_comp.max_health)

# --- Game Logic Functions ---
func open_pause_menu():
	if pause_menu_instance: pause_menu_instance.open_menu()
func open_saveload_menu():
	if save_load_menu_instance: save_load_menu_instance.open_menu()
	
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
	else:
		print("Upgrade failed: Player or stats not found.")
