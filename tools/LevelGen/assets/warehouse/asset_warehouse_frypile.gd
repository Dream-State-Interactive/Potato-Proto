@tool
class_name AssetWarehouseFryPile
extends ProcAsset

@export var fry_color: Color = Color(0.95, 0.75, 0.2)
@export var fry_shadow_color: Color = Color(0.8, 0.6, 0.1)

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 2: return
	# Only spawn on flat ground
	if abs(ctx.terrain_curve[0].y - ctx.terrain_curve[-1].y) > 10.0: return
	
	var floor_y = ctx.terrain_curve[0].y
	
	var pile_width = ctx.rng.randf_range(60, 120)
	var pile_height = ctx.rng.randf_range(30, 60)
	var x = ctx.rng.randf_range(50, ctx.chunk_size - 50)
	
	# Check collision so we don't spawn inside a conveyor
	if not ctx.is_range_free(x - pile_width/2, pile_width, 10.0): return
	
	var pos = Vector2(x, floor_y)
	
	# 1. Fry Mound
	var mound = Polygon2D.new()
	mound.color = fry_shadow_color.darkened(0.2)
	var pts = PackedVector2Array()
	for i in range(10):
		var angle = PI + (float(i)/9.0) * PI
		pts.append(Vector2(cos(angle) * pile_width/2, sin(angle) * pile_height) + pos)
	mound.polygon = pts
	ctx.parent_node.add_child(mound)
	
	# 2. Individual Fries
	for i in range(density):
		var r = ctx.rng.randf()
		var theta = ctx.rng.randf() * PI + PI 
		var fx = cos(theta) * (pile_width/2 * r)
		var fy = sin(theta) * (pile_height * r)
		
		var fry_pos = pos + Vector2(fx, fy)
		_spawn_single_fry(ctx.parent_node, fry_pos, ctx.rng.randf() * TAU, ctx.rng)

func _spawn_single_fry(parent: Node2D, pos: Vector2, rotation: float, rng: RandomNumberGenerator):
	var fry = Polygon2D.new()
	if rng.randf() > 0.8: fry.color = fry_shadow_color 
	else: fry.color = fry_color
	
	var w = rng.randf_range(12, 20) 
	var h = rng.randf_range(3, 5)   
	
	fry.polygon = PackedVector2Array([
		Vector2(-w/2, -h/2), Vector2(w/2, -h/2),
		Vector2(w/2, h/2), Vector2(-w/2, h/2)
	])
	fry.rotation = rotation
	fry.position = pos
	parent.add_child(fry)
