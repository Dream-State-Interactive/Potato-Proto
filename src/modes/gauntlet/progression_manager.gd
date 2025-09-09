# src/modes/gauntlet/progression_manager.gd
extends Node

var hills_completed: int = 0
var current_level: int = 1


signal difficulty_changed(new_level)

func reset():
	hills_completed = 0
	current_level = 1
	print("ProgressionManager has been reset.")

func complete_segment():
	hills_completed += 1
	var new_level = (hills_completed / 2) + 1
	if new_level != current_level:
		current_level = new_level
		emit_signal("difficulty_changed", new_level)
	print("Player completed segment. Total: ", hills_completed, " | New Level: ", current_level)

func get_hill_parameters() -> Dictionary:	
	# Hills get significantly longer as the player progresses.
	var length := 1200.0 + (current_level * 600.0)
	
	# Amplitude is for the "bumps". It's kept relatively small compared to the
	# overall drop to maintain the feeling of rolling downhill.
	var amplitude := 60.0 + (current_level * 5.0)
	
	# Frequency determines how often bumps appear.
	var frequency := 0.0015
	
	# The initial downward slope. A value of 0.2 means a 20px drop for every 100px forward.
	# This is the primary factor for the downhill feel.
	var slope := 0.05 + current_level * 0.01
	
	# Makes the hill get progressively steeper.
	# This is a small value because it's multiplied by the distance squared.
	var steepness_increase := 0.00005 + current_level * 0.00001

	return {
		"length": length,
		"amplitude": amplitude,
		"frequency": frequency,
		"slope": slope,
		"gravity": steepness_increase, # Pass the new gravity parameter
		"color": Color.DARK_OLIVE_GREEN
	}


func get_obstacle_complexity() -> int:
	# Cap complexity at 20 for the MVP to keep towers reasonable.
	return min(20, max(1, current_level))

func get_hazard_density() -> float:
	# The generator script will boost this value near the end of the hill.
	return clamp(0.05 + (current_level * 0.02), 0.05, 0.5)
