@tool
class_name AssetFarmTerrain
extends ProcTerrainAsset

@export_group("Farm Specifics")
@export var soil_light_color: Color = Color(0.35, 0.25, 0.12)

@export_subgroup("Furrows")
@export var furrow_freq: float = 0.003
@export var furrow_amp: float = 0.0

@export_subgroup("Banding")
@export var band_height: float = 30.0
@export var darkness_mult: float = 0.0
@export var irregularity: float = 0.0

func _get_height_at(world_x: float, noise: FastNoiseLite) -> float:
	var y = y_offset + (noise.get_noise_1d(world_x) * noise_amp)
	if furrow_amp > 0.0:
		y += sin(world_x * furrow_freq) * furrow_amp
	return y

func _post_process(ctx: ProcContext, curve: PackedVector2Array, main_poly: Polygon2D):
	# Apply darkness to main poly base
	main_poly.color = color.darkened(darkness_mult)
	
	if band_height <= 0.1: return

	# Draw Light Bands
	var current_offset = 0.0
	var max_depth = 600.0 
	var is_light_band = true
	
	var detail_noise = FastNoiseLite.new()
	detail_noise.seed = 999; detail_noise.frequency = 0.02
	
	while current_offset < max_depth:
		if is_light_band:
			var ribbon = Polygon2D.new()
			ribbon.z_index = main_poly.z_index 
			ribbon.color = soil_light_color.darkened(darkness_mult)
			
			var top_pts = PackedVector2Array()
			var bot_pts = PackedVector2Array()
			
			for i in range(curve.size()):
				var p = curve[i]
				var gx = ctx.global_x + p.x
				
				# Top Edge
				var top_y = p.y + current_offset
				if irregularity > 0.0 and current_offset > 0:
					top_y += detail_noise.get_noise_2d(gx, current_offset) * irregularity
				top_pts.append(Vector2(p.x, top_y))
				
				# Bottom Edge
				var bot_y = p.y + current_offset + band_height
				if irregularity > 0.0:
					bot_y += detail_noise.get_noise_2d(gx, current_offset + band_height) * irregularity
				bot_pts.append(Vector2(p.x, bot_y))
			
			bot_pts.reverse()
			top_pts.append_array(bot_pts)
			ribbon.polygon = top_pts
			ctx.parent_node.add_child(ribbon)
		
		current_offset += band_height
		is_light_band = !is_light_band
