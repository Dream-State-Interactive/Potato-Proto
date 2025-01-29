@tool
extends StaticBody2D

@export var path_texture: Texture2D
@export var path_width: float = 10
@export var extrude_texture: Texture2D
@export var extrude_amount: float = 250
@export var collision_resolution: int = 32 # Number of points for collision polygon
@export var extrusion_resolution: int = 128 # Number of points for extrusion polygon

@onready var path_2d = $Path2D
@onready var line_2d = $Line2D
@onready var extrude_polygon_2d = $ExtrudePolygon2D
@onready var collision_polygon_2d = $CollisionPolygon2D

func _ready():
	update_path()

func update_path():
	if not path_texture or not extrude_texture:
		return

	var curve = path_2d.curve
	var baked_points = curve.get_baked_points()

	line_2d.texture = path_texture
	line_2d.points = baked_points

	# Generate extruded polygon points
	var extruded_polygon_points = generate_extruded_polygon(baked_points, extrude_amount, extrusion_resolution)

	# Create and set the Polygon2D
	extrude_polygon_2d.polygon = extruded_polygon_points
	extrude_polygon_2d.texture = extrude_texture

	# Generate collision polygon with specified resolution
	collision_polygon_2d.polygon = generate_path_polygon(baked_points, path_width, collision_resolution)


# Generates a closed polygon for collision, using simplified points for performance.
func generate_path_polygon(points: PackedVector2Array, width: float, resolution: int) -> PackedVector2Array:
	# Initialize a PackedVector2Array to store the collision polygon's vertices.
	var polygon = PackedVector2Array()
	# Simplify the path to the specified resolution.
	var simplified_points = simplify_path(points, resolution)

	# Generate the first side of the collision polygon (offset along the normal).
	for i in range(simplified_points.size()):
		# Calculate the forward direction vector (tangent to the path).  Modulo operator handles loop-around.
		var forward = (simplified_points[(i + 1) % simplified_points.size()] - simplified_points[i]).normalized()
		# Calculate the outward-pointing normal vector.
		var normal = forward.rotated(PI / 2)
		# Offset the current point outwards along the normal by half the path width to create the polygon edge.
		polygon.append(simplified_points[i] + normal * width / 2)

	# Generate the second side of the collision polygon (offset along the opposite normal).  Reverse iteration for correct winding.
	for i in range(simplified_points.size() - 1, -1, -1):
		# Calculate the forward direction vector.
		var forward = (simplified_points[(i + 1) % simplified_points.size()] - simplified_points[i]).normalized()
		# Calculate the inward-pointing normal vector.
		var normal = forward.rotated(-PI / 2)
		# Offset the current point inwards along the normal to create the other polygon edge.
		polygon.append(simplified_points[i] + normal * width / 2)

	return polygon

func generate_extruded_polygon(points: PackedVector2Array, extrude_amount: float, resolution: int) -> PackedVector2Array:
	# Initialize a PackedVector2Array to store the extruded polygon's vertices.
	var extruded_points: PackedVector2Array = []
	# Simplify the path to the specified resolution.
	var simplified_points = simplify_path(points, resolution)
	# Find the lowest y-coordinate among the simplified points to determine the flat bottom edge.
	var lowest_y = simplified_points[0].y
	for point in simplified_points:
		lowest_y = max(lowest_y, point.y)  #Use max because positive is lowest in 2d space for Godot

	# Add the starting point of the bottom edge (leftmost point of the extrusion).
	extruded_points.append(Vector2(simplified_points[0].x, lowest_y + extrude_amount))

	# Add the simplified points (top edge of the extruded shape).
	for i in range(simplified_points.size()):
		extruded_points.append(simplified_points[i])

	# Add the extruded points for the bottom edge.
	for i in range(simplified_points.size() - 1, -1, -1): #Reverse order for correct connection
		extruded_points.append(Vector2(simplified_points[i].x, lowest_y + extrude_amount))

	# Close the polygon by adding the starting point of the bottom edge again.
	extruded_points.append(Vector2(simplified_points[0].x, lowest_y + extrude_amount))

	return extruded_points

func simplify_path(points: PackedVector2Array, target_points: int) -> PackedVector2Array:
	# If the original path has fewer points than the target, return the original points (no simplification needed).
	if points.size() <= target_points:
		return points

	# Calculate the interval at which to select points for simplification.
	var interval = float(points.size() - 1) / float(target_points - 1)
	# Initialize a PackedVector2Array for the simplified points.
	var simplified_points = PackedVector2Array()

	# Generate simplified points by selecting points at intervals from the original path.
	for i in range(target_points):
		var index = i * interval
		# Use floor() to get the nearest integer index less than or equal to the calculated index to avoid going out of bounds
		simplified_points.append(points[floor(index)])

	return simplified_points
