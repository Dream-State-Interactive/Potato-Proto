@tool
class_name AssetFarmStructure
extends ProcAsset


# Moves just the fences/trees relative to the barn
@export var attached_objects_y_offset: float = 0.0

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 20: return
	
	var idx = ctx.rng.randi_range(10, ctx.terrain_curve.size() - 20)
	var pos = ctx.terrain_curve[idx]
	
	var width = 800.0
	var start_x = pos.x - 250.0 
	
	if not ctx.is_range_free(start_x, width, 50.0):
		return
		
	ctx.reserve_range(start_x, width)
	
	var root = Node2D.new()
	root.position = pos + Vector2(0, y_offset)
	root.z_index = 5
	ctx.parent_node.add_child(root)
	
	# Draw buildings (Relative 0,0)
	FarmDrawUtils.draw_barn(root, Vector2(0, 0))
	FarmDrawUtils.draw_silo(root, Vector2(90, 0))
	FarmDrawUtils.draw_house(root, Vector2(180, 0))
	
	# Draw decorations with extra offset
	# This container holds the attached items so we can offset them separately
	var decor_root = Node2D.new()
	decor_root.position = Vector2(0, attached_objects_y_offset)
	root.add_child(decor_root)
	
	FarmDrawUtils.draw_bushy_tree(decor_root, Vector2(-250, 0), ctx.rng, 1.3)
	FarmDrawUtils.draw_long_fence(decor_root, -200, 3)
	FarmDrawUtils.draw_long_fence(decor_root, 220, 3)
	FarmDrawUtils.draw_bushy_tree(decor_root, Vector2(400, 0), ctx.rng, 1.1)
