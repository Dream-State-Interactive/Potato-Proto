class_name BatchSpawner
extends Node

var scene_to_spawn: PackedScene
var locations: Array[Vector2] = []
var items_per_frame: int = 4 

func _process(_delta: float) -> void:
	if locations.is_empty():
		queue_free()
		return

	var parent = get_parent()
	if not is_instance_valid(parent):
		queue_free()
		return

	var count = 0
	
	while not locations.is_empty() and count < items_per_frame:
		var pos = locations.pop_back()
		
		var instance = scene_to_spawn.instantiate()
		instance.position = pos
		parent.add_child(instance)
		
		count += 1
