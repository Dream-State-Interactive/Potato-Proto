# src/modes/gauntlet/progression_manager.gd
extends Node

var hills_completed: int = 0
var current_level: int = 1

signal difficulty_changed(new_level)

func complete_segment():
	hills_completed += 1
	var new_level = (hills_completed / 2) + 1
	if new_level != current_level:
		current_level = new_level
		emit_signal("difficulty_changed", new_level)
	print("Player completed segment. Total: ", hills_completed, " | New Level: ", current_level)

func get_hill_parameters() -> Dictionary:
	# Adjusted frequency to look better with the new scale.
	var length = 200.0 + (current_level * 200.0)
	var amplitude = 200.0 + (current_level * 25.0)
	var frequency = 0.0015
	return {
		"length": length,
		"amplitude": amplitude,
		"frequency": frequency,
		"color": Color.DARK_OLIVE_GREEN
	}

func get_obstacle_complexity() -> int:
	# Cap complexity at 5 for the MVP to keep towers reasonable.
	return min(50, max(1, current_level))

func get_hazard_density() -> float:
	# The generator script will boost this value near the end of the hill.
	return clamp(0.05 + (current_level * 0.02), 0.05, 0.5)
