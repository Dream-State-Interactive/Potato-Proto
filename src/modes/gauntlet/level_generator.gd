# src/modes/gauntlet/level_generator.gd
@tool
extends Node2D

@export var generate_in_editor: bool = false:
	set(value):
		generate_in_editor = value
		if generate_in_editor and Engine.is_editor_hint():
			_generate_level_preview()

@export_range(1, 20) var editor_preview_length: int = 5

enum ProgressionMode { SEGMENTS, SCORE }

@export_group("World Theming")
@export var progression_mode: ProgressionMode = ProgressionMode.SEGMENTS
## Assign your WorldTheme resources here. They will be applied in order based on their 'trigger_at_segment_count'.
@export var world_themes: Array[WorldTheme]
## If true, theme progression will only advance after completing a 'hill' segment, ignoring special segments.
## If false, any completed segment will advance theme progression.
@export var progress_theme_on_hills_only: bool = false

@export_group("Generation Config")
## If true, obstacle segments (flat areas with boxes) will be appended to hills.
@export var generate_obstacles: bool = true 
@export_range(2, 20) var max_active_segments: int = 5
@export_range(1, 10) var pregenerate_forward: int = 3
@export_range(1, 10) var pregenerate_backward: int = 2
## The scene that will always be generated first. Must contain a Marker2D named "EndMarker".
@export var start_segment_scene: PackedScene = preload("res://src/modes/gauntlet/start_segment.tscn")

const SEGMENT_BOUNDARY_SCENE = preload("res://src/modes/gauntlet/segment_boundary.tscn")

# --- Node References ---
@onready var hill_generator: Node2D = $HillGenerator
@onready var hazard_generator: Node2D = $HazardGenerator
@onready var obstacle_generator: Node2D = $ObstacleGenerator

# --- State Management ---
var _master_seed: int
var _active_segments: Dictionary = {}
var _segment_end_positions: Dictionary = {}
var _player_current_index: int = 0

# This cache is the core of the new deterministic system. It stores the "recipe" for each segment index.
var _segment_recipe_cache: Dictionary = {}

# These variables are for managing the LIVE theme transition based on player progress.
var _completed_hill_segments: int = 0
var _current_world_theme: WorldTheme = null
var _next_world_theme_index: int = 0

var _player_ref: Node2D = null


func _ready():
	if Engine.is_editor_hint():
		return
	if not world_themes.is_empty():
		world_themes.sort_custom(func(a, b): return a.trigger_at_segment_count < b.trigger_at_segment_count)
	reset_and_generate_initial_segments()


# =====================================
# --- Initialization and Resetting ---
# =====================================
func reset_and_generate_initial_segments():
	_reset_and_initialize()
	_apply_initial_theme()
	_generate_initial_bootstrap_segments()

func _reset_and_initialize():
	for segment in _active_segments.values():
		if is_instance_valid(segment):
			segment.queue_free()
	_active_segments.clear()
	_segment_end_positions.clear()
	_segment_recipe_cache.clear()
	
	_master_seed = randi()
	ProgressionManager.reset(_master_seed)
	
	_player_current_index = 0
	_completed_hill_segments = 0
	_segment_end_positions[-1] = Vector2.ZERO

	# Prime the cache for the start segment. This is the base case for the recursive recipe lookup.
	if start_segment_scene:
		_segment_recipe_cache[0] = {
			"type": "handcrafted", 
			"scene": start_segment_scene, 
			"name": "StartSegment"
		}

func _generate_initial_bootstrap_segments():
	_generate_segment_at_index(0)
	var forward_limit = _player_current_index + pregenerate_forward
	for i in range(1, forward_limit + 1):
		_generate_segment_at_index(i)

func _generate_level_preview():
	for child in get_children():
		if child.is_in_group("level_segment"):
			child.queue_free()
	
	_reset_and_initialize() # Use the same reset logic to ensure cache is primed
	_master_seed = 12345 # Use a fixed seed for consistent previews
	ProgressionManager.reset(_master_seed)

	if not world_themes.is_empty():
		_apply_initial_theme()
		
	for i in range(editor_preview_length):
		_generate_segment_at_index(i)


# ==================================
# --- Live Theme Integration Logic ---
# ==================================
func _apply_initial_theme():
	if not world_themes.is_empty():
		_current_world_theme = world_themes[0]
		_next_world_theme_index = 1
		_apply_world_theme(_current_world_theme, true)
	else:
		printerr("LevelGenerator: No WorldThemes have been configured in the Inspector.")

func _check_and_apply_theme_change():
	if _next_world_theme_index >= world_themes.size():
		return

	var next_theme: WorldTheme = world_themes[_next_world_theme_index]
	var should_trigger := false

	match progression_mode:
		ProgressionMode.SEGMENTS:
			var progress_counter = ProgressionManager.max_forward_index if not progress_theme_on_hills_only else _completed_hill_segments
			should_trigger = progress_counter >= next_theme.trigger_at_segment_count
		
		ProgressionMode.SCORE:
			# Check the Player's Score via GameManager
			if is_instance_valid(GameManager.player_instance):
				should_trigger = GameManager.player_instance.score >= next_theme.trigger_at_score

	if should_trigger:
		_current_world_theme = next_theme
		# Use a slightly longer transition for distance to mask the exact pixel line
		_apply_world_theme(_current_world_theme, false) 
		_next_world_theme_index += 1

func _apply_world_theme(theme: WorldTheme, instant: bool):
	if not is_instance_valid(theme):
		printerr("Attempted to apply an invalid WorldTheme resource.")
		return

	if is_instance_valid(theme.theme_data):
		if instant or Engine.is_editor_hint():
			ThemeManager.apply_theme(theme.theme_data)
		else:
			ThemeManager.transition_to_theme(theme.theme_data, 2.5)

	if is_instance_valid(hazard_generator) and not theme.hazard_configs.is_empty():
		hazard_generator.hazard_configs = theme.hazard_configs


# =============================
# --- Core Generation Logic ---
# =============================
func _ensure_surrounding_segments_exist():
	var forward_limit = _player_current_index + pregenerate_forward
	for i in range(_player_current_index, forward_limit + 1):
		_generate_segment_at_index(i)

	var backward_limit = _player_current_index - pregenerate_backward
	for i in range(_player_current_index - 1, backward_limit - 1, -1):
		_generate_segment_at_index(i)
	
	_maybe_cull_segments()

func _generate_segment_at_index(index: int):
	if index < 0 or _active_segments.has(index):
		return

	var recipe = _get_or_decide_segment_recipe(index)
	if recipe.is_empty():
		printerr("Failed to get or decide recipe for segment index: ", index)
		return

	var segment_seed = ProgressionManager.get_seed_for_index(index)
	var result: Dictionary

	match recipe.type:
		"handcrafted":
			result = _generate_handcrafted_segment(recipe.name + "_" + str(index), recipe.scene)
		"store":
			result = _generate_handcrafted_segment("StoreSegment_" + str(index), recipe.scene)
		"hill":
			result = _generate_procedural_segment(index, segment_seed, recipe)
		_:
			printerr("Encountered unknown recipe type: '", recipe.type, "' for index: ", index)
			return

	if result.is_empty():
		printerr("Failed to generate segment node for index: ", index)
		return

	var segment: Node2D = result["node"]
	var end_pos_local: Vector2 = result["end_pos_local"]

	var spawn_pos = _segment_end_positions.get(index - 1, Vector2.ZERO)
	add_child(segment)
	segment.global_position = spawn_pos
	_segment_end_positions[index] = segment.to_global(end_pos_local)

	_active_segments[index] = segment
	_finalize_segment_generation(segment, index, end_pos_local)


# ============================
# --- Deterministic System ---
# ============================
func _get_or_decide_segment_recipe(index: int) -> Dictionary:
	if index in _segment_recipe_cache:
		return _segment_recipe_cache[index]
	if index < 0:
		return {}

	var segment_seed = ProgressionManager.get_seed_for_index(index)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = segment_seed

	var theme_for_rules = _get_theme_for_index(index)
	var recipe: Dictionary

	if not is_instance_valid(theme_for_rules):
		recipe = {"type": "hill", "profile": null} # Fallback if no themes are configured
		_segment_recipe_cache[index] = recipe
		return recipe

	# 1. Check for Handcrafted Segments
	if not theme_for_rules.handcrafted_segments.is_empty():
		for rule in theme_for_rules.handcrafted_segments:
			if is_instance_valid(rule) and rule.scene:
				var is_on_cooldown = false
				for i in range(1, rule.min_hills_between_spawns + 1):
					var prev_recipe = _get_or_decide_segment_recipe(index - i)
					if prev_recipe and (prev_recipe.type == "handcrafted" or prev_recipe.type == "store"):
						is_on_cooldown = true
						break
				
				if not is_on_cooldown and local_rng.randf() < rule.probability:
					recipe = {"type": "handcrafted", "scene": rule.scene, "name": "SpecialSegment"}
					_segment_recipe_cache[index] = recipe
					return recipe

	# 2. Check for Stores
	var store_rules = theme_for_rules.store_rules
	if is_instance_valid(store_rules):
		var is_on_cooldown = false
		for i in range(1, store_rules.min_hills_between_stores + 1):
			var prev_recipe = _get_or_decide_segment_recipe(index - i)
			if prev_recipe and prev_recipe.type == "store":
				is_on_cooldown = true
				break
		
		if not is_on_cooldown and local_rng.randf() < store_rules.regular_store_probability:
			var store_scene = store_rules.regular_store_scene
			if is_instance_valid(store_rules.special_store_scene) and local_rng.randf() < store_rules.special_store_chance:
				store_scene = store_rules.special_store_scene
			
			if store_scene:
				recipe = {"type": "store", "scene": store_scene}
				_segment_recipe_cache[index] = recipe
				return recipe

	# 3. Default to a procedural hill
	var profile = _weighted_choice(theme_for_rules.hill_profiles, local_rng)
	recipe = {"type": "hill", "profile": profile}
	_segment_recipe_cache[index] = recipe
	return recipe

func _get_theme_for_index(index: int) -> WorldTheme:
	if world_themes.is_empty():
		return null

	var theme_to_use = world_themes[0]
	var progress_counter = 0

	if progress_theme_on_hills_only:
		var hill_count = 0
		for i in range(index):
			var recipe = _get_or_decide_segment_recipe(i)
			if recipe and recipe.type == "hill":
				hill_count += 1
		progress_counter = hill_count
	else:
		progress_counter = index

	for theme in world_themes:
		if progress_counter >= theme.trigger_at_segment_count:
			theme_to_use = theme
		else:
			break
			
	return theme_to_use


# =======================================
# --- Segment Instantiation Functions ---
# =======================================
func _generate_procedural_segment(index: int, segment_seed: int, recipe: Dictionary) -> Dictionary:
	var segment = Node2D.new()
	segment.name = "HillSegment_" + str(index)
	segment.add_to_group("level_segment")
	segment.set_meta("segment_type", "hill")

	var hill_params: Dictionary
	var hill_profile: HillProfile = recipe.get("profile")

	if is_instance_valid(hill_profile) and is_instance_valid(hill_profile.hill_parameters):
		var params_res = hill_profile.hill_parameters
		hill_params = {
			"length": params_res.length, "amplitude": params_res.amplitude,
			"slope": params_res.slope, "steepness_increase": params_res.steepness_increase,
			"frequency": params_res.frequency, "control_step": params_res.control_step,
			"visual_bake_interval": params_res.visual_bake_interval,
			"collision_bake_interval": params_res.collision_bake_interval,
			"simplify_epsilon_px": params_res.simplify_epsilon_px,
			"max_collision_vertices": params_res.max_collision_vertices,
			"generator_type": params_res.generator_type
		}
	else:
		hill_params = ProgressionManager.get_hill_parameters(index)

	# The color of the hill should come from the LIVE theme for smooth visual transitions.
	if is_instance_valid(_current_world_theme) and is_instance_valid(_current_world_theme.theme_data):
		hill_params["color"] = _current_world_theme.theme_data.terrain_fill
	
	var should_spawn_starch = (index > ProgressionManager.max_forward_index)
	var hill_result = hill_generator.generate_hill(hill_params, segment_seed, not should_spawn_starch)
	var hill_node: Node2D = hill_result["node"]
	hill_node.z_as_relative = false
	hill_node.z_index = 5
	var hill_end_pos_local: Vector2 = hill_result["end_position"]
	segment.add_child(hill_node)
	
	var spawn_pts: PackedVector2Array = hill_result.get("spawn_points", hill_result["surface_points"])
	var hazards_node: Node2D = hazard_generator.generate(spawn_pts, segment_seed, index)
	if hazards_node:
		hill_node.add_child(hazards_node)

	# --- OBSTACLE GENERATION LOGIC ---
	# Initialize content_end_pos_local to the hill's end. 
	# If obstacles are generated, this will be updated.
	var content_end_pos_local = hill_end_pos_local

	if generate_obstacles:
		var obstacle_result = obstacle_generator.generate_obstacle(ProgressionManager.get_obstacle_complexity(index))
		var content_node = obstacle_result["node"]
		# Add the obstacle width to the total segment length
		content_end_pos_local = hill_end_pos_local + Vector2(float(obstacle_result.get("width", 1000.0)), 0)
		content_node.position = hill_end_pos_local
		segment.add_child(content_node)
	
	return {"node": segment, "end_pos_local": content_end_pos_local}

func _generate_handcrafted_segment(segment_name: String, scene: PackedScene) -> Dictionary:
	if not scene:
		printerr("Attempted to generate a handcrafted segment with a null scene: ", segment_name)
		return {}
		
	var segment = Node2D.new()
	segment.name = segment_name
	segment.add_to_group("level_segment")
	segment.set_meta("segment_type", "special")
	
	var content_node: Node2D = scene.instantiate()
	segment.add_child(content_node)
	
	var end_marker = content_node.find_child("EndMarker", true, false)
	if not end_marker:
		printerr("Handcrafted scene '", scene.resource_path, "' is missing an 'EndMarker' node!")
		return {"node": segment, "end_pos_local": Vector2(1000, 0)}

	return {"node": segment, "end_pos_local": end_marker.position}

func _finalize_segment_generation(segment: Node2D, index: int, end_pos_local: Vector2):
	segment.set_meta("segment_index", index)
	if not Engine.is_editor_hint():
		var boundary = SEGMENT_BOUNDARY_SCENE.instantiate()
		segment.add_child(boundary)
		boundary.position = end_pos_local
		boundary.segment_index = index
		boundary.player_crossed_boundary.connect(_on_player_crossed_boundary)


# =====================================
# --- Player Movement and Culling ---
# =====================================
func _on_player_crossed_boundary(from_index: int, direction: int):
	_player_current_index = from_index + direction

	if direction > 0:
		var recipe = _get_or_decide_segment_recipe(from_index)
		if recipe and recipe.type == "hill":
			_completed_hill_segments += 1
		
		ProgressionManager.update_progress(_player_current_index)
		
		_check_and_apply_theme_change()
	
	call_deferred("_ensure_surrounding_segments_exist")

func _maybe_cull_segments():
	var cull_indices = []
	for index in _active_segments.keys():
		if index > _player_current_index + pregenerate_forward or \
		   index < _player_current_index - pregenerate_backward:
			cull_indices.append(index)
	for index in cull_indices:
		var segment = _active_segments.get(index)
		if is_instance_valid(segment):
			segment.queue_free()
		_active_segments.erase(index)

func _weighted_choice(items: Array, rng: RandomNumberGenerator) -> Variant:
	if items.is_empty(): return null
	var total_weight: float = 0.0
	for item in items:
		if item and "weight" in item:
			total_weight += item.weight
			
	if total_weight <= 0.0:
		if items.is_empty(): return null
		return items.pick_random()
		
	var choice: float = rng.randf() * total_weight
	var current_weight: float = 0.0
	for item in items:
		if item and "weight" in item:
			current_weight += item.weight
			if choice < current_weight:
				return item
				
	return items[-1]
