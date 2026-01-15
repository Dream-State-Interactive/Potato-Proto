# =============================================================================
# run_state.gd - Per-Run Game State
# =============================================================================
#
# WHAT IT IS:
# Holds all mutable state for the current game run: currency, collected items,
# player stats, and score. Resets when starting a new game.
#
# WHY IT EXISTS:
# Separates "what data exists for this run" from "how do we orchestrate
# game flow". GameManager handles flow; RunState holds data.
#
# =============================================================================
extends Node

# --- Constants ---
const DEFAULT_STATS = preload("res://src/player/default_potato_stats.tres")

# --- Run State Variables ---

## The player's current spendable currency.
var current_starch_points: int = 0:
	set(value):
		var old_value = current_starch_points
		current_starch_points = max(0, value)
		if value > old_value:
			total_starch_points += (value - old_value)
		SignalBus.starch_changed.emit(current_starch_points)

## Total starch collected this run (never decreases when spending).
var total_starch_points: int = 0

## Dictionary of collected item IDs for save/load persistence.
var collected_items: Dictionary = {}

## The "source of truth" StatBlock for the current game.
var player_stats: StatBlock = null

## Score from last player death (for leaderboard).
var last_player_score: int = 0

# --- Godot Functions ---

func _ready():
	player_stats = DEFAULT_STATS.duplicate(true)

# --- Public API ---

## Resets all run state for a new game.
func reset():
	collected_items.clear()
	current_starch_points = 0
	total_starch_points = 0
	last_player_score = 0
	player_stats = DEFAULT_STATS.duplicate(true)

## Adds starch points (from collectibles).
func add_starch_points(amount: int):
	current_starch_points += amount

## Spends starch points (from upgrades).
func spend_starch_points(amount: int):
	current_starch_points -= amount

## Registers a collected item by its unique ID.
func register_collected_item(id: String):
	if not id.is_empty():
		collected_items[id] = true

## Checks if an item has been collected this run.
func is_item_collected(id: String) -> bool:
	if id.is_empty():
		return false
	return collected_items.has(id)

## Upgrades a player stat by the given amount.
func upgrade_stat(stat_name: String, amount: float):
	if player_stats == null:
		push_error("RunState: Cannot upgrade stat - player_stats is null")
		return

	var current_value = player_stats.get(stat_name)
	player_stats.set(stat_name, current_value + amount)
	var new_value = player_stats.get(stat_name)
	print("Upgraded '%s' from %s to %s" % [stat_name, current_value, new_value])
	SignalBus.stat_upgraded.emit(stat_name)
