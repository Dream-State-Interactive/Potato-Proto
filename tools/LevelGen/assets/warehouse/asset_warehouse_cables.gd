@tool
class_name AssetWarehouseCables
extends ProcAsset

@export var color: Color = Color(0.08, 0.08, 0.08)
@export var width: float = 3.0
@export var y_hang: float = 120.0
@export var sag_amount: float = 30.0

func generate(ctx: ProcContext):
	var cable = Line2D.new()
	cable.default_color = color
	cable.width = width
	var cable_pts = PackedVector2Array()
	
	var mid_x = ctx.chunk_size * 0.5
	
	# Left side drape (Start to Mid)
	var start_p = Vector2(0, y_hang - 50) 
	var end_p = Vector2(mid_x, y_hang - 20)
	for i in range(11):
		var t = i / 10.0
		var lx = lerp(start_p.x, end_p.x, t)
		var ly = lerp(start_p.y, end_p.y, t) + (sin(t * PI) * sag_amount) 
		cable_pts.append(Vector2(lx, ly))
	
	# Right side drape (Mid to End)
	start_p = Vector2(mid_x, y_hang - 20)
	end_p = Vector2(ctx.chunk_size, y_hang - 50)
	for i in range(11):
		var t = i / 10.0
		var lx = lerp(start_p.x, end_p.x, t)
		var ly = lerp(start_p.y, end_p.y, t) + (sin(t * PI) * sag_amount) 
		cable_pts.append(Vector2(lx, ly))
		
	cable.points = cable_pts
	ctx.parent_node.add_child(cable)
