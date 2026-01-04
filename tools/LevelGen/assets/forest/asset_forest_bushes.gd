@tool
class_name AssetForestBushes
extends ProcAsset

@export var color: Color = Color(0.05, 0.11, 0.05)

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 2: return
	
	for i in range(density):
		var idx = ctx.rng.randi_range(0, ctx.terrain_curve.size()-2)
		var params = _get_spawn_params(ctx, idx) # New helper
		
		var bush = Polygon2D.new()
		bush.color = color
		bush.position = params.position
		bush.rotation = params.rotation
		bush.scale = params.scale
		bush.z_index = 10 
		
		var pts = PackedVector2Array()
		var radius = ctx.rng.randf_range(20, 40)
		for s in range(11):
			var angle = PI + (float(s) / 10.0) * PI
			var r = radius + ctx.rng.randf_range(-5, 5)
			pts.append(Vector2(cos(angle) * r, sin(angle) * r * 0.6))
		
		bush.polygon = pts
		ctx.parent_node.add_child(bush)
