# src/tools/LevelGen/core/terrain_override.gd"
class_name TerrainOverride
extends Resource

@export_group("Range")
@export var start_chunk: int = 0
@export var end_chunk: int = 5
## How many chunks at the start/end to use for smoothing the transition.
@export var transition_chunks: float = 1.0 

@export_group("Shape")
@export var curve: Curve
@export var min_height: float = 0.0  # Altitude 0
@export var max_height: float = 500.0 # Peak Altitude
@export_range(0, 1) var blend_weight: float = 1.0

@export_group("Parallax")
@export var parallax_corrected: bool = false
@export var bg_height_multiplier: float = 0.5

func is_in_range(world_x: float, c_size: int) -> bool:
	var s_x = float(start_chunk * c_size)
	var e_x = float((end_chunk + 1) * c_size)
	return world_x >= s_x and world_x < e_x

func get_progress_at_world_x(world_x: float, c_size: int) -> float:
	var s_x = float(start_chunk * c_size)
	var e_x = float((end_chunk + 1) * c_size)
	return clamp((world_x - s_x) / (e_x - s_x), 0.0, 1.0)

## Returns a 0.0-1.0 value representing how much 'influence' this hill has.
## Used to smoothly blend the start and end of the hill.
func get_blend_mask(world_x: float, c_size: int) -> float:
	var s_x = float(start_chunk * c_size)
	var e_x = float((end_chunk + 1) * c_size)
	var margin = transition_chunks * c_size
	
	if world_x < s_x or world_x > e_x: return 0.0
	
	# Fade in at start, Fade out at end
	var dist_from_start = (world_x - s_x) / margin
	var dist_from_end = (e_x - world_x) / margin
	return clamp(min(dist_from_start, dist_from_end), 0.0, 1.0)

func get_height_at_progress(progress: float) -> float:
	if not curve: return 0.0
	return lerp(min_height, max_height, curve.sample(progress))
