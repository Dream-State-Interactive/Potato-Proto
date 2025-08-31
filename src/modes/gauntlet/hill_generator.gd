# src/modes/gauntlet/hill_generator.gd
@tool
extends Node2D

const SPAWN_STARCH_POINTS_EVERY_N_POINTS = 3
const STARCH_POINT = preload("res://src/collectibles/starch_point.tscn")

func generate_hill(params: Dictionary) -> Dictionary:
	var hill = Node2D.new()
	hill.name = "HillContainer"

	var ground_body = StaticBody2D.new()
	var collision_polygon = CollisionPolygon2D.new()
	var visual_polygon = Polygon2D.new()

	collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS

	var points = PackedVector2Array()
	var noise = FastNoiseLite.new()

	if Engine.is_editor_hint():
		noise.seed = 420
	else:
		noise.seed = randi()
	
	noise.frequency = params.get("frequency", 0.01)
	var length = params.get("length", 500)
	var amplitude = params.get("amplitude", 50)
	# Increased step size to generate fewer points over the larger hill length.
	var step_size = 50.0

	for i in range(int(length / step_size) + 1):
		var x = i * step_size
		# Use noise to vary the y-coordinate, creating the hill shape.
		var y = noise.get_noise_1d(x) * amplitude
		points.append(Vector2(x, y))

	# Create a filled polygon for the visual part of the hill.
	var filled_points = points.duplicate()
	if not filled_points.is_empty():
		# Add bottom points to make the shape solid.
		filled_points.append(Vector2(points[-1].x, amplitude * 2))
		filled_points.append(Vector2(0, amplitude * 2))

	visual_polygon.polygon = filled_points
	visual_polygon.color = params.get("color", Color.DARK_GREEN)

	# The collision polygon only needs the top surface points.
	collision_polygon.polygon = filled_points
	
	var i = 0
	for point in points:
		if i % SPAWN_STARCH_POINTS_EVERY_N_POINTS == 0:
			var starch = STARCH_POINT.instantiate()
			hill.add_child(starch)
			starch.position = point
			starch.position.y -= 100
		i += 1

	ground_body.add_child(collision_polygon)
	hill.add_child(visual_polygon)
	hill.add_child(ground_body)

	return {
		"node": hill,
		"end_position": points[-1] if not points.is_empty() else Vector2.ZERO,
		"surface_points": points 
	}
