@tool
class_name AssetForestTerrain
extends ProcTerrainAsset

@export_group("Forest Specifics")
@export var use_sp_curve: bool = false
@export var sp_freq: float = 0.003
@export var sp_amp: float = 60.0

func _get_height_at(world_x: float, noise: FastNoiseLite) -> float:
	if use_sp_curve:
		var nx = world_x * sp_freq
		return y_offset + sin(nx) * sp_amp + sin(nx * 0.5) * sp_amp * 0.35
	return y_offset + (noise.get_noise_1d(world_x) * noise_amp)
