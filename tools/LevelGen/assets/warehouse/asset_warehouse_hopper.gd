@tool
class_name AssetWarehouseHopper
extends ProcAsset

@export var metal_dark: Color = Color(0.15, 0.18, 0.22)
@export var metal_light: Color = Color(0.3, 0.35, 0.4)
@export var fry_shadow_color: Color = Color(0.8, 0.6, 0.1)
@export var hopper_chance: float = 0.5
@export var ceiling_y: float = -3000.0

func generate(ctx: ProcContext):
	var belt_y = 400.0
	
	# Background Belt
	var belt = Polygon2D.new()
	belt.color = metal_dark
	belt.polygon = PackedVector2Array([
		Vector2(0, belt_y), Vector2(ctx.chunk_size, belt_y - 50),
		Vector2(ctx.chunk_size, belt_y - 20), Vector2(0, belt_y + 30)
	])
	ctx.parent_node.add_child(belt)
	
	# Hopper
	if ctx.rng.randf() < hopper_chance:
		var hopper_x = ctx.chunk_size * 0.5
		var hopper_y = belt_y - 80 
		_create_industrial_hopper(ctx.parent_node, Vector2(hopper_x, hopper_y), 0.7)

func _create_industrial_hopper(parent: Node2D, pos: Vector2, scale: float):
	var hopper = Node2D.new()
	hopper.position = pos
	hopper.scale = Vector2(scale, scale)
	parent.add_child(hopper)
	
	var support_left = Line2D.new()
	support_left.default_color = metal_dark.darkened(0.3)
	support_left.width = 10
	support_left.points = PackedVector2Array([Vector2(-90, -100), Vector2(-90, ceiling_y)])
	hopper.add_child(support_left)
	
	var support_right = Line2D.new()
	support_right.default_color = metal_dark.darkened(0.3)
	support_right.width = 10
	support_right.points = PackedVector2Array([Vector2(90, -100), Vector2(90, ceiling_y)])
	hopper.add_child(support_right)

	var body = Polygon2D.new()
	body.color = metal_light
	body.polygon = PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(40, 50), Vector2(-40, 50)])
	hopper.add_child(body)
	
	var rim = Polygon2D.new()
	rim.color = metal_dark
	rim.polygon = PackedVector2Array([Vector2(-110, -120), Vector2(110, -120), Vector2(100, -100), Vector2(-100, -100)])
	hopper.add_child(rim)
	
	var fries_in = Polygon2D.new()
	fries_in.color = fry_shadow_color
	fries_in.polygon = PackedVector2Array([Vector2(-90, -100), Vector2(0, -140), Vector2(90, -100)])
	hopper.add_child(fries_in)
