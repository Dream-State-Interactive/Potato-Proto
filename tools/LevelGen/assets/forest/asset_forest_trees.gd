@tool
class_name AssetForestTrees
extends ProcAsset

@export var color: Color = Color(0.02, 0.04, 0.02)
@export var z_index_offset: int = 0

@export_group("Style")
@export var use_sp_trees: bool = false

@export_subgroup("Standard Pine Settings")
@export var min_height: float = 300.0
@export var max_height: float = 600.0

@export_subgroup("SP Tree Settings")
@export var sp_min_base: float = 70.0
@export var sp_max_base: float = 140.0
@export var sp_min_h: float = 90.0
@export var sp_max_h: float = 150.0
@export var sp_depth_extension: float = 500.0

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 2: return
	
	if use_sp_trees:
		_gen_sp_trees(ctx)
	else:
		_gen_standard_trees(ctx)

func _gen_standard_trees(ctx: ProcContext):
	for i in range(density):
		# Pick a random point on the terrain curve
		var idx = ctx.rng.randi_range(0, ctx.terrain_curve.size() - 2)
		var params = _get_spawn_params(ctx, idx)
		
		var w = 100.0 * ctx.rng.randf_range(0.8, 1.2)
		var h = ctx.rng.randf_range(min_height, max_height)
		
		var t = Polygon2D.new()
		t.color = color
		t.position = params.position
		t.rotation = params.rotation
		t.scale = params.scale
		t.polygon = _get_jagged_pine_shape(w, h)
		t.z_index = z_index_offset
		ctx.parent_node.add_child(t)

func _gen_sp_trees(ctx: ProcContext):
	for i in range(density):
		var idx = ctx.rng.randi_range(0, ctx.terrain_curve.size() - 2)
		var params = _get_spawn_params(ctx, idx)
		
		var w = ctx.rng.randf_range(sp_min_base, sp_max_base)
		var h = ctx.rng.randf_range(sp_min_h, sp_max_h)
		
		var tri = Polygon2D.new()
		tri.color = color
		tri.z_index = z_index_offset
		tri.position = params.position
		tri.rotation = params.rotation
		tri.scale = params.scale
		
		# The polygon points are local to the node's position.
		# Use 0 as the "ground level" since params.position handles the Y.
		tri.polygon = PackedVector2Array([
			Vector2(-w*0.5, sp_depth_extension),
			Vector2(-w*0.5, 0),
			Vector2(0, -h),
			Vector2(w*0.5, 0),
			Vector2(w*0.5, sp_depth_extension)
		])
		
		ctx.parent_node.add_child(tri)

func _get_jagged_pine_shape(w: float, h: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var hw = w * 0.5
	var segs = 5
	var seg_h = h / segs

	pts.append(Vector2(-hw * 0.5, 0))

	for i in range(segs):
		var yb = -(i * seg_h)
		var yp = -((i + 1) * seg_h)
		var xo = -hw * (1.0 - float(i)/segs)
		pts.append(Vector2(xo, yb - 10))
		if i < segs - 1:
			pts.append(Vector2(xo * 0.4, yp + 20))

	pts.append(Vector2(0, -h))

	for i in range(segs - 1, -1, -1):
		var yb = -(i * seg_h)
		var yp = -((i + 1) * seg_h)
		var xo = hw * (1.0 - float(i)/segs)
		if i < segs - 1:
			pts.append(Vector2(xo * 0.4, yp + 20))
		pts.append(Vector2(xo, yb - 10))

	pts.append(Vector2(hw * 0.5, 0))
	return pts
