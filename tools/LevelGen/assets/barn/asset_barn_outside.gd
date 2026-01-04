@tool
class_name AssetBarnOutside
extends ProcAsset

func generate(ctx: ProcContext):
	# Sky Background (Light Blue)
	# Covers the whole height behind windows
	var sky_rect = Rect2(Vector2(0, 0), Vector2(ctx.chunk_size, 360.0))
	BarnDrawUtils.spawn_solid_rect(ctx.parent_node, sky_rect, Color(0.62, 0.82, 0.95), false)
	
	# Distant Hills (Green)
	var hills = Polygon2D.new()
	hills.color = Color(0.36, 0.58, 0.42)
	hills.position = Vector2(0, 210)
	hills.polygon = PackedVector2Array([
		Vector2(0, 90), Vector2(120, 60), Vector2(260, 78), Vector2(420, 54),
		Vector2(610, 74), Vector2(820, 58), Vector2(ctx.chunk_size, 80),
		Vector2(ctx.chunk_size, 150), Vector2(0, 150)
	])
	ctx.parent_node.add_child(hills)
	
	# Atmospheric Fade (Bottom)
	var fade = ColorRect.new()
	fade.color = Color(0.95, 0.92, 0.86, 0.12)
	fade.position = Vector2(0, 290)
	fade.size = Vector2(ctx.chunk_size, 120)
	ctx.parent_node.add_child(fade)
