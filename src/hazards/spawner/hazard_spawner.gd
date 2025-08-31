# src/hazards/spawner/hazard_spawner.gd
class_name HazardSpawner
extends Node

## Called by HazardSystem. Implement in subclasses.
func spawn(surface_points: PackedVector2Array, into: Node2D) -> void:
	pass
