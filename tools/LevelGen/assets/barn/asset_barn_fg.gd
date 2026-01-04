@tool
class_name AssetBarnFG
extends ProcAsset

@export var floor_y: float = 650.0
@export var dirt_color: Color = Color(0.15, 0.10, 0.05)

func generate(ctx: ProcContext):
	
	# 1. Dirt Mass
	BarnDrawUtils.spawn_solid_rect(ctx.parent_node, Rect2(0, floor_y + 60, ctx.chunk_size, 500), dirt_color, false)
	
	# 2. Scalloped Trim
	BarnDrawUtils.spawn_scallops(ctx.parent_node, floor_y + 62, ctx.chunk_size)
	
	# 3. Floor Platform Beam
	BarnDrawUtils.spawn_beam(ctx.parent_node, Vector2(0, floor_y), Vector2(ctx.chunk_size, 62), false, true)
	
	# 4. Collision
	var sb = StaticBody2D.new()
	var col = CollisionPolygon2D.new()
	col.polygon = PackedVector2Array([
		Vector2(0, floor_y), Vector2(ctx.chunk_size, floor_y),
		Vector2(ctx.chunk_size, floor_y + 120), Vector2(0, floor_y + 120)
	])
	sb.add_child(col)
	ctx.parent_node.add_child(sb)
	
	# 5. Props
	var x_bale = ctx.rng.randf_range(90, 220)
	var x_sack = ctx.rng.randf_range(260, 420)
	var x_pile = ctx.rng.randf_range(500, 700)
	var x_barrel = ctx.rng.randf_range(760, 940)
	
	BarnDrawUtils.spawn_hay_bale(ctx.parent_node, Vector2(x_bale, floor_y), Vector2(120, 70))
	BarnDrawUtils.spawn_sack(ctx.parent_node, Vector2(x_sack, floor_y), Vector2(78, 92))
	BarnDrawUtils.spawn_hay_pile(ctx.parent_node, Vector2(x_pile, floor_y), ctx.rng)
	BarnDrawUtils.spawn_barrel(ctx.parent_node, Vector2(x_barrel, floor_y))
	
	# 6. Report Terrain
	ctx.terrain_curve = PackedVector2Array([Vector2(0, floor_y), Vector2(ctx.chunk_size, floor_y)])
	ctx.terrain_y_end = floor_y
