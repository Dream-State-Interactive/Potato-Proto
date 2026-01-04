@tool
class_name AssetDesertTerrain
extends ProcTerrainAsset

@export_group("Desert Specifics")
@export var add_ripples: bool = false

# Override math: Sine Wave + Noise
func _get_height_at(world_x: float, noise: FastNoiseLite) -> float:
	var dune_shape = sin(world_x * 0.002) * 0.3
	var n = noise.get_noise_1d(world_x)
	return y_offset + (n * noise_amp) + (dune_shape * noise_amp * 0.5)

# Override details: Wind Ripples
func _post_process(ctx: ProcContext, curve: PackedVector2Array, _main_poly: Polygon2D):
	if not add_ripples: return
	
	var rng = ctx.rng
	var ripple_count = 15
	
	for i in range(ripple_count):
		var idx = rng.randi_range(0, curve.size()-2)
		var pos = curve[idx]
		
		var ripple = Line2D.new()
		ripple.default_color = color.darkened(0.15)
		ripple.width = 3.0
		ripple.z_index = 0 # Draw on top of poly (child order handles it)
		
		var slope_vec = (curve[idx+1] - curve[idx]).normalized()
		var p2 = pos + (slope_vec * rng.randf_range(20, 50))
		
		ripple.points = PackedVector2Array([pos, p2])
		ctx.parent_node.add_child(ripple)
