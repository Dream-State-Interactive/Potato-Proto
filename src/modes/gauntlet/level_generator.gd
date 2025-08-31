# src/modes/gauntlet/level_generator.gd
@tool
extends Node2D

@export var generate_in_editor: bool = false:
	set(value):
		generate_in_editor = value
		if generate_in_editor and Engine.is_editor_hint():
			_generate_level_preview()

@export_range(1, 20) var editor_preview_length: int = 5
@export_range(2, 20) var max_active_segments: int = 3

# How many segments to pre-spawn at runtime (should be <= max_active_segments)
@export_range(1, 10) var runtime_bootstrap_segments: int = 2

# For safe culling
@export var player_path: NodePath
@export var cull_margin_px: float = 512.0

## Array to control the special scene generation sequence.
## Create 'SpecialSegmentConfig' resources and add them in the Inspector.
@export var special_segment_sequence: Array[SpecialSegmentConfig]

const SEGMENT_END_TRIGGER = preload("res://src/modes/gauntlet/segment_end_trigger.tscn")
const STORE_SCENE = preload("res://src/modes/gauntlet/store.tscn")
const FALLBACK_SPECIAL_SCENE = preload("res://src/levels/level_proto/level_proto.tscn") # unused

@onready var hill_generator: Node2D = $HillGenerator
@onready var hazard_generator: Node2D = $HazardGenerator
@onready var obstacle_generator: Node2D = $ObstacleGenerator

var _current_spawn_position: Vector2 = Vector2.ZERO
var _active_segments: Array[Node2D] = []

# State variables for the special segment progression
var _special_sequence_index: int = 0
var _special_sequence_repeats: int = 0
var _is_in_special_chain: bool = false
var _last_special_trigger_hills: int = -1

func _ready():
	print("LevelGenerator is ready and running!")
	if Engine.is_editor_hint():
		return # Editor preview is manual via the toggle

	# Reset state without culling
	_reset_runtime_state()
	var to_spawn: int = clampi(runtime_bootstrap_segments, 1, max_active_segments)
	for i in range(to_spawn):
		_generate_next_segment(false) # no culling during bootstrap

func _reset_runtime_state():
	# Clear previously generated segments (if any)
	for child in get_children():
		if child.is_in_group("level_segment"):
			child.queue_free()
	_active_segments.clear()
	_current_spawn_position = Vector2.ZERO
	# Do NOT reset ProgressionManager at runtime
	_special_sequence_index = 0
	_special_sequence_repeats = 0
	_is_in_special_chain = false
	_last_special_trigger_hills = -1

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

	_special_sequence_index = 0
	_special_sequence_repeats = 0
	_is_in_special_chain = false
	_last_special_trigger_hills = -1

	for i in range(editor_preview_length):
		_generate_next_segment(false) # no culling in editor preview

func _generate_next_segment(allow_cull: bool = true):
	# Determine if we should start or continue a special scene chain
	if not _is_in_special_chain and not special_segment_sequence.is_empty():
		var cfg: SpecialSegmentConfig = special_segment_sequence[_special_sequence_index]
		if cfg and cfg.number_of_hills_required > 0:
			if (ProgressionManager.hills_completed > 0
				and (ProgressionManager.hills_completed % cfg.number_of_hills_required == 0)
				and _last_special_trigger_hills != ProgressionManager.hills_completed):
				_is_in_special_chain = true
				_special_sequence_repeats = 0
				_last_special_trigger_hills = ProgressionManager.hills_completed

	if _is_in_special_chain:
		_generate_special_segment(allow_cull)
	else:
		_generate_standard_segment(allow_cull)

func _generate_standard_segment(allow_cull: bool):
	var segment = Node2D.new()
	segment.name = "Segment" + str(ProgressionManager.hills_completed)
	segment.add_to_group("level_segment")
	add_child(segment)
	segment.global_position = _current_spawn_position

	# Part 1: Generate Hill and Hazards
	var hill_params = ProgressionManager.get_hill_parameters()
	var hill_result = hill_generator.generate_hill(hill_params)
	var hill_node: Node2D = hill_result["node"]
	var hill_end_pos_local: Vector2 = hill_result["end_position"]
	segment.add_child(hill_node)

	var hazard_density = ProgressionManager.get_hazard_density()
	#var hazards_node = hazard_generator.generate_on_surface(hill_result["surface_points"], hazard_density)
	#if hazards_node:
		#hill_node.add_child(hazards_node)
	var hazards_node: Node2D = hazard_generator.generate(hill_result["surface_points"])
	if hazards_node:
		hill_node.add_child(hazards_node)

	# Part 2: Generate Content (Store or Obstacle)
	var content_node: Node2D
	var content_width: float
	var content_end_pos_local: Vector2

	if ProgressionManager.hills_completed > 0 and (ProgressionManager.hills_completed % 5 == 4):
		content_node = STORE_SCENE.instantiate()
		content_width = 1000.0
		content_end_pos_local = hill_end_pos_local + Vector2(content_width, 0)
	else:
		var obstacle_result = obstacle_generator.generate_obstacle(ProgressionManager.get_obstacle_complexity())
		content_node = obstacle_result["node"]
		content_width = float(obstacle_result.get("width", 1000.0))
		content_end_pos_local = hill_end_pos_local + Vector2(content_width, 0)

	content_node.position = hill_end_pos_local
	segment.add_child(content_node)

	# Part 3: finalize
	_finalize_segment_generation(segment, content_end_pos_local, allow_cull)

func _generate_special_segment(allow_cull: bool):
	if special_segment_sequence.is_empty() or _special_sequence_index >= special_segment_sequence.size():
		printerr("Attempted to generate a special segment, but sequence is invalid.")
		_is_in_special_chain = false
		_generate_standard_segment(allow_cull)
		return

	var config: SpecialSegmentConfig = special_segment_sequence[_special_sequence_index]
	if not config or not config.scene:
		printerr("Invalid SpecialSegmentConfig at index ", _special_sequence_index)
		_is_in_special_chain = false
		_generate_standard_segment(allow_cull)
		return

	var segment = Node2D.new()
	segment.name = "SpecialSegment_" + str(_special_sequence_index) + "_" + str(_special_sequence_repeats)
	segment.add_to_group("level_segment")
	add_child(segment)
	segment.global_position = _current_spawn_position

	var content_node: Node2D = config.scene.instantiate()
	content_node.position = Vector2.ZERO
	segment.add_child(content_node)

	# Compute end AFTER added to scene so transforms are valid
	var segment_end_pos: Vector2
	var end_marker = content_node.find_child("EndMarker", true, false)
	if end_marker and end_marker is Node2D:
		var end_global: Vector2 = (end_marker as Node2D).global_position
		segment_end_pos = segment.to_local(end_global)
	else:
		printerr("Special scene '", config.scene.resource_path, "' is missing an 'EndMarker' node! Using fallback width.")
		segment_end_pos = Vector2(1000, 0)

	_finalize_segment_generation(segment, segment_end_pos, allow_cull)

	# Update the special sequence progression
	_special_sequence_repeats += 1
	if _special_sequence_repeats >= max(1, config.number_of_times_to_repeat):
		_special_sequence_repeats = 0
		_special_sequence_index += 1
		if _special_sequence_index >= special_segment_sequence.size():
			# Reached the end of the configured chain; stop chaining until next trigger criteria
			_special_sequence_index = special_segment_sequence.size() - 1
			_is_in_special_chain = false

# Shared logic for finishing any segment type.
func _finalize_segment_generation(segment: Node2D, end_pos_local: Vector2, allow_cull: bool):
	# Record start/end (global) for safe culling later
	var start_global: Vector2 = segment.global_position
	var end_global: Vector2 = segment.to_global(end_pos_local)
	segment.set_meta("start_global", start_global)
	segment.set_meta("end_global", end_global)

	# Spawn End Trigger (runtime only)
	if not Engine.is_editor_hint():
		var end_trigger = SEGMENT_END_TRIGGER.instantiate()
		end_trigger.position = end_pos_local
		end_trigger.player_finished_segment.connect(_on_player_finished_segment)
		segment.add_child(end_trigger)

	# Advance spawn position and register segment
	_current_spawn_position = end_global
	_active_segments.append(segment)

	# Cull only if allowed (not during bootstrap or editor preview)
	if allow_cull:
		_maybe_cull_segments()

func _maybe_cull_segments():
	# Keep memory bounded AND never despawn the segment the player is still in.
	if _active_segments.size() <= max_active_segments:
		return

	var player: Node = null
	if player_path != NodePath("") and has_node(player_path):
		player = get_node(player_path)

	if player == null or not (player is Node2D):
		# Without a player reference, be conservative: remove only if we are 2 over the cap
		if _active_segments.size() > max_active_segments + 1:
			var oldest = _active_segments.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
		return

	var p := player as Node2D
	var px := p.global_position.x

	# Try to cull from the front only if its end is comfortably behind the player
	while _active_segments.size() > max_active_segments:
		var oldest: Node2D = _active_segments[0]
		if not is_instance_valid(oldest):
			_active_segments.pop_front()
			continue

		var end_global: Vector2 = oldest.get_meta("end_global", oldest.global_position)
		if end_global.x < px - cull_margin_px:
			_active_segments.pop_front()
			oldest.queue_free()
		else:
			# Oldest is still near/ahead of the player -> don't cull yet
			break

func _on_player_finished_segment():
	# Only complete a "hill" if we were not in a special chain.
	if not _is_in_special_chain:
		ProgressionManager.complete_segment()

	_generate_next_segment()  # allow culling inside generation
