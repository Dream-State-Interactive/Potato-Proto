# src/modes/gauntlet/level_generator.gd
@tool
extends Node2D

@export var generate_in_editor: bool = false:
	set(value):
		generate_in_editor = value
		if generate_in_editor and Engine.is_editor_hint():
			_generate_level_preview()

@export_range(1, 20) var editor_preview_length: int = 5
@export_range(2, 10) var max_active_segments: int = 3

const SEGMENT_END_TRIGGER = preload("res://src/modes/gauntlet/segment_end_trigger.tscn")
const STORE_SCENE = preload("res://src/modes/gauntlet/store.tscn")
const SPECIAL_SCENE = preload("res://src/levels/level_proto/level_proto.tscn")

@onready var hill_generator: Node2D = $HillGenerator
@onready var hazard_generator: Node2D = $HazardGenerator
@onready var obstacle_generator: Node2D = $ObstacleGenerator

var _current_spawn_position: Vector2 = Vector2.ZERO
var _active_segments: Array[Node2D] = []

func _ready():
	print("LevelGenerator is ready and running!")
	if not Engine.is_editor_hint():
		_generate_level_preview()

func _generate_level_preview():
	for child in get_children():
		if child.is_in_group("level_segment"):
			child.queue_free()

	_active_segments.clear()
	_current_spawn_position = Vector2.ZERO
	
	# Reset progression for a clean preview
	if Engine.is_editor_hint():
		ProgressionManager.hills_completed = 0
		ProgressionManager.current_level = 1

	for i in range(editor_preview_length):
		_generate_next_segment()

func _generate_next_segment():
	var segment = Node2D.new()
	segment.name = "Segment" + str(ProgressionManager.hills_completed)
	segment.add_to_group("level_segment")
	add_child(segment)

	segment.global_position = _current_spawn_position

	# Part 1: Generate Hill and Hazards
	var hill_params = ProgressionManager.get_hill_parameters()
	var hill_result = hill_generator.generate_hill(hill_params)
	var hill_node = hill_result["node"]
	var hill_end_pos_local = hill_result["end_position"]
	segment.add_child(hill_node)

	var hazard_density = ProgressionManager.get_hazard_density()
	var hazards_node = hazard_generator.generate_on_surface(hill_result["surface_points"], hazard_density)
	if hazards_node:
		hill_node.add_child(hazards_node)

	# Part 2: Generate Content (Obstacle, Store, or Special Scene)
	var content_node: Node2D
	var content_width: float

	if ProgressionManager.hills_completed > 0 and ProgressionManager.hills_completed % 10 == 9:
		content_node = SPECIAL_SCENE.instantiate()
		content_width = 1000.0 # Estimated width for the special scene
		content_node.position = hill_end_pos_local
	elif ProgressionManager.hills_completed > 0 and ProgressionManager.hills_completed % 5 == 4:
		content_node = STORE_SCENE.instantiate()
		content_width = 100.0
	else:
		var obstacle_result = obstacle_generator.generate_obstacle(ProgressionManager.get_obstacle_complexity())
		content_node = obstacle_result["node"]
		content_width = obstacle_result["width"]
		content_node.position = hill_end_pos_local
	
	segment.add_child(content_node)
	var segment_width = hill_end_pos_local.x + content_width

	# Part 3: Spawn End Trigger (only at runtime)
	if not Engine.is_editor_hint():
		var end_trigger = SEGMENT_END_TRIGGER.instantiate()
		end_trigger.position = Vector2(segment_width, hill_end_pos_local.y)
		end_trigger.player_finished_segment.connect(_on_player_finished_segment)
		segment.add_child(end_trigger)

	# Part 4: Update State and Cull Old Segments
	_current_spawn_position += Vector2(segment_width, hill_end_pos_local.y)
	_active_segments.append(segment)

	if _active_segments.size() > max_active_segments:
		var oldest_segment = _active_segments.pop_front()
		oldest_segment.queue_free()


func _on_player_finished_segment():
	ProgressionManager.complete_segment()
	_generate_next_segment()
