@tool
class_name BarnHayPile
extends Node2D

var outline_color: Color
var hay_color: Color
var outline_px: float = 3.0

var W: float = 190.0
var H: float = 78.0

var _mound: PackedVector2Array
var _shadow: PackedVector2Array
var _base: PackedVector2Array
var _mid: PackedVector2Array
var _top: PackedVector2Array

var _strokes_pts: Array[PackedVector2Array] = []
var _strokes_col: Array[Color] = []
var _strokes_w: PackedFloat32Array = PackedFloat32Array()

var _edge_pts: Array[PackedVector2Array] = []
var _edge_col: Array[Color] = []
var _edge_w: PackedFloat32Array = PackedFloat32Array()

var _ao_rect: Rect2
var _ao_col := Color(0, 0, 0, 0.18)

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

func generate(seed_val: int) -> void:
	_rng.seed = seed_val
	_noise.seed = seed_val
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.055

	_build_mound()
	_build_layers()
	_build_interior_strokes()
	queue_redraw()

func _build_mound() -> void:
	var base_y: float = 0.0
	var top_count: int = 26
	var top_pts := PackedVector2Array()
	
	for i in range(top_count + 1):
		var t: float = float(i) / float(top_count)
		var x: float = lerpf(-W * 0.5, W * 0.5, t)
		var dome: float = sin(t * PI)
		var dome_shaped: float = pow(dome, 1.25)
		var bump: float = _noise.get_noise_1d(x) * 6.5 * (0.25 + 0.75 * dome)
		var y: float = -H * (0.22 + 0.86 * dome_shaped) + bump
		top_pts.append(Vector2(x, y))

	var mound := top_pts.duplicate()
	mound.append(Vector2(W * 0.50, base_y + 18.0))
	mound.append(Vector2(W * 0.34, base_y + 30.0))
	mound.append(Vector2(0.0,       base_y + 34.0))
	mound.append(Vector2(-W * 0.34, base_y + 30.0))
	mound.append(Vector2(-W * 0.50, base_y + 18.0))
	_mound = mound

	_shadow = PackedVector2Array([
		Vector2(-W * 0.52, base_y + 10.0), Vector2( W * 0.52, base_y + 10.0),
		Vector2( W * 0.42, base_y + 26.0), Vector2(-W * 0.42, base_y + 26.0),
	])
	_ao_rect = Rect2(Vector2(-W * 0.48, base_y + 10.0), Vector2(W * 0.96, 10.0))

func _build_layers() -> void:
	_base = _mound
	var mid_arr = Geometry2D.offset_polygon(_mound, -6.0)
	_mid = mid_arr[0] if mid_arr.size() > 0 else _mound
	var top_arr = Geometry2D.offset_polygon(_mound, -12.0)
	_top = top_arr[0] if top_arr.size() > 0 else _mound

func _build_interior_strokes() -> void:
	var stroke_count: int = 85
	for i in range(stroke_count):
		var x = _rng.randf_range(-W * 0.40, W * 0.40)
		var u = pow(_rng.randf(), 0.55)
		var y = lerpf(-H * 0.72, 10.0, 1.0 - u)
		var a = deg_to_rad(_rng.randf_range(-18.0, 18.0))
		var len = _rng.randf_range(10.0, 28.0)
		var p0 = Vector2(x, y)
		var p1 = p0 + Vector2(cos(a), sin(a)) * len

		if Geometry2D.is_point_in_polygon((p0 + p1) * 0.5, _mound):
			_strokes_pts.append(PackedVector2Array([p0, p1]))
			var v = _rng.randf_range(-0.07, 0.09)
			var c = hay_color.lightened(maxf(v, 0.0)).darkened(maxf(-v, 0.0))
			c.a = 0.95
			_strokes_col.append(c)
			_strokes_w.append(_rng.randf_range(1.3, 2.3))

func _draw() -> void:
	draw_colored_polygon(_shadow, Color(0, 0, 0, 0.22))
	var out_arr = Geometry2D.offset_polygon(_mound, outline_px)
	if out_arr.size() > 0:
		draw_colored_polygon(out_arr[0], outline_color)
	else:
		draw_polyline(_mound, outline_color, outline_px)
	
	draw_colored_polygon(_base, hay_color.darkened(0.22))
	draw_colored_polygon(_mid,  hay_color.darkened(0.10))
	draw_colored_polygon(_top,  hay_color.lightened(0.06))

	for i in range(_strokes_pts.size()):
		draw_polyline(_strokes_pts[i], _strokes_col[i], _strokes_w[i])
	
	draw_rect(_ao_rect, _ao_col, true)
