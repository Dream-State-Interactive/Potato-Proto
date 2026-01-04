@tool
class_name AssetFarmTree
extends ProcAsset

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 10: return
	
	for i in range(density):
		var idx = ctx.rng.randi_range(5, ctx.terrain_curve.size() - 5)
		var params = _get_spawn_params(ctx, idx)
		
		# DrawUtils usually takes a single float for scale, so we pass params.scale.x
		FarmDrawUtils.draw_bushy_tree(ctx.parent_node, params.position, ctx.rng, params.scale.x)
