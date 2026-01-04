# src/tools/LevelGen/core/proc_context.gd
class_name ProcContext
extends RefCounted

var chunk_index: int
var global_x: float
var chunk_size: int
var parent_node: Node2D
var rng: RandomNumberGenerator
var shared_state: Dictionary

# Override System
var terrain_overrides: Array[TerrainOverride] = []
var is_background: bool = false

# Data passed from Terrain to Scatter assets
var terrain_curve: PackedVector2Array = PackedVector2Array()
var terrain_y_end: float = 0.0

# Collision/Scatter System
var occupied_ranges: Array[Vector2] = []
var snap_y: float = NAN 

## Finds the correct hill at a specific world coordinate
func get_active_override(world_x: float) -> TerrainOverride:
	for ov in terrain_overrides:
		# 1. Respect the toggle: If this is BG and toggle is off, ignore this hill
		if is_background and not ov.parallax_corrected: continue
		
		# 2. Check if this point is inside the hill
		if ov.is_in_range(world_x, chunk_size):
			return ov
	return null

func is_range_free(start_x: float, width: float, margin: float = 10.0) -> bool:
	var end_x = start_x + width
	var check_min = start_x - margin
	var check_max = end_x + margin
	for r in occupied_ranges:
		if check_min < r.y and check_max > r.x:
			return false
	return true

func reserve_range(start_x: float, width: float):
	occupied_ranges.append(Vector2(start_x, start_x + width))
