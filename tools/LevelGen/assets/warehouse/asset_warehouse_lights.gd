@tool
class_name AssetWarehouseLights
extends ProcAsset

@export var metal_dark: Color = Color(0.15, 0.18, 0.22)
@export var beam_color: Color = Color(1.0, 1.0, 0.9, 0.15)
@export var y_hang: float = 120.0
@export var ceiling_y: float = -3000.0

func generate(ctx: ProcContext):
	var x = ctx.chunk_size * 0.5
	
	# Vertical Wire
	var wire = Line2D.new()
	wire.default_color = Color(0.1, 0.1, 0.1)
	wire.width = 4
	wire.points = PackedVector2Array([Vector2(x, ceiling_y), Vector2(x, y_hang)])
	ctx.parent_node.add_child(wire)
	
	# Lamp Shade
	var shade = Polygon2D.new()
	shade.color = metal_dark
	shade.polygon = PackedVector2Array([
		Vector2(-15, 0), Vector2(15, 0),
		Vector2(25, 20), Vector2(-25, 20)
	])
	shade.position = Vector2(x, y_hang)
	ctx.parent_node.add_child(shade)
	
	# Light Cone
	var cone = Polygon2D.new()
	cone.color = beam_color
	cone.polygon = PackedVector2Array([
		Vector2(-20, 20), Vector2(20, 20),
		Vector2(120, 500), Vector2(-120, 500)
	])
	cone.position = Vector2(x, y_hang)
	ctx.parent_node.add_child(cone)
