# src/tools/LevelGen/core/layer_profile.gd
class_name LayerProfile
extends Resource

@export var layer_name: String = "Layer"
@export var parallax_speed: Vector2 = Vector2(1.0, 1.0)
@export var z_index: int = 0
@export var render_distance: int = 3
@export var y_offset: float = 0.0

## List of assets to spawn in this layer (Order matters: Terrain first, then Trees)
@export var assets: Array[ProcAsset] = []
