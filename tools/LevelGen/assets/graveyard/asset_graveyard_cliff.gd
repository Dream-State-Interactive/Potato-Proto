# ####################### #
# THIS IS FOREGROUND ONLY
# ####################### #
@tool
class_name AssetGraveyardCliff
extends ProcAsset

@export var color: Color = Color(0.04, 0.05, 0.06)
@export var highlight: Color = Color(0.10, 0.11, 0.12)
@export var top_offset: float = 165.0
@export var amp: float = 46.0
@export var freq: float = 0.010
@export var seed_val: int = 505

func generate(ctx: ProcContext):
	if ctx.terrain_curve.is_empty():
		# This happens if Cliff generates before Terrain, or on a layer with no terrain.
		return 

	var noise = _get_noise(seed_val, freq, amp)
	var edge = PackedVector2Array()
	var step = 26
	var num_steps = ceil(float(ctx.chunk_size) / float(step))
	
	# Base Y from terrain start
	var base_y = ctx.terrain_curve[0].y + top_offset
	
	for i in range(num_steps + 1):
		var x = float(i) * step
		if x > ctx.chunk_size: x = float(ctx.chunk_size)
		var gx = ctx.global_x + x
		
		var nn = noise.get_noise_1d(gx * 1.3)
		var wob = sin(gx * freq) * amp
		var y = base_y + (nn * amp) + wob
		edge.append(Vector2(x, y))
		
	var poly = Polygon2D.new(); poly.z_index = 6; poly.color = color
	var pts = edge.duplicate()
	pts.append(Vector2(edge[-1].x, 2400)); pts.append(Vector2(edge[0].x, 2400))
	poly.polygon = pts; ctx.parent_node.add_child(poly)
	
	var hl = Line2D.new(); hl.z_index = 7; hl.width = 5.0; hl.default_color = highlight
	hl.points = edge; ctx.parent_node.add_child(hl)
