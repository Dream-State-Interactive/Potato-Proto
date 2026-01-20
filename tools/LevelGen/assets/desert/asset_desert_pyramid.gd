@tool
class_name AssetDesertPyramid
extends ProcAsset

@export var lit_color: Color = Color(0.25, 0.2, 0.12)
@export var shadow_color: Color = Color(0.1, 0.08, 0.05)
@export var horizon_y: float = 200.0
@export var max_depth_y: float = 2000.0 
## How many pixels of "air" are allowed under the corners before spawn in cancelled | Lower values = stricter placement (flatter ground required)
@export var overhang_tolerance: float = 15.0


func generate(ctx: ProcContext):
	# Logic from reference _create_pyramid
	var h = ctx.rng.randf_range(250, 400)
	var aspect_ratio = ctx.rng.randf_range(1.6, 2.2)
	var w = h * aspect_ratio
	
	var x = ctx.rng.randf_range(100, ctx.chunk_size - 100)
	
	# 1. Project Local X -> Gameplay World X (Parallax Fix)
	var world_x = ctx.global_x + x
	var projected_gameplay_x = world_x / ctx.parallax_factor
	
	var has_override = ctx.get_active_override(projected_gameplay_x) != null
	
	# 2. Setup Defaults
	var final_pos = Vector2(x, horizon_y)
	if has_override:
		final_pos = Vector2(x, INF)
		
	var final_rot = 0.0
	var s = ctx.rng.randf_range(scale_min, scale_max)
	var final_scale = Vector2(s, s)
	
	# 3. Terrain Snapping
	if not ctx.terrain_curve.is_empty():
		var idx = int((x / ctx.chunk_size) * (ctx.terrain_curve.size() - 1))
		var params = _get_spawn_params(ctx, idx)
		
		if has_override or params.position.y < horizon_y:
			final_pos = params.position
			final_rot = params.rotation
			final_scale = params.scale

	# 4. Critical Checks
	if final_pos.y == INF: return
	if final_pos.y > max_depth_y: return
	if not is_slope_valid(final_rot): return

	# 5. Overhang/Bulge Check (check the terrain height at the left and right corners of the pyramid base)
	if not ctx.terrain_curve.is_empty():
		# Calculate the vector from center to right corner (half width), rotated by the slope
		var half_w_vec = Vector2(w * 0.5 * final_scale.x, 0).rotated(final_rot)
		
		# Get the X coordinates of the corners
		var left_x = final_pos.x - half_w_vec.x
		var right_x = final_pos.x + half_w_vec.x
		
		# Get the expected Y height of the corners (where the pyramid base is)
		var left_corner_y = final_pos.y - half_w_vec.y
		var right_corner_y = final_pos.y + half_w_vec.y

		# Sample the actual Terrain Y at those X locations
		var terrain_left_y = _get_y_on_curve(ctx, left_x)
		var terrain_right_y = _get_y_on_curve(ctx, right_x)
		
		# If Terrain Y > Corner Y, the ground is BELOW the corner (gap).
		if terrain_left_y != INF and (terrain_left_y - left_corner_y) > overhang_tolerance:
			return # Left side is floating
			
		if terrain_right_y != INF and (terrain_right_y - right_corner_y) > overhang_tolerance:
			return # Right side is floating

	# 6. Build Node
	var container = Node2D.new()
	container.position = final_pos
	container.rotation = final_rot
	container.scale = final_scale
	container.z_index = -10 
	ctx.parent_node.add_child(container)
	
	var split_x = ctx.rng.randf_range(-w * 0.1, w * 0.1)
	
	# Left Face (Shadow)
	var p_shadow = Polygon2D.new()
	p_shadow.color = shadow_color
	p_shadow.polygon = PackedVector2Array([
		Vector2(-w/2, 0), Vector2(0, -h), Vector2(split_x, 0) 
	])
	container.add_child(p_shadow)
	
	# Right Face (Lit)
	var p_lit = Polygon2D.new()
	p_lit.color = lit_color
	p_lit.polygon = PackedVector2Array([
		Vector2(split_x, 0), Vector2(0, -h), Vector2(w/2, 0)      
	])
	container.add_child(p_lit)

## Helper to find the Y value of the terrain at a specific local X
func _get_y_on_curve(ctx: ProcContext, local_x: float) -> float:
	# Clamp to ensure we don't look outside the chunk array
	if local_x < 0 or local_x > ctx.chunk_size:
		return INF # out-of-bounds
		
	# Map X to Index
	var step_size = ctx.chunk_size / float(ctx.terrain_curve.size() - 1)
	var idx = int(local_x / step_size)

	# Safety Clamp
	idx = clamp(idx, 0, ctx.terrain_curve.size() - 1)
	
	return ctx.terrain_curve[idx].y
