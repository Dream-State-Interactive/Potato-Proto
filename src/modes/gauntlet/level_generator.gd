# src/modes/gauntlet/level_generator.gd
@tool
extends Node2D

@export var generate_in_editor: bool = false:
	set(value):
		generate_in_editor = value
		if generate_in_editor and Engine.is_editor_hint():
			_generate_level_preview()

@export_range(1, 20) var editor_preview_length: int = 5

# --- Generation Config ---
@export_range(2, 20) var max_active_segments: int = 5
@export_range(1, 10) var pregenerate_forward: int = 3
@export_range(1, 10) var pregenerate_backward: int = 2

## Array to control the special scene generation sequence.
## Create 'SpecialSegmentConfig' resources and add them in the Inspector.
@export var special_segment_sequence: Array[SpecialSegmentConfig]
## The scene that will always be generated first. Must contain a Marker2D named "EndMarker".
@export var start_segment_scene: PackedScene = preload("res://src/modes/gauntlet/start_segment.tscn")

@export_group("Store Generation")
## The scene for the regular store.
@export var regular_store_scene: PackedScene = preload("res://src/modes/gauntlet/store.tscn")
## How many hills are completed before a regular store appears.
@export var regular_store_interval: int = 5
## The scene for the special, less frequent store.
@export var special_store_scene: PackedScene
## How many hills are completed before a special store appears.
@export var special_store_interval: int = 15

const SEGMENT_BOUNDARY_SCENE = preload("res://src/modes/gauntlet/segment_boundary.tscn")

# --- Node References ---
@onready var hill_generator: Node2D = $HillGenerator
@onready var hazard_generator: Node2D = $HazardGenerator
@onready var obstacle_generator: Node2D = $ObstacleGenerator
@onready var background: CanvasLayer = $"../Background"

# --- State Management ---
var _master_seed: int
var _rng := RandomNumberGenerator.new()
var _active_segments: Dictionary = {}
var _segment_end_positions: Dictionary = {}
var _player_current_index: int = 0
var _special_sequence_index: int = 0
var _special_sequence_repeats: int = 0
var _is_in_special_chain: bool = false
var _last_special_trigger_hills: int = -1
var last_theme_change_hill_count: int = -1


func _ready():
	if Engine.is_editor_hint():
		return
	reset_and_generate_initial_segments()


# =====================================
# --- Initialization and Resetting ---
# =====================================
## game_manager.gd calls this to reset the generator
func reset_and_generate_initial_segments():
	print("--- RESETTING LEVEL GENERATOR ---")
	_reset_and_initialize()
	_generate_initial_bootstrap_segments()

func _reset_and_initialize():
	for segment in _active_segments.values():
		if is_instance_valid(segment):
			segment.queue_free()
	_active_segments.clear()
	_segment_end_positions.clear()
	
	_master_seed = randi()
	ProgressionManager.reset(_master_seed)
	
	_player_current_index = 0
	# The anchor is still crucial. It defines where the world begins.
	_segment_end_positions[-1] = Vector2.ZERO
	
	_special_sequence_index = 0
	_special_sequence_repeats = 0
	_is_in_special_chain = false
	_last_special_trigger_hills = -1

func _generate_initial_bootstrap_segments():
	print("--- GENERATING INITIAL BOOTSTRAP ---")
	# Generate the start segment and the forward buffer.
	# No negative segments are ever generated here.
	_generate_segment_at_index(0)
	var forward_limit = _player_current_index + pregenerate_forward
	for i in range(1, forward_limit + 1):
		_generate_segment_at_index(i)
	print("--- BOOTSTRAP COMPLETE ---")

func _generate_level_preview():
	for child in get_children():
		if child.is_in_group("level_segment"):
			child.queue_free()
	_active_segments.clear()
	_segment_end_positions.clear()
	_master_seed = 12345
	ProgressionManager.reset(_master_seed)
	_player_current_index = 0
	_segment_end_positions[-1] = Vector2.ZERO
	for i in range(editor_preview_length):
		_generate_segment_at_index(i)


# =============================
# --- Core Generation Logic ---
# =============================
func _ensure_surrounding_segments_exist():
	print("Ensuring surrounding segments exist around index: %d" % _player_current_index)
	var forward_limit = _player_current_index + pregenerate_forward
	for i in range(_player_current_index, forward_limit + 1):
		_generate_segment_at_index(i)

	var backward_limit = _player_current_index - pregenerate_backward
	for i in range(_player_current_index - 1, backward_limit - 1, -1):
		_generate_segment_at_index(i)
	
	_maybe_cull_segments()

func _generate_segment_at_index(index: int):
	# The generator will simply refuse to create any segment with a negative index.
	if index < 0:
		return

	if _active_segments.has(index):
		return

	print("Generating segment for index: %d" % index)
	var segment_seed = ProgressionManager.get_seed_for_index(index)
	var result: Dictionary

	if index == 0 and start_segment_scene:
		result = _generate_start_segment(segment_seed)
	else:
		var hills_completed = ProgressionManager.max_forward_index
		if not _is_in_special_chain and not special_segment_sequence.is_empty():
			var cfg: SpecialSegmentConfig = special_segment_sequence[_special_sequence_index]
			if cfg and cfg.number_of_hills_required > 0 and (hills_completed > 0 and (hills_completed % cfg.number_of_hills_required == 0) and _last_special_trigger_hills != hills_completed):
				_is_in_special_chain = true
				_special_sequence_repeats = 0
				_last_special_trigger_hills = hills_completed
		
		if _is_in_special_chain:
			result = _generate_special_segment(index, segment_seed)
		else:
			result = _generate_standard_segment(index, segment_seed)

	if result.is_empty():
		printerr("Failed to generate segment for index: ", index)
		return

	var segment: Node2D = result["node"]
	var end_pos_local: Vector2 = result["end_pos_local"]

	# Positioning logic is now simpler as it only handles index >= 0.
	var spawn_pos = _segment_end_positions.get(index - 1, Vector2.ZERO)
	add_child(segment)
	segment.global_position = spawn_pos
	_segment_end_positions[index] = segment.to_global(end_pos_local)

	_active_segments[index] = segment
	_finalize_segment_generation(segment, index, end_pos_local)

# Shared logic for finishing any segment type.
func _finalize_segment_generation(segment: Node2D, index: int, end_pos_local: Vector2):
	segment.set_meta("segment_index", index)
	if not Engine.is_editor_hint():
		# A boundary is placed at the end of every valid segment.
		# Since negative segments can't be created, a boundary at the start of the world is never made.
		var boundary = SEGMENT_BOUNDARY_SCENE.instantiate()
		segment.add_child(boundary)
		boundary.position = end_pos_local
		boundary.segment_index = index
		boundary.player_crossed_boundary.connect(_on_player_crossed_boundary)

func _generate_start_segment(_seed: int) -> Dictionary:
	var segment = Node2D.new()
	segment.name = "StartSegment_0"
	segment.add_to_group("level_segment")
	var content_node: Node2D = start_segment_scene.instantiate()
	segment.add_child(content_node)
	# Compute end AFTER added to scene so transforms are valid
	var end_marker = content_node.find_child("EndMarker", true, false)
	if not end_marker:
		printerr("Start scene is missing an 'EndMarker' node!")
		return {}
	return {"node": segment, "end_pos_local": end_marker.position}

func _generate_standard_segment(index: int, seed: int) -> Dictionary:
	_rng.seed = seed
	
	var hills_completed = ProgressionManager.max_forward_index
	if hills_completed > 0 and (hills_completed % 3 == 0) and (hills_completed != last_theme_change_hill_count):
		last_theme_change_hill_count = hills_completed
		ThemeManagerOlde.advance_theme()
		if is_instance_valid(background):
			background.change_color(ThemeManagerOlde.get_current_theme().sky_color)
			
	var segment = Node2D.new()
	segment.name = "Segment" + str(index)
	segment.add_to_group("level_segment")

	# Generate Hill and Hazards
	var hill_params = ProgressionManager.get_hill_parameters(index)
	var should_spawn_starch = (index > ProgressionManager.max_forward_index)
	var hill_result = hill_generator.generate_hill(hill_params, seed, not should_spawn_starch)
	var hill_node: Node2D = hill_result["node"]
	hill_node.z_as_relative = false
	hill_node.z_index = 5
	var hill_end_pos_local: Vector2 = hill_result["end_position"]
	segment.add_child(hill_node)
	
	var spawn_pts: PackedVector2Array = hill_result.get("spawn_points", hill_result["surface_points"])
	# We also pass the index to the hazard generator for consistency.
	var hazards_node: Node2D = hazard_generator.generate(spawn_pts, seed, index)
	if hazards_node:
		hill_node.add_child(hazards_node)

	# Generate Content (Store or Obstacle)
	var content_node: Node2D
	var content_end_pos_local: Vector2
	var content_spawned = false
	
	# Check for the Special Store first to give it priority.
	if special_store_scene and special_store_interval > 0 and (hills_completed % special_store_interval == special_store_interval - 1):
		content_node = special_store_scene.instantiate()
		content_end_pos_local = hill_end_pos_local + Vector2(1000, 0)
		content_spawned = true
	elif regular_store_scene and regular_store_interval > 0 and (hills_completed % regular_store_interval == regular_store_interval - 1):
		content_node = regular_store_scene.instantiate()
		content_end_pos_local = hill_end_pos_local + Vector2(1000, 0)
		content_spawned = true
		
	if not content_spawned:
		var obstacle_result = obstacle_generator.generate_obstacle(ProgressionManager.get_obstacle_complexity(index))
		content_node = obstacle_result["node"]
		content_end_pos_local = hill_end_pos_local + Vector2(float(obstacle_result.get("width", 1000.0)), 0)

	content_node.position = hill_end_pos_local
	segment.add_child(content_node)
	
	return {"node": segment, "end_pos_local": content_end_pos_local}

func _generate_special_segment(index: int, seed: int) -> Dictionary:
	if special_segment_sequence.is_empty() or _special_sequence_index >= special_segment_sequence.size():
		_is_in_special_chain = false
		return _generate_standard_segment(index, seed)
	var config: SpecialSegmentConfig = special_segment_sequence[_special_sequence_index]
	if not config or not config.scene:
		_is_in_special_chain = false
		return _generate_standard_segment(index, seed)
	var segment = Node2D.new()
	segment.name = "SpecialSegment_" + str(index)
	segment.add_to_group("level_segment")
	var content_node: Node2D = config.scene.instantiate()
	segment.add_child(content_node)
	var end_marker = content_node.find_child("EndMarker", true, false)
	if not end_marker:
		printerr("Special scene '", config.scene.resource_path, "' is missing 'EndMarker'!")
		return {}

	# Update the special sequence progression
	_special_sequence_repeats += 1
	if _special_sequence_repeats >= max(1, config.number_of_times_to_repeat):
		_special_sequence_repeats = 0
		_special_sequence_index = (_special_sequence_index + 1) % special_segment_sequence.size()
		_is_in_special_chain = false
	return {"node": segment, "end_pos_local": end_marker.position}


func _on_player_crossed_boundary(from_index: int, direction: int):
	_player_current_index = from_index + direction
	print("Player is now in segment: %d" % _player_current_index)

	if direction > 0:
		ProgressionManager.update_progress(_player_current_index)
	
	_ensure_surrounding_segments_exist()

func _maybe_cull_segments():
	var cull_indices = []
	for index in _active_segments.keys():
		if index > _player_current_index + pregenerate_forward or \
		   index < _player_current_index - pregenerate_backward:
			cull_indices.append(index)
	for index in cull_indices:
		var segment = _active_segments.get(index)
		if is_instance_valid(segment):
			print("Culling segment at index: ", index)
			segment.queue_free()
		_active_segments.erase(index)
