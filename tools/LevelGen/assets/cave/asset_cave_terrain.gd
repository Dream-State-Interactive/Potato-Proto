@tool
class_name AssetCaveTerrain
extends ProcAsset

@export_group("Visuals")
@export var color: Color = Color(0.02, 0.05, 0.1)
@export var z_index: int = 0
@export var show_outlines: bool = true
@export var outline_color: Color = Color(0.1, 0.15, 0.2)

@export_group("Generation")
@export var floor_y: float = 200.0
@export var ceil_y: float = -600.0
@export var amp: float = 120.0
@export var noise_freq: float = 0.006
@export var noise_seed: int = 999

@export_subgroup("Cave Wander (Tunnel Winding)")
## Makes the entire tunnel move up and down over long distances
@export var wander_enabled: bool = false 
@export var wander_freq: float = 0.001
@export var wander_amp: float = 300.0
@export var wander_seed: int = 12345

@export_group("Physics")
@export var add_collision: bool = false

func generate(ctx: ProcContext):
	var noise = _get_noise(noise_seed, noise_freq, amp)
	
	# Separate noise for the "Wander" (Path of the tunnel)
	var wander_noise = null
	if wander_enabled:
		wander_noise = _get_noise(wander_seed, wander_freq, wander_amp)
	
	var f_curve = PackedVector2Array()
	var c_curve = PackedVector2Array()
	var step = 40
	
	# Calculate shift based on where the floor WOULD naturally start at x=0
	var shift = 0.0
	if not is_nan(ctx.snap_y):
		var natural_floor_start = _get_floor_y(0.0, ctx.global_x, noise, wander_noise)
		shift = ctx.snap_y - natural_floor_start
	
	# Loop with seam fix
	var num_steps = ceil(float(ctx.chunk_size) / float(step))
	for i in range(num_steps + 1):
		var x = float(i) * step
		if x > ctx.chunk_size: x = float(ctx.chunk_size)
		var gx = ctx.global_x + x
		
		# Floor
		var fy = _get_floor_y(x, gx, noise, wander_noise) + shift
		
		# Ceiling
		# We apply the same shift AND the same wander to the ceiling
		var spike = sin(gx * 0.12) * 20.0
		var raw_ceil = ceil_y + (noise.get_noise_1d(gx + 5000.0) * amp) + spike
		
		if wander_noise:
			var wander = wander_noise.get_noise_1d(gx) * wander_amp
			raw_ceil += wander
			
		var cy = raw_ceil + shift
		
		f_curve.append(Vector2(x, fy))
		c_curve.append(Vector2(x, cy))
	
	# Save floor for next chunk
	ctx.terrain_curve = f_curve
	ctx.terrain_y_end = f_curve[-1].y
	
	# Build Meshes
	_build_poly(ctx.parent_node, f_curve, 4000.0)  # Floor fills down
	_build_poly(ctx.parent_node, c_curve, -4000.0) # Ceiling fills up
	
	if add_collision:
		# Floor collision
		var sb_floor = StaticBody2D.new()
		sb_floor.name = "FloorCollision"
		var col_floor = CollisionPolygon2D.new()
		var col_pts_floor = f_curve.duplicate()
		col_pts_floor.append(Vector2(f_curve[-1].x, 4000))
		col_pts_floor.append(Vector2(f_curve[0].x, 4000))
		col_floor.polygon = col_pts_floor
		sb_floor.add_child(col_floor)
		ctx.parent_node.add_child(sb_floor)

		# Ceiling collision
		var sb_ceil = StaticBody2D.new()
		sb_ceil.name = "CeilingCollision"
		var col_ceil = CollisionPolygon2D.new()
		var col_pts_ceil = c_curve.duplicate()
		col_pts_ceil.append(Vector2(c_curve[-1].x, -4000))
		col_pts_ceil.append(Vector2(c_curve[0].x, -4000))
		col_ceil.polygon = col_pts_ceil
		sb_ceil.add_child(col_ceil)
		ctx.parent_node.add_child(sb_ceil)

# Helper for floor calc to reuse in snap logic
func _get_floor_y(local_x: float, global_x: float, noise: FastNoiseLite, wander_noise: FastNoiseLite) -> float:
	var n = noise.get_noise_1d(global_x)
	var spike = sin(global_x * 0.12) * 20.0
	var y = floor_y + (n * amp) - spike
	
	if wander_noise:
		y += wander_noise.get_noise_1d(global_x) * wander_amp
		
	return y

func _build_poly(parent: Node2D, curve: PackedVector2Array, fill_y: float):
	# Shadow/Depth Layer
	var shadow = Polygon2D.new()
	shadow.color = color.darkened(0.6)
	var s_pts = curve.duplicate()
	var offset = Vector2(0, 15 if fill_y > 0 else -15)
	for i in range(s_pts.size()): s_pts[i] += offset
	s_pts.append(Vector2(curve[-1].x, fill_y))
	s_pts.append(Vector2(curve[0].x, fill_y))
	shadow.polygon = s_pts
	shadow.z_index = z_index - 1
	parent.add_child(shadow)

	# Main Poly
	var poly = Polygon2D.new()
	poly.color = color
	poly.z_index = z_index
	var pts = curve.duplicate()
	pts.append(Vector2(curve[-1].x, fill_y))
	pts.append(Vector2(curve[0].x, fill_y))
	poly.polygon = pts
	parent.add_child(poly)
	
	# Rim Light
	if show_outlines:
		var rim = Line2D.new()
		rim.points = curve
		rim.width = 4.0
		rim.default_color = outline_color
		rim.z_index = z_index + 1
		parent.add_child(rim)
