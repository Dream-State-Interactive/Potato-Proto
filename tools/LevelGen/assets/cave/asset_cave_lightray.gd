@tool
class_name AssetCaveLightRay
extends ProcAsset

@export var color: Color = Color(0.4, 0.7, 1.0, 0.04)
@export var width_min: float = 60.0
@export var width_max: float = 180.0
@export var height: float = 1500.0
@export var angle_max: float = 15.0

func generate(ctx: ProcContext):
	
	var ray = Polygon2D.new()
	var w = ctx.rng.randf_range(width_min, width_max)
	
	# Trapezoid shape expanding downwards
	ray.polygon = PackedVector2Array([
		Vector2(-w, 0), 
		Vector2(w, 0), 
		Vector2(w * 4.0, height), 
		Vector2(-w * 4.0, height)
	])
	
	ray.color = color
	ray.position = Vector2(ctx.rng.randf_range(0, ctx.chunk_size), y_offset)
	ray.rotation = deg_to_rad(ctx.rng.randf_range(-angle_max, angle_max))
	
	# Additive Blending for the "Light" effect
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ray.material = mat
	
	ctx.parent_node.add_child(ray)
