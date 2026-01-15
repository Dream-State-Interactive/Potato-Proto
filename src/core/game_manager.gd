# =============================================================================
# game_manager.gd - Game Flow Orchestrator
# =============================================================================
#
# WHAT IT IS:
# An Autoload Singleton responsible for game flow orchestration: starting new
# games, loading saves, managing scene transitions, and handling pause state.
#
# ARCHITECTURE:
# - Run state (starch, collected items, stats) lives in RunState singleton
# - Signals are defined in SignalBus singleton
# - Player instance is accessed via Godot's group system
# - This file handles game flow + backwards-compat proxies for existing code
#
# =============================================================================
extends Node

# =============================================================================
# --- BACKWARDS COMPATIBILITY: Signal Proxies ---
# These forward from SignalBus so existing code connecting to GameManager works.
# =============================================================================
signal scene_changed
signal player_health_updated(current, max)
signal starch_changed(new_amount)
signal stat_upgraded(stat_name)
signal player_is_ready(player_node)
signal ability1_equipped(ability_info: AbilityInfo)
signal ability2_equipped(ability_info: AbilityInfo)
signal ability1_state_updated(state: int, progress: float)
signal ability2_state_updated(state: int, progress: float)

# =============================================================================
# --- GAME FLOW STATE (owned by GameManager) ---
# =============================================================================

## Flag for indicating starting the Main Game (Menu & Stuff)
var _initial_boot: bool = true
## A flag set by the Main Menu to tell this manager how to handle the next scene load.
var next_scene_is_new_game: bool = true
## The save slot to use when loading a game.
var slot_to_load: int = 1
## Path to the level to load for new game.
var level_path_to_load: String = ""
## Current level path (used by SceneLoader).
var current_level_path: String = ""

# =============================================================================
# --- PAUSE MANAGEMENT (owned by GameManager) ---
# =============================================================================

var pause_requesters: int = 0

# =============================================================================
# --- BACKWARDS COMPATIBILITY: Property Proxies ---
# These delegate to RunState/groups so existing code still works.
# =============================================================================

## @deprecated Use RunState.current_starch_points instead
var current_starch_points: int:
	get: return RunState.current_starch_points
	set(value): RunState.current_starch_points = value

## @deprecated Use RunState.total_starch_points instead
var total_starch_points: int:
	get: return RunState.total_starch_points
	set(value): RunState.total_starch_points = value

## @deprecated Use RunState.player_stats instead
var player_stats: StatBlock:
	get: return RunState.player_stats
	set(value): RunState.player_stats = value

## @deprecated Use RunState.collected_items instead
var collected_items: Dictionary:
	get: return RunState.collected_items
	set(value): RunState.collected_items = value

## @deprecated Use RunState.last_player_score instead
var last_player_score: int:
	get: return RunState.last_player_score
	set(value): RunState.last_player_score = value

## @deprecated Use get_tree().get_first_node_in_group("player") instead
var player_instance:
	get: return get_tree().get_first_node_in_group("player")
	set(_value): push_warning("GameManager.player_instance is read-only. Player registers via group.")

## @deprecated Use RunState.DEFAULT_STATS instead
const DEFAULT_STATS = preload("res://src/player/default_potato_stats.tres")

# =============================================================================
# --- GODOT FUNCTIONS ---
# =============================================================================

func _ready():
	# Connect SignalBus signals to local proxies for backwards compatibility.
	# This allows code that connects to GameManager.signal_name to keep working.
	SignalBus.scene_changed.connect(func(): scene_changed.emit())
	SignalBus.player_health_updated.connect(func(c, m): player_health_updated.emit(c, m))
	SignalBus.starch_changed.connect(func(a): starch_changed.emit(a))
	SignalBus.stat_upgraded.connect(func(s): stat_upgraded.emit(s))
	SignalBus.player_is_ready.connect(func(p): player_is_ready.emit(p))
	SignalBus.ability1_equipped.connect(func(i): ability1_equipped.emit(i))
	SignalBus.ability2_equipped.connect(func(i): ability2_equipped.emit(i))
	SignalBus.ability1_state_updated.connect(func(s, p): ability1_state_updated.emit(s, p))
	SignalBus.ability2_state_updated.connect(func(s, p): ability2_state_updated.emit(s, p))

# =============================================================================
# --- PAUSE MANAGEMENT ---
# =============================================================================

func pause():
	pause_requesters += 1
	get_tree().paused = true
	GUI.show_pause_menu_backdrop()

func resume():
	if pause_requesters <= 0:
		return
	pause_requesters -= 1
	if pause_requesters == 0 and get_tree().paused:
		get_tree().paused = false
		GUI.hide_pause_menu_backdrop()

func quit():
	get_tree().quit()

# =============================================================================
# --- GAME FLOW METHODS ---
# =============================================================================

## This is called by the Main Menu before changing scenes to tell us what to do.
func set_next_game_state(is_new: bool, slot: int):
	next_scene_is_new_game = is_new
	slot_to_load = slot

## This is called by our safe SceneLoader BEFORE a scene change.
func prepare_for_scene_change():
	print("GameManager: Preparing for scene change.")
	SignalBus.scene_changed.emit()

## This is called by the main game scene (Main.tscn) when it becomes ready.
func on_game_scene_ready():
	print("GameManager: Game scene is ready. Checking game state.")
	if _initial_boot:
		_initial_boot = false
		SceneLoader.change_scene_with_transition("res://src/ui/menus/MainMenu.tscn")
		return
	if next_scene_is_new_game:
		reset_game_state()
		SceneLoader.change_scene_with_transition(level_path_to_load)
	else:
		load_game_after_player_ready()

## NEW GAME
func start_new_game_at_level(level_path: String):
	set_next_game_state(true, 1)
	level_path_to_load = level_path
	prepare_for_scene_change()
	SceneLoader.change_scene_with_transition(SceneLoader.MAIN_GAME_SCENE)

## LOAD GAME
func start_loaded_game(slot: int):
	set_next_game_state(false, slot)
	prepare_for_scene_change()
	SceneLoader.change_scene_with_transition(SceneLoader.MAIN_GAME_SCENE)

## This function ensures we don't try to load data into a player that doesn't exist yet.
func load_game_after_player_ready():
	var player = get_tree().get_first_node_in_group("player")
	while not is_instance_valid(player):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")

	SaveManager.load_game(slot_to_load)
	var scene_root = get_tree().current_scene
	var collectibles_in_scene = scene_root.find_children("*", "Collectible", true, false)
	for item in collectibles_in_scene:
		if item is Collectible and not item.unique_id.is_empty():
			if RunState.is_item_collected(item.unique_id):
				item.queue_free()

	player.apply_stats_from_resource()
	player.call_deferred("force_visual_update")

## This resets all persistent data for a "New Game".
func reset_game_state():
	print("Game state reset")
	RunState.reset()

	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return

	var level_generator = scene_root.find_child("LevelGenerator", true, false)
	if is_instance_valid(level_generator):
		level_generator.reset_and_generate_initial_segments()
	else:
		ProgressionManager.reset(0)

	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.stats = RunState.player_stats
		player.apply_stats_from_resource()

## This is called by the SceneLoader AFTER a new level has been instanced.
func on_level_loaded():
	print("GameManager: A level has finished loading. Checking state.")
	if current_level_path == "res://src/ui/menus/MainMenu.tscn":
		print("GameManager: Main Menu loaded. Waiting for user input.")
		return
	if next_scene_is_new_game:
		reset_game_state()
	else:
		print("GameManager: State is 'Load Game'. Initiating load sequence.")
		load_game_after_player_ready()

# =============================================================================
# --- PLAYER REGISTRATION ---
# =============================================================================

## Called by Player._ready() to wire up stats and signals.
func register_player(player, health_comp: CHealth):
	print("GameManager: Player has registered.")

	# Assign the source-of-truth stat block from RunState.
	player.stats = RunState.player_stats
	player.apply_stats_from_resource()

	# Wire up health component.
	health_comp.max_health = RunState.player_stats.max_health
	health_comp.current_health = RunState.player_stats.max_health
	health_comp.health_changed.connect(_on_player_health_updated)

	SignalBus.player_is_ready.emit(player)
	RunState.last_player_score = 0
	player.player_death.connect(_on_player_death)

func _on_player_health_updated(current: float, max_health: float):
	SignalBus.player_health_updated.emit(current, max_health)

func _on_player_death(score: int):
	RunState.last_player_score = score

# =============================================================================
# --- BACKWARDS COMPATIBILITY: Method Proxies ---
# =============================================================================

## @deprecated Use RunState.register_collected_item() instead
func register_collected_item(id: String):
	RunState.register_collected_item(id)

## @deprecated Use RunState.is_item_collected() instead
func is_item_collected(id: String) -> bool:
	return RunState.is_item_collected(id)

## @deprecated Use get_tree().get_first_node_in_group("player") != null instead
func is_player_active() -> bool:
	return get_tree().get_first_node_in_group("player") != null

## @deprecated Use RunState.add_starch_points() instead
func add_starch_points(amount: int):
	RunState.add_starch_points(amount)

## @deprecated Use RunState.spend_starch_points() instead
func spend_starch_points(amount: int):
	RunState.spend_starch_points(amount)

## @deprecated Use RunState.upgrade_stat() instead
func upgrade_stat(stat_name: String, amount: float):
	RunState.upgrade_stat(stat_name, amount)
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.apply_stats_from_resource()

## @deprecated These are now emitted directly to SignalBus from player.gd
func on_ability1_state_updated(state: int, progress: float):
	SignalBus.ability1_state_updated.emit(state, progress)

func on_ability2_state_updated(state: int, progress: float):
	SignalBus.ability2_state_updated.emit(state, progress)

## Needed by SaveManager during load - sets starch without triggering tracking logic
func set_starch_points(value: int):
	RunState.current_starch_points = value
