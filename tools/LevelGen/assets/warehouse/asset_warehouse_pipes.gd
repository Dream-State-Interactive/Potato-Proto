@tool
class_name AssetWarehousePipes
extends ProcAsset

@export var pipe_color: Color = Color(0.07, 0.09, 0.11) # metal_dark darkened(0.5)
@export var column_color: Color = Color(0.14, 0.15, 0.17) # wall_base darkened(0.3)
@export var ceiling_y: float = -3000.0
@export var depth: float = 4000.0

func generate(ctx: ProcContext):
	# Columns
	for i in range(2):
		var col_x = ctx.rng.randf_range(0, ctx.chunk_size)
		var w = ctx.rng.randf_range(40, 80)
		var col = Polygon2D.new()
		col.color = column_color
		col.polygon = PackedVector2Array([
			Vector2(col_x, ceiling_y), Vector2(col_x + w, ceiling_y),
			Vector2(col_x + w, depth), Vector2(col_x, depth)
		])
		ctx.parent_node.add_child(col)
	
	# Horizontal Pipe
	var pipe_y = ctx.rng.randf_range(100, 400)
	var pipe = Line2D.new()
	pipe.default_color = pipe_color
	pipe.width = 20
	pipe.points = PackedVector2Array([Vector2(0, pipe_y), Vector2(ctx.chunk_size, pipe_y)])
	ctx.parent_node.add_child(pipe)
