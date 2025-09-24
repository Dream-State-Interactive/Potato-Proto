# src/modes/gauntlet/progression_manager.gd
extends Node

var master_seed: int = 0
var max_forward_index: int = 0
var current_level: int = 1 # This now represents the player's PEAK level for UI/events

signal difficulty_changed(new_level)

func reset(new_master_seed: int):
	master_seed = new_master_seed
	max_forward_index = 0
	current_level = 1
	print("ProgressionManager reset with new master seed.")

func update_progress(new_index: int):
	if new_index > max_forward_index:
		max_forward_index = new_index
		# The global current_level is still useful for tracking the player's best run
		var new_level = (max_forward_index / 2) + 1
		if new_level != current_level:
			current_level = new_level
			emit_signal("difficulty_changed", new_level)
		print("Player reached new max index: ", max_forward_index, " | New Peak Level: ", current_level)

func get_seed_for_index(index: int) -> int:
	var combined_string = str(master_seed) + ":" + str(index)
	return combined_string.hash()


func get_level_for_index(index: int) -> int:
	# This is a helper function to consistently calculate difficulty from position.
	# We use max(0, index) so the start segment (index 0) is level 1, not 0.
	return (max(0, index) / 4) + 1

func get_hill_parameters(index: int) -> Dictionary:	
	# Calculate the difficulty level specific to this segment's index.
	var segment_level = get_level_for_index(index)
	
	# LENGTH: Hills get significantly longer as the player progresses.
	const BASE_LENGTH: float = 1500.0
	const LENGTH_INCREASE_PER_LEVEL: float = 750.0
	
	# AMPLITUDE: Amplitude is for the "bumps". It's kept small compared to maintain the feeling of rolling downhill.
	const BASE_AMPLITUDE: float = 60.0
	const AMPLITUDE_INCREASE_PER_LEVEL: float = 5.0
	
	# SLOPE: The initial downward slope.
	const BASE_SLOPE: float = 0.05
	const SLOPE_INCREASE_PER_LEVEL: float = 0.005  # Was 0.01, now increases 50% slower.
	
	# STEEPNESS INCREASE: The quadratic term that makes the hill curve downwards over its length.
	# This is a very sensitive value and should increase extremely slowly.
	const BASE_STEEPNESS_INCREASE: float = 0.00004
	const STEEPNESS_INCREASE_PER_LEVEL: float = 0.000002 # Was 0.00001, now increases 80% slower.
	
	# --- Formula Calculations ---
	var length: float = BASE_LENGTH + (segment_level * LENGTH_INCREASE_PER_LEVEL)
	var amplitude: float = BASE_AMPLITUDE + (segment_level * AMPLITUDE_INCREASE_PER_LEVEL)
	var frequency: float = 0.0015
	var slope: float = BASE_SLOPE + (segment_level * SLOPE_INCREASE_PER_LEVEL)
	var steepness_increase: float = BASE_STEEPNESS_INCREASE + (segment_level * STEEPNESS_INCREASE_PER_LEVEL)

	return {
		"length": length,
		"amplitude": amplitude,
		"frequency": frequency,
		"slope": slope,
		"steepness_increase": steepness_increase,
		"color": ThemeManagerOlde.get_current_theme().hill_color
	}

func get_obstacle_complexity(index: int) -> int:
	var segment_level = get_level_for_index(index)
	return min(20, max(1, segment_level))

func get_hazard_density(index: int) -> float:
	var segment_level = get_level_for_index(index)
	return clamp(0.05 + (segment_level * 0.02), 0.05, 0.5)
