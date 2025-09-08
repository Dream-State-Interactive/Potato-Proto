# src/hazards/spawner/hazard_system.gd
@tool
class_name HazardSystem
extends Node2D

## Drag your spawner nodes (children or anywhere) here in the inspector.
@export var spawners: Array[NodePath] = []

func generate(surface_points: PackedVector2Array) -> Node2D:
	var container := Node2D.new()
	container.name = "HazardsContainer"

	for path in spawners:
		if not has_node(path): continue
		var s := get_node(path)
		if s is HazardSpawner:
			(s as HazardSpawner).spawn(surface_points, container)
		else:
			push_warning("Node at %s is not a HazardSpawner" % [str(path)])

	return container
