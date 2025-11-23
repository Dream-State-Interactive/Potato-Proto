# src/modes/gauntlet/wave_hill_animator.gd
extends Node

@export var wave_speed: float = 1.0          # how fast the wave animates
@export var wave_amplitude: float = 30.0     # peak vertical offset in pixels

var visual_polygon: Polygon2D
var collision_polygon: CollisionPolygon2D

var top_visual_points: PackedVector2Array
var top_collision_points: PackedVector2Array

var segment_length: float = 1.0
var time_accum: float = 0.0

func setup(
	_visual_polygon: Polygon2D,
	_collision_polygon: CollisionPolygon2D,
	_top_visual_points: PackedVector2Array,
	_top_collision_points: PackedVector2Array
) -> void:
	visual_polygon = _visual_polygon
	collision_polygon = _collision_polygon

	# Store the "rest pose" of the top surfaces
	top_visual_points = _top_visual_points.duplicate()
	top_collision_points = _top_collision_points.duplicate()

	if top_visual_points.size() >= 2:
		segment_length = top_visual_points[top_visual_points.size() - 1].x - top_visual_points[0].x
	else:
		segment_length = 1.0  # avoid division by zero

func _process(delta: float) -> void:
	if visual_polygon == null or collision_polygon == null:
		return
	if segment_length <= 0.0:
		return

	# time_accum = elapsed seconds
	time_accum += delta

	# wave_speed = cycles per second
	var phase_base: float = time_accum * wave_speed * TAU

	# Animate visual polygon
	var v_poly: PackedVector2Array = visual_polygon.polygon
	var top_count_v: int = top_visual_points.size()
	if v_poly.size() >= top_count_v and top_count_v > 1:
		var x_start_v: float = top_visual_points[0].x
		for i in range(top_count_v):
			var base: Vector2 = top_visual_points[i]
			var s: float = (base.x - x_start_v) / segment_length  # 0..1 across segment
			var envelope: float = sin(PI * s)                      # 0 at ends, 1 in middle

			# phase moves over time; s*TAU shifts wave along the segment
			var offset: float = sin(phase_base + s * TAU) * wave_amplitude * envelope

			var p: Vector2 = v_poly[i]
			p.y = base.y + offset
			v_poly[i] = p

		visual_polygon.polygon = v_poly

	# Animate collision polygon (same logic)
	var c_poly: PackedVector2Array = collision_polygon.polygon
	var top_count_c: int = top_collision_points.size()
	if c_poly.size() >= top_count_c and top_count_c > 1:
		var x_start_c: float = top_collision_points[0].x
		for i in range(top_count_c):
			var base_c: Vector2 = top_collision_points[i]
			var s_c: float = (base_c.x - x_start_c) / segment_length
			var envelope_c: float = sin(PI * s_c)
			
			var offset_c: float = sin(phase_base + s_c * TAU) * wave_amplitude * envelope_c

			var pc: Vector2 = c_poly[i]
			pc.y = base_c.y + offset_c
			c_poly[i] = pc

		collision_polygon.polygon = c_poly
