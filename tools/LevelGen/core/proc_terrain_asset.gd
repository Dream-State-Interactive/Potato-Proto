# src/tools/LevelGen/core/proc_terrain_asset.gd
class_name ProcTerrainAsset
extends ProcAsset

@export_group("Base Terrain Settings")
@export var color: Color = Color.DARK_GRAY
@export var depth: float = 2000.0 
@export var add_collision: bool = false

@export_subgroup("Noise")
@export var noise_freq: float = 0.001
@export var noise_amp: float = 150.0
@export var noise_seed: int = 1337

func generate(ctx: ProcContext):
	var noise = _get_noise(noise_seed, noise_freq, noise_amp)
	var curve_pts = PackedVector2Array()
	var step = 20
	var h_scale = ctx.shared_state.get("current_height_scale", 1.0)
	
	# 1. Start height calculation
	var start_noise_y = _get_height_at(ctx.global_x, noise)
	var start_target_y = _calculate_final_y(ctx.global_x, start_noise_y, ctx, h_scale)

	var vertical_shift = 0.0
	if not is_nan(ctx.snap_y):
		vertical_shift = ctx.snap_y - start_target_y

	# 2. Vertex Generation
	var num_steps = ceil(float(ctx.chunk_size) / float(step))
	var max_y_in_chunk = -1e7
	
	for i in range(num_steps + 1):
		var x = float(i) * step
		if x > ctx.chunk_size: x = float(ctx.chunk_size) 
		
		var world_x = ctx.global_x + x
		var noise_y = _get_height_at(world_x, noise)
		var final_y = _calculate_final_y(world_x, noise_y, ctx, h_scale) + vertical_shift
		
		curve_pts.append(Vector2(x, final_y))
		max_y_in_chunk = max(max_y_in_chunk, final_y)

	ctx.terrain_curve = curve_pts
	ctx.terrain_y_end = curve_pts[-1].y

	# 3. Visuals (Polygon2D)
	var poly = Polygon2D.new(); poly.color = color
	var draw_pts = curve_pts.duplicate()
	var bottom_y = max(depth, max_y_in_chunk + 2000.0)
	draw_pts.append(Vector2(curve_pts[-1].x, bottom_y))
	draw_pts.append(Vector2(curve_pts[0].x, bottom_y))
	poly.polygon = draw_pts
	ctx.parent_node.add_child(poly)
	
	# 4. Collision & Surface System
	if add_collision:
		var sb = StaticBody2D.new()
		sb.name = "ProcTerrainBody"
		
		if surface_definition:
			# A. Apply Physics (Friction/Bounce) to the body
			sb.physics_material_override = surface_definition.physics_material
			
			# B. Apply Audio/Visual Data via Metadata
			sb.set_meta(SurfaceManager.META_KEY, surface_definition)

		var col = CollisionPolygon2D.new()
		col.polygon = draw_pts
		sb.add_child(col)
		ctx.parent_node.add_child(sb)
	
	_post_process(ctx, curve_pts, poly)

func _calculate_final_y(world_x: float, noise_y: float, ctx: ProcContext, h_scale: float) -> float:
	var ov = ctx.get_active_override(world_x)
	if ov:
		var prog = ov.get_progress_at_world_x(world_x, ctx.chunk_size)
		var altitude = ov.get_height_at_progress(prog) * h_scale
		var mask = ov.get_blend_mask(world_x, ctx.chunk_size)
		
		var target_y = noise_y - altitude
		return lerp(noise_y, target_y, ov.blend_weight * mask)
	return noise_y

func _get_height_at(world_x: float, noise: FastNoiseLite) -> float:
	return y_offset + (noise.get_noise_1d(world_x) * noise_amp)

func _post_process(_ctx: ProcContext, _curve: PackedVector2Array, _poly: Polygon2D):
	pass
