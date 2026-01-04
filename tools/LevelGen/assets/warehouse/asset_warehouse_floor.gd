@tool
class_name AssetWarehouseFloor
extends ProcAsset

@export var floor_color: Color = Color(0.25, 0.25, 0.28)
@export var truss_color: Color = Color(0.15, 0.15, 0.18)
@export var start_y: float = 500.0
@export var depth: float = 4000.0

func generate(ctx: ProcContext):
	var my_start_y = start_y
	
	# Snap Logic
	if not is_nan(ctx.snap_y):
		my_start_y = ctx.snap_y
	elif ctx.shared_state.has("last_floor_y"):
		my_start_y = ctx.shared_state["last_floor_y"]
	
	var my_end_y = my_start_y
	var type = "FLAT"
	var r = ctx.rng.randf()
	
	if r < 0.6: type = "FLAT"
	elif r < 0.75: type = "BRIDGE"
	elif r < 0.85: 
		type = "STAIRS_DOWN"; my_end_y += 200
	else: 
		type = "STAIRS_UP"; my_end_y -= 200
		
	
	ctx.shared_state["last_floor_y"] = my_end_y
	
	# Calculate safe bottom Y
	var max_y = max(my_start_y, my_end_y)
	var safe_depth = max(depth, max_y + 2000.0)
	
	if type == "BRIDGE":
		_build_bridge(ctx, my_start_y, safe_depth)
	else:
		var poly = Polygon2D.new()
		poly.color = floor_color
		poly.polygon = PackedVector2Array([
			Vector2(0, my_start_y), Vector2(ctx.chunk_size, my_end_y),
			Vector2(ctx.chunk_size, safe_depth), Vector2(0, safe_depth)
		])
		ctx.parent_node.add_child(poly)
		_add_col(ctx.parent_node, poly.polygon)
		ctx.terrain_curve = PackedVector2Array([Vector2(0, my_start_y), Vector2(ctx.chunk_size, my_end_y)])

func _build_bridge(ctx: ProcContext, y: float, safe_depth: float):
	var gap_s = 100.0; var gap_e = ctx.chunk_size - 100.0
	
	# Ledge Left
	var p1 = Polygon2D.new(); p1.color = floor_color
	p1.polygon = PackedVector2Array([Vector2(0,y), Vector2(gap_s,y), Vector2(gap_s,safe_depth), Vector2(0,safe_depth)])
	ctx.parent_node.add_child(p1); _add_col(ctx.parent_node, p1.polygon)
	
	# Ledge Right
	var p2 = Polygon2D.new(); p2.color = floor_color
	p2.polygon = PackedVector2Array([Vector2(gap_e,y), Vector2(ctx.chunk_size,y), Vector2(ctx.chunk_size,safe_depth), Vector2(gap_e,safe_depth)])
	ctx.parent_node.add_child(p2); _add_col(ctx.parent_node, p2.polygon)
	
	# Truss
	var top = Polygon2D.new(); top.color = truss_color
	top.polygon = PackedVector2Array([Vector2(gap_s,y), Vector2(gap_e,y), Vector2(gap_e,y+10), Vector2(gap_s,y+10)])
	ctx.parent_node.add_child(top); _add_col(ctx.parent_node, top.polygon)
	
	var bot = Polygon2D.new(); bot.color = truss_color
	bot.polygon = PackedVector2Array([Vector2(gap_s,y+60), Vector2(gap_e,y+60), Vector2(gap_e,y+70), Vector2(gap_s,y+70)])
	ctx.parent_node.add_child(bot)
	
	var zig = Line2D.new(); zig.default_color = truss_color; zig.width = 5
	var pts = PackedVector2Array()
	for i in range(11): pts.append(Vector2(lerp(gap_s, gap_e, i/10.0), y + (0 if i%2==0 else 60)))
	zig.points = pts
	ctx.parent_node.add_child(zig)
	
	ctx.terrain_curve = PackedVector2Array([Vector2(gap_s,y), Vector2(gap_e,y)])

func _add_col(p: Node, poly: PackedVector2Array):
	var sb = StaticBody2D.new()
	var c = CollisionPolygon2D.new()
	c.polygon = poly
	sb.add_child(c)
	p.add_child(sb)
