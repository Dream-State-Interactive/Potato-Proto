# src/tools/LevelGen/core/proc_asset.gd
@tool
class_name ProcAsset
extends Resource

@export_group("Placement")
@export var density: int = 1
@export_range(0.0, 1.0) var probability: float = 1.0
## If true, this asset generates based on the terrain curve (must be placed after a Terrain asset).
@export var snaps_to_terrain: bool = false
## If true, the asset will tilt to match the angle of the ground.
@export var snap_rotation: bool = false 
@export var y_offset: float = 0.0

@export_group("Transform")
@export var scale_min: float = 1.0
@export var scale_max: float = 1.0

func generate(ctx: ProcContext) -> void:
	pass

## Helper to get randomized transform data for a single spawn instance
func _get_spawn_params(ctx: ProcContext, curve_idx: int) -> Dictionary:
	var pos = ctx.terrain_curve[curve_idx]
	var rot = 0.0
	var scale = ctx.rng.randf_range(scale_min, scale_max)
	
	if snap_rotation and ctx.terrain_curve.size() > curve_idx + 1:
		var p1 = ctx.terrain_curve[curve_idx]
		var p2 = ctx.terrain_curve[curve_idx + 1]
		rot = (p2 - p1).angle()
	
	# Apply Y offset (rotated if snapping to rotation)
	var offset_vec = Vector2(0, y_offset)
	if snap_rotation:
		offset_vec = offset_vec.rotated(rot)
	
	return {
		"position": pos + offset_vec,
		"rotation": rot,
		"scale": Vector2(scale, scale)
	}

func _get_noise(seed_offset: int, freq: float, amp: float) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_offset
	noise.frequency = freq
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	return noise
