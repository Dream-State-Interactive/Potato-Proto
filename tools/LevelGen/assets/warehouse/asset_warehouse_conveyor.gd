@tool
class_name AssetWarehouseConveyor
extends ProcAsset

@export var metal_light: Color = Color(0.3, 0.35, 0.4)
@export var metal_dark: Color = Color(0.15, 0.18, 0.22)
@export var belt_color: Color = Color(0.1, 0.1, 0.1)
@export var fry_color: Color = Color(0.95, 0.75, 0.2)

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 2: return
	
	# Only spawn on flat ground
	if abs(ctx.terrain_curve[0].y - ctx.terrain_curve[-1].y) > 10.0: return
	
	var floor_y = ctx.terrain_curve[0].y
	var width = ctx.rng.randf_range(300, 500)
	var start_x = ctx.rng.randf_range(100, ctx.chunk_size - width - 100)
	
	if not ctx.is_range_free(start_x, width, 20.0): return
	ctx.reserve_range(start_x, width)
	
	var root = Node2D.new()
	root.position = Vector2(start_x, floor_y)
	ctx.parent_node.add_child(root)
	
	var height = ctx.rng.randf_range(150, 250)
	
	# Legs
	WarehouseDrawUtils.create_simple_leg(root, Vector2(50, 0), height/2, metal_dark)
	WarehouseDrawUtils.create_simple_leg(root, Vector2(width-50, 0), height, metal_dark)
	
	# Frame
	var start_pt = Vector2(0, -height/2)
	var end_pt = Vector2(width, -height)
	var frame = Polygon2D.new()
	frame.color = metal_light
	var dir = (end_pt - start_pt).normalized()
	var perp = Vector2(-dir.y, dir.x) * 40.0
	frame.polygon = PackedVector2Array([start_pt + perp, end_pt + perp, end_pt, start_pt])
	root.add_child(frame)
	
	# Belt
	var belt = Line2D.new()
	belt.default_color = belt_color
	belt.width = 10
	belt.points = PackedVector2Array([start_pt + perp/2, end_pt + perp/2])
	root.add_child(belt)
	
	var fry_tex = WarehouseDrawUtils.create_fry_particle_texture()
	
	# 1. Belt Moving Particles
	var p = CPUParticles2D.new()
	p.position = start_pt + (perp * 0.6)
	p.amount = int(width / 20)
	var belt_len = start_pt.distance_to(end_pt)
	var fry_speed = 150.0
	p.lifetime = belt_len / fry_speed
	p.texture = fry_tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 5)
	p.direction = dir
	p.spread = 0.0 # Strict direction
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = fry_speed
	p.initial_velocity_max = fry_speed
	p.color = fry_color
	p.angle_min = -15 + rad_to_deg(dir.angle())
	p.angle_max = 15 + rad_to_deg(dir.angle())
	root.add_child(p)
	
	# 2. Chute & Falling Particles
	var chute = Polygon2D.new()
	chute.color = metal_dark.darkened(0.2)
	chute.polygon = PackedVector2Array([
		end_pt, end_pt + Vector2(50, 0),
		end_pt + Vector2(30, 60), end_pt + Vector2(0, 60)
	])
	root.add_child(chute)
	
	var fall_p = CPUParticles2D.new()
	fall_p.position = end_pt + Vector2(15, 60)
	fall_p.amount = 12
	fall_p.lifetime = 1.0
	fall_p.texture = fry_tex
	fall_p.direction = Vector2(0, 1) # Down
	fall_p.spread = 20.0
	fall_p.gravity = Vector2(0, 400)
	fall_p.initial_velocity_min = 50.0
	fall_p.initial_velocity_max = 100.0
	fall_p.color = fry_color
	fall_p.angle_min = 0
	fall_p.angle_max = 360
	fall_p.angular_velocity_min = 100
	fall_p.angular_velocity_max = 300
	root.add_child(fall_p)
