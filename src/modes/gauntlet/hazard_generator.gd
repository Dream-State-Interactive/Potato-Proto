# src/modes/gauntlet/hazard_generator.gd

@tool
class_name HazardGenerator
extends Node2D

## Create 'HazardConfig' resources and add them here.
## The generator will pick from this list based on progression.
@export var hazard_configs: Array[HazardConfig]

func generate(surface_points: PackedVector2Array) -> Node2D:
	var container := Node2D.new()
	container.name = "HazardsContainer"

	if surface_points.size() < 2:
		return container

	# 1. Determine which hazards are eligible for the current progression level.
	var current_hills: int = ProgressionManager.hills_completed
	var potential_hazards: Array[HazardConfig] = []
	for config in hazard_configs:
		if config and current_hills >= config.min_hills_completed and current_hills <= config.max_hills_completed:
			potential_hazards.append(config)
	
	if potential_hazards.is_empty():
		return container # No hazards to spawn at this level.

	# 2. Iterate through the hill surface and try to spawn hazards.
	var total_points = surface_points.size()
	for i in range(total_points - 1):
		# Check each potential hazard for this point
		for config in potential_hazards:
			if not config.hazard_scene:
				continue
			# Calculate how many "progression steps" have passed since this hazard unlocked.
			var hills_since_unlock = max(0, current_hills - config.min_hills_completed)
			
			# Calculate the current density based on progression.
			var current_density = config.base_density + (hills_since_unlock * config.density_increase_per_hill)
			
			# Clamp the density to the defined maximum.
			var density = min(current_density, config.max_density)
			var progress_percent: float = float(i) / total_points

			# Apply the end-of-hill density boost if applicable
			if progress_percent >= config.end_boost_start_percent:
				density *= config.end_boost_multiplier

			# Random check to see if we should spawn this hazard
			if randf() < density:
				_spawn_hazard(config, surface_points[i], surface_points[i+1], container)
				# To prevent clutter, we can break here so only one hazard spawns per segment.
				# You can remove this 'break' if you want multiple hazards to potentially spawn at the same spot.
				break 
				
	return container

# Helper function to instantiate and position a single hazard.
func _spawn_hazard(config: HazardConfig, p1: Vector2, p2: Vector2, container: Node2D):
	var hazard_instance := config.hazard_scene.instantiate()

	# Calculate position and orientation
	var mid_point := p1.lerp(p2, 0.5)
	var normal := (p2 - p1).orthogonal().normalized()
	if normal.y > 0: # Ensure normal points upwards from the ground
		normal = -normal

	hazard_instance.position = mid_point
	hazard_instance.rotation = normal.angle() + deg_to_rad(90)

	container.add_child(hazard_instance)
