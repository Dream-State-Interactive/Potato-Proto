@tool
class_name AssetDesertPyramid
extends ProcAsset

@export var lit_color: Color = Color(0.25, 0.2, 0.12)
@export var shadow_color: Color = Color(0.1, 0.08, 0.05)
@export var horizon_y: float = 200.0

func generate(ctx: ProcContext):
	# Logic from reference _create_pyramid
	var h = ctx.rng.randf_range(250, 400)
	var aspect_ratio = ctx.rng.randf_range(1.6, 2.2)
	var w = h * aspect_ratio
	
	var x = ctx.rng.randf_range(100, ctx.chunk_size - 100)
	var y = horizon_y
	
	var container = Node2D.new()
	container.position = Vector2(x, y)
	container.z_index = -10 # Behind terrain
	ctx.parent_node.add_child(container)
	
	var split_x = ctx.rng.randf_range(-w * 0.1, w * 0.1)
	
	# Left Face (Shadow)
	var p_shadow = Polygon2D.new()
	p_shadow.color = shadow_color
	p_shadow.polygon = PackedVector2Array([
		Vector2(-w/2, 0),   
		Vector2(0, -h),     
		Vector2(split_x, 0) 
	])
	container.add_child(p_shadow)
	
	# Right Face (Lit)
	var p_lit = Polygon2D.new()
	p_lit.color = lit_color
	p_lit.polygon = PackedVector2Array([
		Vector2(split_x, 0), 
		Vector2(0, -h),      
		Vector2(w/2, 0)      
	])
	container.add_child(p_lit)
