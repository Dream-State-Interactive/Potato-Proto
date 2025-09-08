# src/modes/gauntlet/hazard_generator.gd
@tool
extends Node2D

const HAZARD_SCENE = preload("res://src/hazards/hazard_base.tscn")

func generate_on_surface(surface_points: PackedVector2Array, density: float) -> Node2D:
	if surface_points.size() < 2 or density <= 0.0:
		return null

	var hazards_container = Node2D.new()
	hazards_container.name = "HazardsContainer"

	# Loop through all surface points to place hazards everywhere.
	for i in range(surface_points.size() - 1):
		var current_density = density
		
		# Add a density boost for the last 15% of the hill.
		if float(i) / (surface_points.size() - 1) > 0.85:
			current_density *= 4.0 # 4x density boost

		if randf() < current_density:
			var p1 = surface_points[i]
			var p2 = surface_points[i+1]
			
			var segment = p2 - p1
			# Get a normal vector pointing perpendicular to the surface.
			var normal = segment.orthogonal().normalized()
			
			# Ensure the normal always points up.
			if normal.y > 0:
				normal = -normal
				
			var hazard = HAZARD_SCENE.instantiate()
			# Place the hazard in the middle of the two surface points.
			hazard.position = p1.lerp(p2, 0.5)
			# Rotate the hazard to match the angle of the ground.
			hazard.rotation = normal.angle() + deg_to_rad(90)
			hazards_container.add_child(hazard)
			
	return hazards_container
