@tool
class_name AssetCaveDetails
extends ProcAsset

@export_group("Visuals")
@export var crystal_color: Color = Color(0.0, 0.9, 1.0)
@export var spike_color: Color = Color(0.05, 0.1, 0.2)
@export var glow_intensity: float = 1.6

@export_group("Synchronization")
@export_subgroup("Must Match Terrain Asset")
@export var ceil_y: float = -200.0  # Default original
@export var amp: float = 120.0      # Default original
@export var noise_freq: float = 0.006
@export var noise_seed: int = 999
@export var floor_y_ref: float = 200.0


func generate(ctx: ProcContext):
	if ctx.terrain_curve.is_empty(): return
	
	# Generate specific noise for ceiling placement
	var noise = _get_noise(noise_seed, noise_freq, amp)
	
	for i in range(density):
		var idx = ctx.rng.randi_range(2, ctx.terrain_curve.size() - 3)
		var pos_floor = ctx.terrain_curve[idx]
		
		# Calculate Ceiling Y at this X
		var gx = ctx.global_x + pos_floor.x
		var spike_val = sin(gx * 0.12) * 20.0
		
		# Use exported ceil_y variable
		var current_ceil_y = ceil_y
		if not is_nan(ctx.snap_y):
			
			var _floor_calc = 600.0 + (noise.get_noise_1d(gx) * amp) - spike_val # 600 is default floor
			pass

		var cy = current_ceil_y + (noise.get_noise_1d(gx + 5000.0) * amp) + spike_val
		
		# Apply Snapping Shift if valid
		if not is_nan(ctx.snap_y):
			var shift = pos_floor.y - _calc_expected_floor(gx, noise, spike_val)
			cy += shift

		var pos_ceil = Vector2(pos_floor.x, cy)
		
		if ctx.rng.randf() < 0.3:
			_add_crystal(ctx.parent_node, pos_floor, ctx.rng)
			
		if ctx.rng.randf() < 0.4:
			_add_spike(ctx.parent_node, pos_ceil, ctx.rng)


func _calc_expected_floor(gx: float, noise: FastNoiseLite, spike: float) -> float:
	return floor_y_ref + (noise.get_noise_1d(gx) * amp) - spike


func _add_spike(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator):
	var spike = Polygon2D.new()
	spike.color = spike_color
	var w = rng.randf_range(40, 90)
	var h = rng.randf_range(150, 350)
	spike.polygon = PackedVector2Array([Vector2(-w/2, 0), Vector2(w/2, 0), Vector2(0, h)])
	spike.position = pos + Vector2(0, -35)
	spike.z_index = -5 
	parent.add_child(spike)

func _add_crystal(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator):
	var c = Polygon2D.new()
	c.color = crystal_color * glow_intensity
	var s = rng.randf_range(8, 14)
	c.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s/2, 0), Vector2(0, s), Vector2(-s/2, 0)])
	c.position = pos + Vector2(0, -5)
	c.z_index = 5
	parent.add_child(c)
