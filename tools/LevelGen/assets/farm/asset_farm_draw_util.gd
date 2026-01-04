@tool
class_name FarmDrawUtils
extends RefCounted

static func draw_bushy_tree(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator, scale: float):
	var tree = Node2D.new()
	tree.position = pos
	tree.scale = Vector2(scale, scale)
	tree.z_index = -2
	parent.add_child(tree)

	var trunk = Polygon2D.new()
	trunk.color = Color(0.18, 0.12, 0.08)
	trunk.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(-6, -25), Vector2(6, -25), Vector2(6, 0)])
	tree.add_child(trunk)
	
	var leaves_col = Color(0.12, 0.18, 0.1)
	var centers = [Vector2(0, -35), Vector2(-18, -28), Vector2(18, -28), Vector2(-10, -45), Vector2(10, -45)]
	
	for c in centers:
		var circle = Polygon2D.new()
		circle.color = leaves_col
		var pts = PackedVector2Array()
		var r = rng.randf_range(14, 20)
		for i in range(12):
			pts.append(c + Vector2(cos((float(i)/12.0)*TAU)*r, sin((float(i)/12.0)*TAU)*r))
		circle.polygon = pts
		tree.add_child(circle)

static func draw_long_fence(parent: Node2D, start_x: float, segments: int):
	var seg_width = 40.0
	for i in range(segments):
		var s = Vector2(start_x + (i * seg_width), 0)
		var e = Vector2(start_x + ((i + 1) * seg_width), 0)
		_draw_fence_segment(parent, s, e)

static func _draw_fence_segment(parent: Node2D, start: Vector2, end: Vector2):
	var col = Color(0.3, 0.25, 0.2)
	
	var rails = Line2D.new()
	rails.default_color = col
	rails.width = 2.0
	rails.points = PackedVector2Array([start + Vector2(0, -12), end + Vector2(0, -12)])
	parent.add_child(rails)
	
	var rails2 = Line2D.new()
	rails2.default_color = col
	rails2.width = 2.0
	rails2.points = PackedVector2Array([start + Vector2(0, -22), end + Vector2(0, -22)])
	parent.add_child(rails2)
	
	var dist = start.distance_to(end)
	var count = int(dist / 25)
	for i in range(count + 1):
		var t = float(i) / max(1, count)
		var p = start.lerp(end, t)
		var post = Polygon2D.new()
		post.color = col.darkened(0.1)
		post.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(-2, -28), Vector2(2, -28), Vector2(2, 0)])
		post.position = p
		parent.add_child(post)

static func draw_barn(parent: Node2D, offset: Vector2):
	var w = 110.0; var h_wall = 60.0; var h_roof = 45.0; var depth = 40.0
	var col_red = Color(0.5, 0.15, 0.15); var col_dark = col_red.darkened(0.3); var col_roof = Color(0.2, 0.2, 0.22)
	
	var side = Polygon2D.new()
	side.color = col_dark
	side.position = offset
	side.polygon = PackedVector2Array([Vector2(w/2, 0), Vector2(w/2 + depth, -15), Vector2(w/2 + depth, -h_wall - 15), Vector2(w/2, -h_wall)])
	parent.add_child(side)
	
	var r_side = Polygon2D.new()
	r_side.color = col_roof.darkened(0.2)
	r_side.position = offset
	r_side.polygon = PackedVector2Array([Vector2(w/2, -h_wall), Vector2(w/2 + depth, -h_wall - 15), Vector2(depth, -h_wall - h_roof - 15), Vector2(0, -h_wall - h_roof)])
	parent.add_child(r_side)
	
	var front = Polygon2D.new()
	front.color = col_red
	front.position = offset
	front.polygon = PackedVector2Array([Vector2(-w/2, 0), Vector2(-w/2, -h_wall), Vector2(-w/2 + 15, -h_wall - h_roof * 0.6), Vector2(0, -h_wall - h_roof), Vector2(w/2 - 15, -h_wall - h_roof * 0.6), Vector2(w/2, -h_wall), Vector2(w/2, 0)])
	parent.add_child(front)
	
	var door = Polygon2D.new()
	door.color = col_dark
	door.position = offset
	door.polygon = PackedVector2Array([Vector2(-25, 0), Vector2(-25, -45), Vector2(25, -45), Vector2(25, 0)])
	parent.add_child(door)
	
	var x = Line2D.new()
	x.default_color = Color(0.9, 0.9, 0.9)
	x.width = 3.0
	x.points = PackedVector2Array([Vector2(-25, 0), Vector2(25, -45)])
	door.add_child(x)
	
	var x2 = Line2D.new()
	x2.default_color = Color(0.9, 0.9, 0.9)
	x2.width = 3.0
	x2.points = PackedVector2Array([Vector2(-25, -45), Vector2(25, 0)])
	door.add_child(x2)

static func draw_silo(parent: Node2D, offset: Vector2):
	var w = 40.0; var h = 110.0; var col = Color(0.6, 0.58, 0.5)
	
	var body = Polygon2D.new()
	body.color = col
	body.position = offset
	body.polygon = PackedVector2Array([Vector2(-w/2, 0), Vector2(-w/2, -h), Vector2(w/2, -h), Vector2(w/2, 0)])
	parent.add_child(body)
	
	var dome = Polygon2D.new()
	dome.color = col.darkened(0.2)
	dome.position = offset
	
	var pts = PackedVector2Array()
	for i in range(17):
		var angle = PI + (float(i) / 16.0) * PI
		pts.append(Vector2(cos(angle) * w / 2.0, sin(angle) * w / 2.0 - h))
	
	dome.polygon = pts
	parent.add_child(dome) # This is now outside the loop!

static func draw_house(parent: Node2D, offset: Vector2):
	var w = 50.0; var h = 40.0; var depth = 25.0; var col = Color(0.7, 0.6, 0.25)
	
	var side = Polygon2D.new()
	side.color = col.darkened(0.3)
	side.position = offset
	side.polygon = PackedVector2Array([Vector2(w/2, 0), Vector2(w/2 + depth, -8), Vector2(w/2 + depth, -h - 8), Vector2(w/2, -h)])
	parent.add_child(side)
	
	var roof = Polygon2D.new()
	roof.color = Color(0.2, 0.2, 0.2)
	roof.position = offset
	roof.polygon = PackedVector2Array([Vector2(-w/2 - 5, -h), Vector2(0, -h - 25), Vector2(w/2 + 5, -h), Vector2(w/2 + depth + 5, -h - 8), Vector2(depth, -h - 33), Vector2(0, -h - 25)])
	parent.add_child(roof)
	
	var front = Polygon2D.new()
	front.color = col
	front.position = offset
	front.polygon = PackedVector2Array([Vector2(-w/2, 0), Vector2(-w/2, -h), Vector2(0, -h - 25), Vector2(w/2, -h), Vector2(w/2, 0)])
	parent.add_child(front)
	
	var win = Polygon2D.new()
	win.color = Color(0.1, 0.05, 0.0)
	win.position = offset
	win.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(-10, -25), Vector2(10, -25), Vector2(10, -10)])
	parent.add_child(win)
