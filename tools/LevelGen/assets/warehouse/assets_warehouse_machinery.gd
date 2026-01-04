@tool
class_name AssetWarehouseMachinery
extends ProcAsset

@export var metal_dark: Color = Color(0.15, 0.18, 0.22)

func generate(ctx: ProcContext):
	var type = ctx.rng.randi_range(0, 2)
	var x = ctx.chunk_size * 0.5
	var y = ctx.rng.randf_range(600, 1200)
	
	if type == 0:
		_draw_flywheel(ctx, Vector2(x, y))
	elif type == 1:
		_draw_piston(ctx, Vector2(x, y))
	else:
		_draw_tank(ctx, Vector2(x, y + 200))

func _draw_flywheel(ctx: ProcContext, pos: Vector2):
	var wheel = Polygon2D.new()
	wheel.color = metal_dark.darkened(0.4)
	wheel.position = pos
	var pts = PackedVector2Array()
	var rad = ctx.rng.randf_range(150, 250)
	for i in range(16): pts.append(Vector2(cos((float(i)/16.0)*TAU)*rad, sin((float(i)/16.0)*TAU)*rad))
	wheel.polygon = pts
	ctx.parent_node.add_child(wheel)
	
	# Spokes
	var spoke = Polygon2D.new()
	spoke.color = metal_dark.darkened(0.6)
	spoke.polygon = PackedVector2Array([Vector2(-20, -rad), Vector2(20, -rad), Vector2(20, rad), Vector2(-20, rad)])
	wheel.add_child(spoke)
	var spoke2 = spoke.duplicate(); spoke2.rotation = PI/2; wheel.add_child(spoke2)
	
	var tween = ctx.parent_node.create_tween().set_loops()
	tween.tween_property(wheel, "rotation", TAU, ctx.rng.randf_range(4.0, 8.0)).as_relative()

func _draw_piston(ctx: ProcContext, pos: Vector2):
	var cyl = Polygon2D.new()
	cyl.color = metal_dark.darkened(0.3)
	cyl.polygon = PackedVector2Array([Vector2(-60,0), Vector2(60,0), Vector2(60,300), Vector2(-60,300)])
	cyl.position = pos
	ctx.parent_node.add_child(cyl)
	
	var head = Polygon2D.new()
	head.color = metal_dark.lightened(0.1)
	head.polygon = PackedVector2Array([Vector2(-50,0), Vector2(50,0), Vector2(50,100), Vector2(-50,100)])
	head.position = Vector2(0, 20)
	cyl.add_child(head)
	
	var tween = ctx.parent_node.create_tween().set_loops()
	tween.tween_property(head, "position:y", 180.0, ctx.rng.randf_range(1.0, 2.0)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(head, "position:y", 20.0, ctx.rng.randf_range(1.0, 2.0)).set_trans(Tween.TRANS_SINE)

func _draw_tank(ctx: ProcContext, pos: Vector2):
	var w = ctx.rng.randf_range(150, 250)
	var h = ctx.rng.randf_range(300, 500)
	
	var tank = Polygon2D.new()
	tank.color = metal_dark.darkened(0.5)
	tank.polygon = PackedVector2Array([Vector2(-w/2, 0), Vector2(w/2, 0), Vector2(w/2, h), Vector2(-w/2, h)])
	tank.position = pos
	ctx.parent_node.add_child(tank)
	
	# Bubbles
	var bubbles = CPUParticles2D.new()
	bubbles.position = Vector2(0, h)
	bubbles.amount = 20
	bubbles.lifetime = 4.0
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(w/2 - 10, 10)
	bubbles.direction = Vector2(0, -1)
	bubbles.gravity = Vector2(0, -20)
	bubbles.scale_amount_min = 2.0
	bubbles.scale_amount_max = 5.0
	bubbles.color = Color(1, 1, 1, 0.1)
	tank.add_child(bubbles)
