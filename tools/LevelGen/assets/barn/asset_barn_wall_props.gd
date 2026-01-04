@tool
class_name AssetBarnWallProps
extends ProcAsset

@export var floor_y: float = 650.0

func generate(ctx: ProcContext):
	# One tool rack per chunk, randomized position
	var rack_x = ctx.rng.randf_range(260.0, 520.0)
	
	BarnDrawUtils.spawn_tool_rack(ctx.parent_node, Vector2(rack_x, floor_y - 205.0))
