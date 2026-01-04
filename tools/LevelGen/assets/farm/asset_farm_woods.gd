@tool
class_name AssetFarmWoods
extends ProcAsset

@export var color: Color = Color(0.05, 0.1, 0.05)
@export var noise_seed: int = 11
@export var noise_freq: float = 0.015
@export var noise_amp: float = 50.0

func generate(ctx: ProcContext):
	var noise = _get_noise(noise_seed, noise_freq, noise_amp)
	var curve = PackedVector2Array()
	var step = 16
	
	# Base terrain curve
	for x in range(0, ctx.chunk_size, step):
		var y = y_offset + noise.get_noise_1d(ctx.global_x + x) * noise_amp
		curve.append(Vector2(x, y))
	# Seam fix
	var last_y = y_offset + noise.get_noise_1d(ctx.global_x + ctx.chunk_size) * noise_amp
	curve.append(Vector2(ctx.chunk_size, last_y))
	
	# Apply Tree Jitter
	var tree_curve = PackedVector2Array()
	var rng = ctx.rng
	
	for p in curve:
		var h_mod = rng.randf_range(-20, 20)
		tree_curve.append(Vector2(p.x, p.y + h_mod))
		
	# Build Poly
	var poly = Polygon2D.new()
	poly.color = color
	var pts = tree_curve.duplicate()
	pts.append(Vector2(tree_curve[-1].x, 2000))
	pts.append(Vector2(tree_curve[0].x, 2000))
	poly.polygon = pts
	ctx.parent_node.add_child(poly)
