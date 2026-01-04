@tool
class_name WarehouseDrawUtils
extends RefCounted

static func create_simple_leg(parent: Node2D, pos: Vector2, h: float, color: Color):
	var w = 15.0
	var leg = Polygon2D.new()
	leg.color = color
	leg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, -h), Vector2(0, -h)])
	leg.position = pos
	parent.add_child(leg)

static func create_fry_particle_texture() -> GradientTexture2D:
	var grad = Gradient.new(); grad.set_color(0, Color.WHITE); grad.set_color(1, Color.WHITE)
	var tex = GradientTexture2D.new(); tex.gradient = grad; tex.width = 12; tex.height = 4
	return tex
