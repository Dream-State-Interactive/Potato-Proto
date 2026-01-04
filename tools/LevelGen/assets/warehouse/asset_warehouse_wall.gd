@tool
class_name AssetWarehouseWall
extends ProcAsset

@export var base_color: Color = Color(0.2, 0.22, 0.25)
@export var brick_color: Color = Color(0.18, 0.2, 0.23)
@export var window_chance: float = 0.6

func generate(ctx: ProcContext):
	# Base Wall
	var bg = Polygon2D.new()
	bg.color = base_color
	bg.polygon = PackedVector2Array([
		Vector2(0, -3000), Vector2(ctx.chunk_size, -3000),
		Vector2(ctx.chunk_size, 4000), Vector2(0, 4000)
	])
	ctx.parent_node.add_child(bg)
	
	# Bricks
	var brick_w = 60; var brick_h = 30
	var rows = 100; var cols = int(ctx.chunk_size / brick_w) + 1
	for y in range(rows):
		var offset = 0 if y % 2 == 0 else brick_w / 2
		for x in range(cols):
			if ctx.rng.randf() > 0.85:
				var b = Polygon2D.new()
				b.color = brick_color
				b.polygon = PackedVector2Array([Vector2(0,0), Vector2(brick_w-2, 0), Vector2(brick_w-2, brick_h-2), Vector2(0, brick_h-2)])
				b.position = Vector2(x * brick_w + offset, -1000 + (y * brick_h))
				ctx.parent_node.add_child(b)
				
	# Window
	if ctx.rng.randf() < window_chance:
		var win_w = 150.0; var win_h = 250.0
		var win_x = ctx.rng.randf_range(100, ctx.chunk_size - 200)
		_draw_window(ctx.parent_node, Vector2(win_x, -500), win_w, win_h)

func _draw_window(parent: Node2D, pos: Vector2, w: float, h: float):
	# Frame
	var frame = Polygon2D.new()
	frame.color = Color(0.15, 0.15, 0.15)
	frame.polygon = PackedVector2Array([
		Vector2(-w/2 - 5, -h/2 - 5), Vector2(w/2 + 5, -h/2 - 5),
		Vector2(w/2 + 5, h/2 + 5), Vector2(-w/2 - 5, h/2 + 5)
	])
	frame.position = pos
	parent.add_child(frame)
	
	# Panes
	var rows = 3
	var cols = 2
	var pane_w = w / cols
	var pane_h = h / rows
	
	for r in range(rows):
		for c in range(cols):
			var pane = Polygon2D.new()
			pane.color = Color(0.1, 0.12, 0.15) # Dark glass
			var gap = 2.0
			
			# Calculate local position relative to window center
			var p_x = -w/2 + (c * pane_w) + gap
			var p_y = -h/2 + (r * pane_h) + gap
			
			pane.polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(pane_w - gap*2, 0),
				Vector2(pane_w - gap*2, pane_h - gap*2), Vector2(0, pane_h - gap*2)
			])
			pane.position = pos + Vector2(p_x, p_y)
			parent.add_child(pane)
