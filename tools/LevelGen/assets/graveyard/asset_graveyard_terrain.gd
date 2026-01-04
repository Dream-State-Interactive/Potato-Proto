@tool
class_name AssetGraveyardTerrain
extends ProcTerrainAsset

@export_group("Graveyard Specifics")
@export var hill_color: Color = Color(0.05, 0.08, 0.11)
@export var depth01: float = 0.0 # 0=Close, 1=Far
@export var fade_color: Color = Color(0.12, 0.24, 0.28)
@export var fade_strength: float = 0.38
@export var fog_strength: float = 0.78
@export var rim_light: bool = true
@export var z_index: int = 0 # Explicitly define z_index for this asset

func _get_height_at(world_x: float, noise: FastNoiseLite) -> float:
	# Add sway (low frequency sine)
	var sway = sin(world_x * (noise_freq * 2.0)) * (noise_amp * 0.2)
	# y_offset comes from ProcAsset base class
	return y_offset + (noise.get_noise_1d(world_x) * noise_amp) + sway

func _post_process(ctx: ProcContext, curve: PackedVector2Array, main_poly: Polygon2D):
	# Apply Distance Fade
	var final_col = GraveyardDrawUtils.distance_fade(hill_color, depth01, fade_color, fade_strength)
	main_poly.color = final_col
	main_poly.z_index = z_index
	
	# Rim Light
	if rim_light:
		var rim_col = GraveyardDrawUtils.distance_fade(hill_color.lightened(0.1), depth01, fade_color, fade_strength)
		GraveyardDrawUtils.add_line(ctx.parent_node, curve, rim_col, 3.0, z_index + 1)
		
	# Fog Sheet
	_add_fog_sheet(ctx.parent_node, curve, final_col)

func _add_fog_sheet(parent: Node2D, curve: PackedVector2Array, base_col: Color):
	var fog = Polygon2D.new()
	fog.z_index = z_index + 2
	var c = fade_color
	c.a = clamp(0.05 + (1.0 - depth01) * 0.18, 0.04, 0.22) * fog_strength
	fog.color = c
	
	var pts = PackedVector2Array()
	var y_off = 16.0 + (1.0-depth01) * 10.0
	var thick = 64.0 + (1.0-depth01) * 30.0
	
	for p in curve: pts.append(p + Vector2(0, y_off))
	for i in range(curve.size()-1, -1, -1): pts.append(curve[i] + Vector2(0, y_off + thick))
	
	fog.polygon = pts
	parent.add_child(fog)
