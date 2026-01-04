@tool
class_name AssetFarmFence
extends ProcAsset

@export var min_segments: int = 2
@export var max_segments: int = 5

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 20: return
	
	for i in range(density):
		var idx = ctx.rng.randi_range(5, ctx.terrain_curve.size() - 20)
		var pos = ctx.terrain_curve[idx]
		
		var segs = ctx.rng.randi_range(min_segments, max_segments)
		var width = segs * 40.0
		
		if not ctx.is_range_free(pos.x, width, 20.0):
			continue 
		
		ctx.reserve_range(pos.x, width)
		
		var fence_root = Node2D.new()
		# Uses the inherited y_offset
		fence_root.position = pos + Vector2(0, y_offset)
		fence_root.z_index = 5
		ctx.parent_node.add_child(fence_root)
		
		FarmDrawUtils.draw_long_fence(fence_root, 0, segs)
