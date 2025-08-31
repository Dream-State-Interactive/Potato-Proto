# res://src/modes/gauntlet/hazards/spawners/worm_hazard_spawner.gd
class_name WormHazardSpawner
extends HazardSpawner

@export var worm_scene: PackedScene = preload("res://src/hazards/worm/hazard_worm.tscn")
@export var max_per_hill_cap: int = 3

func spawn(surface_points: PackedVector2Array, into: Node2D) -> void:
	if surface_points.size() < 2: return

	var cfg := ProgressionManager.get_worm_params()
	if not bool(cfg.get("enabled", false)): return

	var stack_size: int = int(cfg.get("stack_size", 3))
	stack_size = min(stack_size, 6)
	var chance: float = float(cfg.get("chance", 0.03))
	var max_per_hill: int = int(cfg.get("max_per_hill", 3))
	max_per_hill = min(max_per_hill, max_per_hill_cap)

	var spawned := 0
	for i in range(surface_points.size() - 1):
		if spawned >= max_per_hill: break
		if randf() >= chance: continue

		var p1 := surface_points[i]
		var p2 := surface_points[i + 1]
		var mid := p1.lerp(p2, 0.5)

		var normal := (p2 - p1).orthogonal().normalized()
		if normal.y > 0: normal = -normal

		var worm := worm_scene.instantiate()
		# Configure optional params safely
		if worm.has_method("set"):
			worm.set("initial_stack", stack_size)
			worm.set("hazardous", true)
			worm.set("pin_break_speed", 7000.0)

		worm.position = mid
		worm.rotation = normal.angle() + deg_to_rad(90)
		into.add_child(worm)

		spawned += 1
