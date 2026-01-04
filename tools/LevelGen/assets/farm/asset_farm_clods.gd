@tool
class_name AssetFarmDecor
extends ProcAsset

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 10: return
	_gen_clods(ctx)

func _gen_clods(ctx: ProcContext):
	for i in range(density):
		var idx = ctx.rng.randi_range(2, ctx.terrain_curve.size()-3)
		var params = _get_spawn_params(ctx, idx)
		
		var clod = Polygon2D.new()
		var dark = Color(0.22, 0.15, 0.08)
		var light = Color(0.35, 0.25, 0.12)
		
		clod.color = light.lightened(0.05) if ctx.rng.randf() > 0.5 else dark.darkened(0.1)
		clod.z_index = 1
		clod.position = params.position
		clod.rotation = params.rotation
		clod.scale = params.scale
		
		var w = ctx.rng.randf_range(10, 30)
		var h = ctx.rng.randf_range(5, 10)
		
		clod.polygon = PackedVector2Array([
			Vector2(-w/2, 0), 
			Vector2(-w/4, -h * ctx.rng.randf_range(0.5, 1.0)),
			Vector2(0, -h), 
			Vector2(w/3, -h * ctx.rng.randf_range(0.5, 1.0)), 
			Vector2(w/2, 0)
		])
		ctx.parent_node.add_child(clod)
