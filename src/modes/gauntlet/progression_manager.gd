# src/modes/gauntlet/progression_manager.gd
extends Node

var hills_completed: int = 0
var current_level: int = 1

# --- Worm progression ---
var worms_unlock_at: int = 20
var worm_stack_base: int = 6                # starting length at unlock
var worm_stack_step_hills: int = 5          # hills per step
var worm_chance_base: float = 0.03          # base per-spot probability when unlocked
var worm_chance_step: float = 0.01          # per step increase
var worm_chance_cap: float = 0.20           # don't spam too hard
var worm_max_per_hill: int = 3              # safety cap per hill

signal difficulty_changed(new_level)

func complete_segment():
	hills_completed += 1
	var new_level = (hills_completed / 2) + 1
	if new_level != current_level:
		current_level = new_level
		emit_signal("difficulty_changed", new_level)
	print("Player completed segment. Total: ", hills_completed, " | New Level: ", current_level)

func get_hill_parameters() -> Dictionary:
	var length := 800.0 + (current_level * 240.0)
	var amplitude := 160.0 + (current_level * 22.0)
	var frequency := 0.0012
	var slope := 0.08 + current_level * 0.004
	return {
		"length": length,
		"amplitude": amplitude,
		"frequency": frequency,
		"slope": slope,
		"color": Color.DARK_OLIVE_GREEN
	}


func get_worm_params() -> Dictionary:
	if hills_completed < worms_unlock_at:
		return {"enabled": false}

	var steps: int = int((hills_completed - worms_unlock_at) / worm_stack_step_hills)
	var stack_size: int = worm_stack_base + steps
	var chance: float = clampf(
		worm_chance_base + (steps * worm_chance_step),
		worm_chance_base,
		worm_chance_cap
	)

	return {
		"enabled": true,
		"stack_size": stack_size,
		"chance": chance,
		"max_per_hill": worm_max_per_hill
	}
func get_obstacle_complexity() -> int:
	# Cap complexity at 5 for the MVP to keep towers reasonable.
	return min(50, max(1, current_level))

func get_hazard_density() -> float:
	# The generator script will boost this value near the end of the hill.
	return clamp(0.05 + (current_level * 0.02), 0.05, 0.5)
