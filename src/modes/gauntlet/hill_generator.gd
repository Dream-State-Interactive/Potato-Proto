# src/modes/gauntlet/hill_generator.gd
@tool
extends Node2D

# === Collectible Config ===
const SPAWN_STARCH_POINTS_EVERY_N_POINTS: int = 3
const STARCH_POINT := preload("res://src/collectibles/starch_point.tscn")
const WaveHillAnimator := preload("res://src/modes/gauntlet/wave_hill_animator.gd")
const EPS: float = 0.001

# === Export Variables ===
@export var visual_bake_interval: float = 8.0      # Resolution of visual hills
@export var collision_bake_interval: float = 18.0  # Resolution of collision hills
@export var simplify_epsilon_px: float = 4.0       # Simplification tolerance for collision (px)
@export var max_collision_vertices: int = 512      # Safety cap for collision vertex count

var generate_backwards = false
var hill: Node2D
var ground_body: StaticBody2D
var collision_polygon: CollisionPolygon2D

func generate_collectibles(spawn_points: PackedVector2Array) -> void:
	if not generate_backwards:
		var i: int = 0
		for p in spawn_points:
			if i % SPAWN_STARCH_POINTS_EVERY_N_POINTS == 0:
				var starch: Node2D = STARCH_POINT.instantiate()
				hill.add_child(starch)
				starch.position = p + Vector2(0.0, -100.0)
			i += 1

func _generate_flat_line(params: Dictionary) -> Dictionary:
	hill = Node2D.new()
	hill.name = "FlatLineContainer"

	ground_body = StaticBody2D.new()
	collision_polygon = CollisionPolygon2D.new()
	var visual_polygon: Polygon2D = Polygon2D.new()
	collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS

	var length: float = float(params.get("length", 1200.0))
	# A flat line has no amplitude, but we need a thickness for the polygon
	var thickness: float = 200.0

	# The surface is just two points
	var surface_points: PackedVector2Array = [Vector2.ZERO, Vector2(length, 0.0)]

	# Build visual polygon
	var fill_visual: PackedVector2Array = PackedVector2Array()
	fill_visual.append(Vector2(0.0, 0.0))
	fill_visual.append(Vector2(length, 0.0))
	fill_visual.append(Vector2(length, thickness))
	fill_visual.append(Vector2(0.0, thickness))
	visual_polygon.polygon = fill_visual
	visual_polygon.color = params.get("color", Color.DARK_GREEN)

	# Build collision polygon (can be the same as visual for a simple rectangle)
	collision_polygon.polygon = fill_visual

	# Assemble final hill node
	ground_body.add_child(collision_polygon)
	hill.add_child(visual_polygon)
	hill.add_child(ground_body)

	var end_pos: Vector2 = Vector2(length, 0.0)

	return {
		"node": hill,
		"end_position": end_pos,
		"surface_points": surface_points,
		"spawn_points": surface_points # Can use surface points for spawning
	}


func generate_hill(params: Dictionary, noise_seed: int, is_generating_backwards: bool) -> Dictionary:
	generate_backwards = is_generating_backwards
	var generator_type: int = params.get("generator_type", HillGenerationParams.GeneratorType.NOISE_HILL)

	match generator_type:
		HillGenerationParams.GeneratorType.FLAT_LINE:
			return _generate_flat_line(params)
		_:
			# --- Root node for this hill segment ---
			hill = Node2D.new()
			hill.name = "HillContainer"
			
			# Physics & visuals
			ground_body = StaticBody2D.new()
			collision_polygon = CollisionPolygon2D.new()
			var visual_polygon: Polygon2D = Polygon2D.new()
			collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
			
			# --- Noise-based height function ---
			var noise: FastNoiseLite = FastNoiseLite.new()
			noise.seed = noise_seed
			noise.frequency = float(params.get("frequency", 0.0015))
			noise.fractal_octaves = 1
			
			# --- Shape params ---
			var length: float    = float(params.get("length", 1200.0))
			var amplitude: float = float(params.get("amplitude", 60.0))
			var slope: float     = float(params.get("slope", 0.2))
			var steepness_increase: float = float(params.get("steepness_increase", 0.00005))
			# For bowl/crest shapes, we want the global trend mostly flat so
			# the start and end are near the same height.
			if generator_type == HillGenerationParams.GeneratorType.VALLEY \
			or generator_type == HillGenerationParams.GeneratorType.HILL \
			or generator_type == HillGenerationParams.GeneratorType.WAVE:
				slope = 0.0
				steepness_increase = 0.0
			
			var base_y: float = 0.0 # Each segment starts at its own local origin
			
			# Control vs visual density
			var control_step: float = float(params.get("control_step", 140.0))
			var vis_bake: float = float(params.get("visual_bake_interval", visual_bake_interval))
			var col_bake: float = float(params.get("collision_bake_interval", collision_bake_interval))
			var simplify_eps: float = float(params.get("simplify_epsilon_px", simplify_epsilon_px))
			var max_col_vertices: int = int(params.get("max_collision_vertices", max_collision_vertices))
			
			# ----- shape profile selection -----
			var shape_profile: Callable = func(t: float) -> float:
				return 0.0
			
			match generator_type:
				HillGenerationParams.GeneratorType.NOISE_HILL:
					shape_profile = func(t: float) -> float:
						return 0.0
				HillGenerationParams.GeneratorType.VALLEY:
					# 0 → dip → 0 (bowl), +Y is down
					shape_profile = func(t: float) -> float:
						return sin(PI * t)  # 0..1..0
				HillGenerationParams.GeneratorType.HILL:
					# 0 → crest → 0 (bump up)
					shape_profile = func(t: float) -> float:
						return -sin(PI * t)
				HillGenerationParams.GeneratorType.WAVE:
					# Wavy roller-coaster; two oscillations
					shape_profile = func(t: float) -> float:
						return 0.7 * sin(TAU * t * 2.0)
				HillGenerationParams.GeneratorType.UPHILL:
					shape_profile = func(t: float) -> float:
						return 0.0
				_:
					shape_profile = func(t: float) -> float:
						return 0.0
			
			# Flip global trend for uphill so potato climbs instead of descending.
			if generator_type == HillGenerationParams.GeneratorType.UPHILL:
				slope = -abs(slope)
				steepness_increase = -abs(steepness_increase) * 0.25
			
			var shape_amplitude: float = amplitude
			var noise_amplitude: float = amplitude * 0.5
			
			if generator_type == HillGenerationParams.GeneratorType.WAVE:
				noise_amplitude = amplitude * 0.25   # softer chop, more swell
			
			# --- Height functions (patched) ---
			var y_raw: Callable = func(x: float) -> float:
				var t: float = (x / length) if length > 0.0 else 0.0
				# 1. Global trend: downhill or uphill
				var global_trend: float = x * slope + x * x * steepness_increase
				# 2. Macro shape: hill/valley/wave/etc.
				var shape_offset: float = float(shape_profile.call(t)) * shape_amplitude
				# 3. Noise for bumps & texture.
				var noise_component: float = noise.get_noise_1d(x) * noise_amplitude
				return base_y + global_trend + shape_offset + noise_component
			
			# Normalize so the seam starts exactly at y=0 (relative to this segment's origin).
			var y0: float = float(y_raw.call(0.0))
			var yL: float = float(y_raw.call(length))

			var y_at: Callable = func(x: float) -> float:
				return float(y_raw.call(x)) - y0

			# For WAVE, also force the end back to baseline by removing a linear ramp
			if generator_type == HillGenerationParams.GeneratorType.WAVE and length > 0.0:
				var total_delta: float = yL - y0
				y_at = func(x: float) -> float:
					var t_local: float = x / length
					var base: float = float(y_raw.call(x)) - y0
					# Subtract a linear ramp so y_at(0) = 0 and y_at(length) = 0
					return base - total_delta * t_local

				
			# Bezier handle length: shorter on sharp curves
			var handle_len_fn: Callable = func(x: float, y_prev: float, y: float, y_next: float) -> float:
				var local_step: float = control_step
				var base_len: float   = 0.45 * local_step
				var dy1: float = (y - y_prev)
				var dy2: float = (y_next - y)
				var curvature: float = abs(dy2 - dy1) / float(max(1.0, local_step))
				var k: float = 1.0 / (1.0 + curvature * 1.2)
				return clamp(base_len * k, 0.1 * control_step, 0.5 * control_step)
				
			# --- Sample control points ---
			var curve: Curve2D = Curve2D.new()
			var spawn_points: PackedVector2Array = PackedVector2Array()
			var dx: float = control_step * 0.5

			var x: float = 0.0
			while x <= length:
				var y: float      = float(y_at.call(x))
				var y_prev: float = float(y_at.call(max(0.0, x - dx)))
				var y_next: float = float(y_at.call(min(length, x + dx)))
				var tangent: Vector2 = Vector2(dx * 2.0, (y_next - y_prev)).normalized()
				var hlen: float = float(handle_len_fn.call(x, y_prev, y, y_next))
				curve.add_point(Vector2(x, y), -tangent * hlen, tangent * hlen)
				spawn_points.append(Vector2(x, y))
				x += control_step
				
			# Force last point at hill end
			if curve.get_point_count() == 0 or curve.get_point_position(curve.get_point_count() - 1).x < length:
				var y_end: float      = float(y_at.call(length))
				var y_prev_end: float = float(y_at.call(max(0.0, length - dx)))
				var tan_end: Vector2  = Vector2(dx, (y_end - y_prev_end)).normalized()
				var hlen_end: float = float(handle_len_fn.call(length, y_prev_end, y_end, y_end))
				curve.add_point(Vector2(length, y_end), -tan_end * hlen_end, tan_end * hlen_end)
				spawn_points.append(Vector2(length, y_end))

			# --- Bake two resolutions: one for visuals, one for collisions ---
			curve.bake_interval = vis_bake
			var surface_points_visual: PackedVector2Array = curve.get_baked_points()
			
			# Ensure the hill's surface never goes backward on the X-axis
			if surface_points_visual.size() > 1:
				var filtered_visual_points := PackedVector2Array()
				filtered_visual_points.append(surface_points_visual[0])
				var last_x: float = surface_points_visual[0].x
				for i in range(1, surface_points_visual.size()):
					if surface_points_visual[i].x > last_x:
						filtered_visual_points.append(surface_points_visual[i])
						last_x = surface_points_visual[i].x
				surface_points_visual = filtered_visual_points
			
			curve.bake_interval = col_bake
			var surface_points_collision: PackedVector2Array = curve.get_baked_points()
			
			# --- Simplify/cap collision points ---
			if simplify_eps > 0.0:
				surface_points_collision = Algorithms._rdp(surface_points_collision, simplify_eps)
			if surface_points_collision.size() > max_col_vertices and max_col_vertices > 2:
				var reduced := PackedVector2Array()
				var step: float = float(surface_points_collision.size() - 1) / float(max_col_vertices - 1)
				var t_red: float = 0.0
				while int(floor(t_red)) < surface_points_collision.size():
					reduced.append(surface_points_collision[int(floor(t_red))])
					t_red += step
				if reduced[reduced.size() - 1] != surface_points_collision[surface_points_collision.size() - 1]:
					reduced.append(surface_points_collision[surface_points_collision.size() - 1])
				surface_points_collision = reduced
				
			# --- Seam stitch (forces first point at y=0) ---
			var poly_surface_visual: PackedVector2Array = surface_points_visual.duplicate()
			if poly_surface_visual.size() >= 1 and abs(poly_surface_visual[0].y) > 0.001:
				poly_surface_visual.insert(0, Vector2(0.0, 0.0))
			var poly_surface_collision: PackedVector2Array = surface_points_collision.duplicate()
			if poly_surface_collision.size() >= 1 and abs(poly_surface_collision[0].y) > 0.001:
				poly_surface_collision.insert(0, Vector2(0.0, 0.0))
				
			# --- Build visual polygon (high res, pretty) ---
			var fill_visual: PackedVector2Array = PackedVector2Array()
			fill_visual.append_array(poly_surface_visual)
			if fill_visual.size() >= 2:
				var max_y_v: float = -INF
				for p in poly_surface_visual:
					max_y_v = max(max_y_v, p.y)
				var bottom_y_v: float = max(amplitude * 2.2, max_y_v + amplitude * 0.6)
				fill_visual.append(Vector2(poly_surface_visual[fill_visual.size() - 1].x, bottom_y_v))
				fill_visual.append(Vector2(poly_surface_visual[0].x, bottom_y_v))
			visual_polygon.polygon = fill_visual
			visual_polygon.color = params.get("color", Color.DARK_GREEN)
			
			# --- Build collision polygon (simplified) ---
			var fill_collision: PackedVector2Array = PackedVector2Array()
			fill_collision.append_array(poly_surface_collision)
			if fill_collision.size() >= 2:
				var max_y_c: float = -INF
				for p in poly_surface_collision:
					max_y_c = max(max_y_c, p.y)
				var bottom_y_c: float = max(amplitude * 2.2, max_y_c + amplitude * 0.6)
				fill_collision.append(Vector2(poly_surface_collision[fill_collision.size() - 1].x, bottom_y_c))
				fill_collision.append(Vector2(poly_surface_collision[0].x, bottom_y_c))
			collision_polygon.polygon = fill_collision

# ============================================================================================
			# --- Attach runtime wave animator for WAVE segments ---
			if generator_type == HillGenerationParams.GeneratorType.WAVE:
				var animator: WaveHillAnimator = WaveHillAnimator.new()
				# You can tweak these or pull from params if you want per-theme control
				animator.wave_amplitude = amplitude * 0.4
				animator.wave_speed = 1.0
				hill.add_child(animator)
				# Note: poly_surface_visual / poly_surface_collision are the top surface points
				animator.setup(visual_polygon, collision_polygon, poly_surface_visual, poly_surface_collision)
# ============================================================================================

			# --- Starch collectibles ---
			generate_collectibles(spawn_points)

			# --- Assemble final hill node ---
			ground_body.add_child(collision_polygon)
			hill.add_child(visual_polygon)
			hill.add_child(ground_body)
			
			# End position = last baked visual point (for chaining hills)
			var end_pos: Vector2 = surface_points_visual[surface_points_visual.size() - 1] if surface_points_visual.size() > 0 else Vector2(length, base_y + length * slope)

			return {
				"node": hill,
				"end_position": end_pos,
				"surface_points": surface_points_visual,
				"spawn_points": spawn_points
			}
# ------------------------------------------------------------------------------
# References / Tutorials / Resources:
#
# Procedural Terrain & Noise:
# - Godot Docs: Using FastNoiseLite for procedural content
#   https://docs.godotengine.org/en/4.4/classes/class_fastnoiselite.html
# - Using FastNoiseLite to Procedurally Generate Shapes
#   https://www.youtube.com/watch?v=wdHU5D-pvvo
# - Red Blob Games: Noise-based terrain generation (excellent deep dive)
#   https://www.redblobgames.com/maps/terrain-from-noise/
#
# Curve2D and Bezier Handles:
# - Godot Docs: Curve2D class reference
#   https://docs.godotengine.org/en/stable/classes/class_curve2d.html
# - Catlike Coding: Bezier curve tutorials (Unity, but math is universal)
#   https://catlikecoding.com/unity/tutorials/curves-and-splines/
#
# Polygon Construction & Collision:
# - Godot Docs: CollisionPolygon2D
#   https://docs.godotengine.org/en/stable/classes/class_collisionpolygon2d.html
# - Godot Docs: Polygon2D
#   https://docs.godotengine.org/en/stable/classes/class_polygon2d.html
# - Triangulation theory (why we close the polygon to the bottom)
#   https://en.wikipedia.org/wiki/Polygon_triangulation
#
# Simplifying Geometry:
# - Ramer–Douglas–Peucker algorithm (polyline simplification)
#   https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm
# - Implementation notes for reducing vertices in game geometry
#   https://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
#
# Procedural Generation Patterns:
# - Red Blob Games: “Polygonal Map Generation” (conceptual design patterns)
#   https://www.redblobgames.com/maps/mapgen2.html
# - Amit Patel’s blog on game AI and procedural systems
#   https://www.redblobgames.com/
#
# Godot Best Practices:
# - Godot Docs: @tool scripts and editor hints
#   https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html
# - Godot Docs: PackedVector2Array (efficient point storage)
#   https://docs.godotengine.org/en/stable/classes/class_packedvector2array.html
#
# General Game Math:
# - Fundamentals of vector math in games (Dot products, projections)
#   https://gamemath.com/book/
# - Gaffer on Games: Fix Your Timestep (why stability matters in physics)
#   https://gafferongames.com/post/fix_your_timestep/
#
# ------------------------------------------------------------------------------
