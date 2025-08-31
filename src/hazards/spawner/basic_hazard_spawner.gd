# res://src/modes/gauntlet/hazards/spawners/basic_hazard_spawner.gd
class_name BasicHazardSpawner
extends HazardSpawner

@export var hazard_scene: PackedScene = preload("res://src/hazards/hazard_base.tscn")
@export var base_density: float = 0.08
@export var end_boost_start: float = 0.85
@export var end_boost_multiplier: float = 4.0

func spawn(surface_points: PackedVector2Array, into: Node2D) -> void:
	if surface_points.size() < 2: return

	for i in range(surface_points.size() - 1):
		var density := base_density
		if float(i) / (surface_points.size() - 1) > end_boost_start:
			density *= end_boost_multiplier

		if randf() >= density: continue

		var p1 := surface_points[i]
		var p2 := surface_points[i + 1]
		var mid := p1.lerp(p2, 0.5)

		var normal := (p2 - p1).orthogonal().normalized()
		if normal.y > 0: normal = -normal

		var h := hazard_scene.instantiate()
		h.position = mid
		h.rotation = normal.angle() + deg_to_rad(90)
		into.add_child(h)
