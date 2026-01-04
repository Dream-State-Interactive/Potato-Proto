@tool
class_name AssetDesertVegetation
extends ProcAsset

@export var trunk_color: Color = Color(0.2, 0.15, 0.1)
@export var leaf_color: Color = Color(0.15, 0.25, 0.15)
@export var shrub_color: Color = Color(0.22, 0.18, 0.1)
@export var brightness_mult: float = 0.0 

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 5: return
	
	for i in range(density):
		var idx = ctx.rng.randi_range(2, ctx.terrain_curve.size()-3)
		var params = _get_spawn_params(ctx, idx)
		
		if ctx.rng.randf() < 0.4:
			_spawn_joshua_tree(ctx, params)
		else:
			_spawn_shrub(ctx, params)

func _spawn_shrub(ctx: ProcContext, params: Dictionary):
	var shrub = Polygon2D.new()
	shrub.color = shrub_color.darkened(brightness_mult)
	shrub.z_index = -5 
	shrub.position = params.position
	shrub.rotation = params.rotation
	shrub.scale = params.scale
	
	var w = ctx.rng.randf_range(30, 50)
	var h = ctx.rng.randf_range(20, 40)
	
	var pts = PackedVector2Array()
	var segments = 8
	for i in range(segments + 1):
		var angle = PI + (float(i)/segments) * PI 
		pts.append(Vector2(cos(angle) * w * 0.5, sin(angle) * h * ctx.rng.randf_range(0.8, 1.2)))
	
	shrub.polygon = pts
	ctx.parent_node.add_child(shrub)

func _spawn_joshua_tree(ctx: ProcContext, params: Dictionary):
	var tree = Node2D.new()
	tree.position = params.position
	tree.rotation = params.rotation
	tree.scale = params.scale
	tree.z_index = -5
	ctx.parent_node.add_child(tree)
	
	var h = ctx.rng.randf_range(60, 100)
	var w = ctx.rng.randf_range(8, 12)
	
	# --- Trunk ---
	var trunk = Polygon2D.new()
	trunk.color = trunk_color.darkened(brightness_mult)
	trunk.polygon = PackedVector2Array([
		Vector2(-w/2, 0), 
		Vector2(-w/2, -h), 
		Vector2(w/2, -h), 
		Vector2(w/2, 0)
	])
	tree.add_child(trunk)
	
	# Add spikes to the main trunk top
	_add_spikes(tree, Vector2(0, -h), w, ctx.rng)
	
	# --- Branches ---
	var branches = ctx.rng.randi_range(1, 2)
	for i in range(branches):
		var b_h_start = -h * ctx.rng.randf_range(0.4, 0.7)
		var b_len = h * ctx.rng.randf_range(0.3, 0.5)
		var dir = 1 if ctx.rng.randf() > 0.5 else -1
		var angle = deg_to_rad(ctx.rng.randf_range(30, 60)) * dir
		
		# Calculate end position relative to tree center
		var b_end = Vector2(0, b_h_start) + Vector2(sin(angle), -cos(angle)) * b_len
		
		var branch = Line2D.new()
		branch.default_color = trunk_color.darkened(brightness_mult)
		branch.width = w * 0.8
		branch.points = PackedVector2Array([Vector2(0, b_h_start), b_end])
		tree.add_child(branch)
		
		# Add spikes to the branch tip
		_add_spikes(tree, b_end, w, ctx.rng)

func _add_spikes(parent: Node, pos: Vector2, _ref_w: float, _rng: RandomNumberGenerator):
	var spikes = Polygon2D.new()
	spikes.color = leaf_color.darkened(brightness_mult)
	spikes.position = pos
	
	var pts = PackedVector2Array()
	var count = 8
	var rad = 15.0 
	for i in range(count * 2):
		var angle = (float(i) / (count * 2)) * TAU
		var r = rad if i % 2 == 0 else rad * 0.3
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	spikes.polygon = pts
	parent.add_child(spikes)
