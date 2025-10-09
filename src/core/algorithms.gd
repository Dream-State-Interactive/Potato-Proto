extends Node

## Distance from a point P to a line segment AB
func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len2: float = ab.length_squared()
	if ab_len2 <= 0.0:
		return (p - a).length()
	var t: float = clamp((p - a).dot(ab) / ab_len2, 0.0, 1.0)
	var c: Vector2 = a + ab * t
	return (p - c).length()

## Ramer-Douglas_Peucker Algorithm: decimates a curve composed of line segments to a similar curve with fewer points. 
## (In other words, turns a curve "low-poly")
func _rdp(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var n: int = points.size()
	if n < 3:
		return points
	var p0: Vector2 = points[0]
	var pn: Vector2 = points[n - 1]
	var idx: int = -1
	var dmax: float = 0.0
	# Find farthest point from the segment p0→pn
	for i in range(1, n - 1):
		var d: float = Algorithms._dist_point_to_segment(points[i], p0, pn)
		if d > dmax:
			dmax = d
			idx = i
	# Recurse on sub-spans if error too large
	if dmax > epsilon and idx >= 0:
		var left: PackedVector2Array = _rdp(points.slice(0, idx + 1), epsilon)
		var right: PackedVector2Array = _rdp(points.slice(idx, n), epsilon)
		var out := PackedVector2Array()
		for j in range(left.size() - 1): # avoid duplicate last point
			out.append(left[j])
		for j in range(right.size()):
			out.append(right[j])
		return out
	else:
		var out := PackedVector2Array()
		out.append(p0)
		out.append(pn)
		return out
