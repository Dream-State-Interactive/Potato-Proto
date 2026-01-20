# src/tools/LevelGen/core/level_maker_modular.gd
extends Node2D

# =======================================================================
# =========================  CONFIGURATION  =============================
# =======================================================================

@export_group("Active Settings")
## The base width of a procedural chunk in pixels.
@export var chunk_size: int = 1024
## The default biome used before any specific map entries trigger.
@export var current_biome: BiomeProfile
## Optional scene to spawn at Index 0 (Game Start).
@export var starting_segment: PackedScene
## The player to track for generation. Auto-assigned via GameManager if null.
@export var player_node: Node2D

@export_group("Level Flow")
## Ordered list of biome transitions. Converted to a Dictionary at runtime for O(1) lookup.
@export var biome_list: Array[BiomeEntry] = []
## Ordered list of terrain overrides. Defined by a user-specified Curve2D.
@export var terrain_overrides: Array[TerrainOverride] = []
# Runtime cache: chunk_index -> BiomeProfile
var _biome_map_cache: Dictionary = {}

@export_group("Handcrafted Levels")
## specific scenes to spawn at specific chunk indices (e.g., Boss arenas, Shops).
@export var special_chunk_list: Array[SpecialChunkEntry] = []
# Runtime cache: chunk_index -> PackedScene
var _special_chunks_cache: Dictionary = {}

@export_group("Visuals")
## Distance ahead of the player to generate collision/gameplay chunks.
@export var render_distance_px: float = 4000.0
## Distance behind the player to unload chunks.
@export var delete_distance_px: float = 4000.0
## How many extra background chunks to generate beyond biome boundaries to prevent gaps.
@export var bg_padding_chunks: int = 2
## Shifts all background layers to the right (positive) or left (negative) in pixels.
@export var global_bg_offset_x: float = 200.0

@export_group("Biome Transitions")
## Duration (seconds) for the background layer opacity crossfade.
@export var biome_transition_time: float = 1.0
## Distance ahead of the camera to generate the NEXT biome's background (invisible) to prevent pop-in.
@export var biome_prewarm_px: float = 2500.0
## Fade-in duration for individual background chunks when they first spawn.
@export var bg_chunk_fade_time: float = 0.25

# =======================================================================
# ============================  INTERNAL  ===============================
# =======================================================================

const _INF := 1.0e18

var _world_env: WorldEnvironment
var _atmosphere_controller: Node2D

# Active Background Layers
# Key: LayerProfile Instance ID
# Value: { 
#   "container": Parallax2D, 
#   "chunks": { idx: Node2D }, 
#   "profile": LayerProfile, 
#   "biome": BiomeProfile, 
#   "start_x": float, 
#   "end_x": float 
# }
var _bg_layers: Dictionary = {}

# History of biome boundaries in world space.
# Used to clamp background layers so they don't bleed into previous/next biomes.
# Element: { "biome": BiomeProfile, "start_x": float, "end_x": float }
var _biome_segments: Array = []

# Active Gameplay Nodes
# Key: Chunk Index (int)
# Value: { "node": Node2D, "start_x": float, "end_x": float }
var _gameplay_chunks: Dictionary = {}

# Persistent Metadata Registry
# Stores the definition of every chunk generated so far.
# Allows us to respawn chunks (backtracking) exactly as they were initially generated.
# Key: Chunk Index (int)
# Value: { "start": Vector2, "end": Vector2, "biome": BiomeProfile, "scene": PackedScene }
var _chunk_meta: Dictionary = {}

# Generation Frontier Tracking
var _max_generated_index: int = -1
var _last_end_position: Vector2 = Vector2.ZERO

# Current Loading Window indices
var _loaded_min_idx: int = 0
var _loaded_max_idx: int = 0

# Visual State
var _default_biome: BiomeProfile
var _visual_biome: BiomeProfile

# Crossfade State
var _fade_from_biome: BiomeProfile = null
var _biome_fade_tween: Tween = null

# Sky System
var _sky_canvas: CanvasLayer
var _sky_rect: TextureRect
var _sky_gradient: GradientTexture2D
var _active_sky_tween: Tween
var _celestial_node: Node2D

# Shared state passed to ProcAssets (e.g. for height continuity between assets)
var _shared_state: Dictionary = {}

# =======================================================================
# ==========================  GODOT FUNCS  ==============================
# =======================================================================

func _ready():
	# Convert Inspector Arrays to Dictionaries for faster runtime lookups
	for entry in biome_list:
		if entry and entry.biome:
			_biome_map_cache[entry.chunk_index] = entry.biome

	for entry in special_chunk_list:
		if entry and entry.scene:
			_special_chunks_cache[entry.chunk_index] = entry.scene

	_setup_sky()
	
	_setup_world_env()

	# Hook into Global Player events
	if GameManager.player_instance:
		player_node = GameManager.player_instance
	if GameManager.has_signal("player_is_ready"):
		if not GameManager.player_is_ready.is_connected(_on_player_ready):
			GameManager.player_is_ready.connect(_on_player_ready)

	_default_biome = current_biome
	_visual_biome = current_biome

	AudioService.play_music(current_biome.music, 1.0, Vector2(0,0), true, "LevelMusic", true)

	# Initialize the first biome segment (infinite to the left)
	_begin_biome_segment_if_needed(_default_biome, -100000.0)
	_apply_biome_visuals(_default_biome, 0.0)

	# Bootstrap generation: Backfill (-1) and Start (0)
	if starting_segment:
		_spawn_gameplay_chunk(0, Vector2.ZERO, starting_segment)
	else:
		_spawn_gameplay_chunk(-1, Vector2(-chunk_size, 0), null)
		_spawn_gameplay_chunk(0, _last_end_position, null)

	_loaded_min_idx = _min_loaded_from_loaded()
	_loaded_max_idx = _max_loaded_from_loaded()

func _on_player_ready(p):
	player_node = p

func _process(_delta):
	# robust player validation
	if not is_instance_valid(player_node):
		if GameManager.player_instance:
			player_node = GameManager.player_instance
		else:
			return
	elif GameManager.player_instance and player_node != GameManager.player_instance:
		player_node = GameManager.player_instance

	var p_pos: Vector2 = player_node.global_position

	# Calculate current chunk based on X. 
	# Note: This is an approximation for visual transitions; gameplay logic uses _chunk_meta.
	var player_chunk_index: int = _get_chunk_index_at_x(p_pos.x)

	# 1. Visuals: Handle Sky/Music/BG Crossfading based on player location
	_update_visual_biome(player_chunk_index)

	# 2. Gameplay: Generate forward, respawn backward
	_update_gameplay_window(p_pos.x)

	# 3. Backgrounds: Manage Parallax layers (spawn/cull/move)
	_update_background_parallax(p_pos.x)
	
	# 4. Cleanup
	_cull_chunks(p_pos.x)
	_update_sky()

# =======================================================================
# =====================  GAMEPLAY LAYER (WINDOW)  =======================
# =======================================================================

## Manages the "Sliding Window" of active gameplay chunks.
## Generates new chunks if moving forward, re-instantiates old chunks if moving backward.
func _update_gameplay_window(player_x: float) -> void:
	# 1) Generate forward (Frontier)
	while player_x + render_distance_px > _last_end_position.x:
		var next_idx: int = _max_generated_index + 1
		var special_scene: PackedScene = _special_chunks_cache.get(next_idx, null)
		_spawn_gameplay_chunk(next_idx, _last_end_position, special_scene)

	# 2) Ensure symmetric loaded window (Backtracking support)
	var player_idx: int = _get_chunk_index_at_x(player_x)
	# Calculate how many chunks fit in the render distance + padding
	var pad: int = int(ceil(render_distance_px / float(chunk_size))) + 2

	var want_min: int = player_idx - pad
	var want_max: int = player_idx + pad

	for i in range(want_min, want_max + 1):
		# If we have meta (it was generated before) but no active node, respawn it
		if _chunk_meta.has(i) and not _gameplay_chunks.has(i):
			_respawn_chunk(i)

## Re-creates a previously generated chunk using stored metadata.
## Ensures terrain continuity is preserved when backtracking.
func _respawn_chunk(idx: int) -> void:
	if _gameplay_chunks.has(idx): return
	if not _chunk_meta.has(idx): return

	var meta: Dictionary = _chunk_meta[idx] as Dictionary
	var start_pos: Vector2 = meta.get("start", Vector2.ZERO)
	var end_pos: Vector2 = meta.get("end", start_pos + Vector2(chunk_size, 0))
	var biome: BiomeProfile = meta.get("biome", _default_biome)
	var explicit_scene: PackedScene = meta.get("scene", null)

	var container: Node2D = get_node_or_null("Gameplay_Layer")
	if not container:
		container = Node2D.new()
		container.name = "Gameplay_Layer"
		container.z_index = 0
		add_child(container)

	var chunk_node: Node2D = null

	if explicit_scene:
		chunk_node = explicit_scene.instantiate()
		chunk_node.name = "Special_%d" % idx
		chunk_node.position = start_pos
		container.add_child(chunk_node)
	else:
		var profile: LayerProfile = _get_gameplay_layer_profile_for_biome(biome)

		chunk_node = Node2D.new()
		chunk_node.name = "Proc_%d" % idx
		chunk_node.position = Vector2(start_pos.x, 0)
		container.add_child(chunk_node)

		if profile:
			# Pass start_pos.y as snap_y to ensure vertices align with neighbor
			_generate_assets_for_node(chunk_node, profile, idx, start_pos.x, chunk_size, start_pos.y)

	_gameplay_chunks[idx] = { "node": chunk_node, "start_x": start_pos.x, "end_x": end_pos.x }
	_loaded_min_idx = min(_loaded_min_idx, idx)
	_loaded_max_idx = max(_loaded_max_idx, idx)

## Generates a brand new chunk at the frontier.
func _spawn_gameplay_chunk(idx: int, start_pos: Vector2, explicit_scene: PackedScene):
	var container: Node2D = get_node_or_null("Gameplay_Layer")
	if not container:
		container = Node2D.new(); container.name = "Gameplay_Layer"; container.z_index = 0
		add_child(container)

	var chunk_biome: BiomeProfile = _get_biome_for_index(idx)
	if chunk_biome:
		_begin_biome_segment_if_needed(chunk_biome, start_pos.x)
	else:
		chunk_biome = _default_biome
	
	# Scale Logic
	var s: float = chunk_biome.scale if chunk_biome else 1.0
	# Force 1.0 for starting segment if needed
	if explicit_scene and explicit_scene == starting_segment:
		s = 1.0

	var chunk_node: Node2D = null
	
	# Default end position (will be overwritten)
	var new_end_pos: Vector2 = start_pos + Vector2(chunk_size * s, 0)

	if explicit_scene:
		# --- HANDCRAFTED ---
		chunk_node = explicit_scene.instantiate()
		chunk_node.name = "Special_%d" % idx
		chunk_node.position = start_pos
		chunk_node.scale = Vector2(s, s) 
		container.add_child(chunk_node)

		var marker = chunk_node.find_child("EndMarker", true, false)
		if marker:
			# Marker position is local, so we scale it to get World Offset
			new_end_pos = start_pos + (marker.position * s)
		else:
			push_warning("Special Chunk %d missing 'EndMarker'!" % idx)
	else:
		# --- PROCEDURAL ---
		var profile: LayerProfile = _get_gameplay_layer_profile_for_biome(chunk_biome)

		if profile:
			chunk_node = Node2D.new()
			chunk_node.name = "Proc_%d" % idx
			# Node is placed at World X, World Y=0 (Verticals handled by vertex offsets)
			chunk_node.position = Vector2(start_pos.x, 0)
			chunk_node.scale = Vector2(s, s)
			container.add_child(chunk_node)

			var ctx = _generate_assets_for_node(chunk_node, profile, idx, start_pos.x, chunk_size, start_pos.y)
			
			if ctx and not ctx.terrain_curve.is_empty():
				# Convert Local Y End to World Y End by multiplying by Scale
				var world_y_end = ctx.terrain_y_end * s
				new_end_pos = Vector2(start_pos.x + (chunk_size * s), world_y_end)
			else:
				# Fallback: Maintain current height
				new_end_pos = Vector2(start_pos.x + (chunk_size * s), start_pos.y)
		else:
			chunk_node = Node2D.new()
			chunk_node.name = "Empty_%d" % idx
			chunk_node.position = Vector2(start_pos.x, 0)
			container.add_child(chunk_node)

	_gameplay_chunks[idx] = { "node": chunk_node, "start_x": start_pos.x, "end_x": new_end_pos.x }

	_chunk_meta[idx] = {
		"start": start_pos,
		"end": new_end_pos,
		"biome": chunk_biome,
		"scene": explicit_scene
	}

	_max_generated_index = max(_max_generated_index, idx)
	_last_end_position = new_end_pos

	_loaded_min_idx = min(_loaded_min_idx, idx)
	_loaded_max_idx = max(_loaded_max_idx, idx)

# =======================================================================
# ====================  BACKGROUND LAYERS (PARALLAX)  ===================
# =======================================================================

## Registers a new biome segment if the biome has changed.
## Caps the previous segment so its background layers stop spawning chunks.
func _begin_biome_segment_if_needed(biome: BiomeProfile, start_world_x: float) -> void:
	if biome == null: return

	# If duplicate call for same biome, ignore
	if _biome_segments.size() > 0:
		var last_seg = _biome_segments[_biome_segments.size() - 1]
		if last_seg.get("biome", null) == biome:
			return

	# Close previous segment
	if _biome_segments.size() > 0:
		var prev: Dictionary = _biome_segments[_biome_segments.size() - 1] as Dictionary
		var buffer_dist = render_distance_px + (chunk_size * bg_padding_chunks)
		var extended_end_x = start_world_x + buffer_dist
		prev["end_x"] = extended_end_x
		_biome_segments[_biome_segments.size() - 1] = prev
		_set_biome_bg_end(prev.get("biome", null), extended_end_x)

	# Start new segment
	_biome_segments.append({ "biome": biome, "start_x": start_world_x, "end_x": _INF })
	_ensure_biome_bg_layers_initialized(biome, start_world_x)

## Creates Parallax2D containers for a specific biome starting at a specific X.
func _ensure_biome_bg_layers_initialized(biome: BiomeProfile, start_world_x: float):
	# Get the global scale (default 1.0)
	var b_scale: float = biome.scale if biome else 1.0
	
	for layer in biome.layers:
		if _is_gameplay_layer(layer): continue

		var pid: int = layer.get_instance_id()
		if _bg_layers.has(pid): continue

		var p_node := Parallax2D.new()
		p_node.name = "Parallax_%d" % pid
		p_node.scroll_scale = layer.parallax_speed
		p_node.z_index = layer.z_index
		p_node.repeat_size = Vector2.ZERO

		var offset_x: float = (start_world_x * layer.parallax_speed.x) + global_bg_offset_x
		
		# Y offset usually needs to be scaled visually if it's a fixed height offset
		var offset_y: float = layer.y_offset 
		
		p_node.scroll_offset = Vector2(offset_x, offset_y)

		add_child(p_node)

		_bg_layers[pid] = {
			"container": p_node,
			"chunks": {},
			"profile": layer,
			"biome": biome,
			"start_x": start_world_x,
			"end_x": _INF
		}

func _set_biome_bg_end(biome: BiomeProfile, end_world_x: float):
	if biome == null: return
	for pid in _bg_layers.keys():
		var d: Dictionary = _bg_layers[pid] as Dictionary
		var d_biome: BiomeProfile = d.get("biome", null)
		if d_biome == biome:
			d["end_x"] = end_world_x
			_bg_layers[pid] = d

# -----------------------------------------
# --- Visual biome crossfade controller ---
# -----------------------------------------
func _update_visual_biome(player_chunk_index: int) -> void:
	var target: BiomeProfile = _get_biome_for_index(player_chunk_index)
	if not target or target == _visual_biome:
		return
	_start_biome_crossfade(_visual_biome, target, biome_transition_time)

func _start_biome_crossfade(from_biome: BiomeProfile, to_biome: BiomeProfile, duration: float) -> void:
	_fade_from_biome = from_biome
	_visual_biome = to_biome
	current_biome = to_biome

	# Ensure target layers exist (prewarm logic usually handles this, but safety first)
	var to_start_x: float = _get_latest_segment_start_x(to_biome)
	_ensure_biome_bg_layers_initialized(to_biome, to_start_x)

	# Set initial alphas
	_set_biome_bg_alpha(to_biome, 0.0)
	if from_biome:
		_set_biome_bg_alpha(from_biome, 1.0)

	if _biome_fade_tween:
		_biome_fade_tween.kill()

	_biome_fade_tween = create_tween().set_parallel(true)

	# Fade IN new
	_biome_fade_tween.tween_method(func(a: float): _set_biome_bg_alpha(to_biome, a), 0.0, 1.0, duration)

	# Fade OUT old
	if from_biome:
		_biome_fade_tween.tween_method(func(a: float): _set_biome_bg_alpha(from_biome, a), 1.0, 0.0, duration)

	_biome_fade_tween.finished.connect(func():
		_fade_from_biome = null
	)

	_apply_biome_visuals(to_biome, duration)

func _set_biome_bg_alpha(biome: BiomeProfile, a: float) -> void:
	if biome == null: return

	for pid in _bg_layers.keys():
		var d: Dictionary = _bg_layers[pid] as Dictionary
		var d_biome: BiomeProfile = d.get("biome", null)
		if d_biome != biome: continue

		var container: Parallax2D = d.get("container", null) as Parallax2D
		if container and is_instance_valid(container):
			var m := container.modulate
			m.a = a
			container.modulate = m
			container.visible = true

func _get_latest_segment_start_x(biome: BiomeProfile) -> float:
	for i in range(_biome_segments.size() - 1, -1, -1):
		var seg: Dictionary = _biome_segments[i] as Dictionary
		var b: BiomeProfile = seg.get("biome", null)
		if b == biome:
			return float(seg.get("start_x", 0.0))
	return 0.0

func _get_next_segment_after_x(x: float):
	var best = null
	var best_start: float = _INF
	for seg in _biome_segments:
		var d: Dictionary = seg as Dictionary
		var sx: float = float(d.get("start_x", _INF))
		if sx > x and sx < best_start:
			best_start = sx
			best = d
	return best

## Main Background loop: Spawns/Culls/Fades background layers based on player position.
func _update_background_parallax(player_x: float):
	var active_biomes: Dictionary = {}

	# 1. Mark current visual biome active
	if _visual_biome:
		active_biomes[_visual_biome.get_instance_id()] = true

	# 2. Mark fading-out biome active
	if _fade_from_biome and _biome_fade_tween and _biome_fade_tween.is_running():
		active_biomes[_fade_from_biome.get_instance_id()] = true

	# 3. Prewarm the NEXT biome (generate it but keep alpha 0)
	var next_seg = _get_next_segment_after_x(player_x)
	if next_seg != null:
		var next_biome: BiomeProfile = next_seg.get("biome", null)
		var next_start_x: float = float(next_seg.get("start_x", _INF))
		# Add the padding width to the prewarm check
		var world_width_estimate = chunk_size / 0.5 # Estimate based on mid-ground speed
		var total_prewarm = biome_prewarm_px + (bg_padding_chunks * world_width_estimate)
		if next_biome and (next_start_x - player_x) <= total_prewarm:
			active_biomes[next_biome.get_instance_id()] = true
			if next_biome != _visual_biome and next_biome != _fade_from_biome:
				_set_biome_bg_alpha(next_biome, 0.0)

	# If near the start of a new segment, keep the previous biome active so it can generate its "buffer" chunks.
	if _biome_segments.size() > 0:
		for i in range(_biome_segments.size()):
			var seg = _biome_segments[i]
			# If player is within this segment's [start, end] range (including the buffer), keep it active
			if player_x >= float(seg.start_x) - render_distance_px and player_x <= float(seg.end_x) + render_distance_px:
				var b = seg.get("biome", null)
				if b: active_biomes[b.get_instance_id()] = true

	var keys_to_remove: Array = []
	for pid in _bg_layers.keys():
		var layer_data: Dictionary = _bg_layers[pid] as Dictionary
		var biome: BiomeProfile = layer_data.get("biome", null)
		if biome == null: continue

		var bid: int = biome.get_instance_id()
		var should_process: bool = active_biomes.has(bid)

		var container: Parallax2D = layer_data.get("container", null) as Parallax2D
		if container and is_instance_valid(container):
			container.visible = should_process

		if should_process:
			var profile: LayerProfile = layer_data.get("profile", null)
			_process_bg_layer(layer_data, profile, player_x)

		var end_x: float = float(layer_data.get("end_x", _INF))
		if end_x < _INF and (player_x - delete_distance_px) > end_x:
			if container and is_instance_valid(container):
				container.queue_free()
			keys_to_remove.append(pid)

	for k in keys_to_remove:
		_bg_layers.erase(k)


func _process_bg_layer(layer_data: Dictionary, profile: LayerProfile, player_x: float):
	if profile == null: return
	var chunks: Dictionary = layer_data.get("chunks", {})
	var parent: Parallax2D = layer_data.get("container", null)
	if not parent: return

	var dist: int = int(profile.render_distance)
	var speed: float = float(profile.parallax_speed.x)
	if speed <= 0.0001: speed = 0.0001
	
	# Get Scale
	var biome: BiomeProfile = layer_data.get("biome")
	var b_scale: float = biome.scale if biome else 1.0

	var start_x: float = float(layer_data.get("start_x", 0.0))
	var end_x: float = float(layer_data.get("end_x", _INF))

	# 1. Relative position in biome (World Space)
	var dist_from_start: float = player_x - start_x

	# 2. Effective width of one chunk in World Space (due to parallax slowdown + scale)
	var effective_width_world: float = (float(chunk_size) * b_scale) / speed

	# 3. Center Index (Relative to Biome Start)
	var center_idx: int = int(floor(dist_from_start / effective_width_world))

	# 4. Calculate Local Bounds for Culling
	# We want chunks to exist from Local 0 up to Local End
	var local_limit_start = 0.0
	var local_limit_end = _INF
	
	if end_x < _INF:
		var total_world_len = end_x - start_x
		# Convert World Length -> Local Parallax Length
		# Local = World * Speed
		local_limit_end = total_world_len * speed

	for idx in range(center_idx - dist, center_idx + dist + 1):
		
		# Calculate this chunk's local range
		var chunk_local_start = idx * (chunk_size * b_scale)
		var chunk_local_end = (idx + 1) * (chunk_size * b_scale)
		
		# Allow padding so chunks don't pop out instantly at the edges
		var bleed = (chunk_size * b_scale) * float(max(1, bg_padding_chunks))
	
		# Is chunk entirely before the biome starts?
		if chunk_local_end <= local_limit_start - bleed: continue
	
		# Is chunk entirely after the biome ends?
		if local_limit_end < _INF and chunk_local_start >= local_limit_end + bleed: continue

		if chunks.has(idx): continue

		var chunk_root := Node2D.new()
		chunk_root.name = "BG_%d" % idx
		
		# Apply Scale
		chunk_root.scale = Vector2(b_scale, b_scale)
		# Position is standard local grid
		chunk_root.position.x = idx * (chunk_size * b_scale)
		
		chunk_root.modulate = Color(1, 1, 1, 0)
		parent.add_child(chunk_root)

		# Gen X for Noise: Continuous based on unscaled grid
		var gen_x: float = (start_x * speed) + (float(idx) * float(chunk_size))
		
		# Pass gen_x as the final argument (world_x) so overrides look up the correct absolute position
		_generate_assets_for_node(chunk_root, profile, idx, gen_x, chunk_size, NAN, gen_x)

		chunks[idx] = chunk_root

		if bg_chunk_fade_time > 0.0:
			var tw := create_tween()
			tw.tween_property(chunk_root, "modulate", Color(1, 1, 1, 1), bg_chunk_fade_time)

	# Cull
	for k in chunks.keys():
		var i: int = int(k)
		if i < center_idx - dist or i > center_idx + dist:
			var n: Node2D = chunks[k]
			if n and is_instance_valid(n):
				n.queue_free()
			chunks.erase(k)

	layer_data["chunks"] = chunks

# =======================================================================
# ==========================  SHARED GEN LOGIC  =========================
# =======================================================================
func _setup_world_env():
	if has_node("WorldEnvironment"):
		_world_env = get_node("WorldEnvironment")
	else:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		var e_res = Environment.new()
		e_res.background_mode = Environment.BG_CANVAS
		_world_env.environment = e_res
		add_child(_world_env)

func _generate_assets_for_node(node: Node2D, profile: LayerProfile, idx: int, gen_x: float, size: float, snap_y: float, world_x: float = NAN) -> ProcContext:
	var ctx = ProcContext.new()
	ctx.chunk_index = idx
	ctx.global_x = gen_x
	ctx.chunk_size = int(size)
	ctx.parent_node = node
	ctx.snap_y = snap_y
	ctx.shared_state = _shared_state.duplicate()
	ctx.terrain_overrides = terrain_overrides
	
	# Determine if BG and set Parallax Factor for coordinate projection
	ctx.is_background = not _is_gameplay_layer(profile)
	ctx.parallax_factor = profile.parallax_speed.x
	
	# Safety for 0.0 speed (fixed backgrounds) to prevent division by zero later
	if is_equal_approx(ctx.parallax_factor, 0.0):
		ctx.parallax_factor = 0.0001
	
	# If this is the gameplay layer, world_x is just idx * size.
	# If it's a BG layer, world_x is passed in as the parallax-corrected coordinate (gen_x).
	if is_nan(world_x):
		world_x = float(idx * chunk_size)
	
	# Pass the correct world coordinate for noise and override detection
	ctx.global_x = world_x 

	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = (idx * 420) ^ (profile.z_index * 420)

	for asset in profile.assets:
		if not asset: continue
		
		# --- PROBABILITY CHECK ---
		# We roll a float between 0.0 and 1.0. 
		# If the roll is higher than the probability, we skip this asset.
		if ctx.rng.randf() > asset.probability:
			continue
			
		# --- TERRAIN SNAP CHECK ---
		# If the asset requires a terrain curve but none has been generated yet 
		# (if you put a Tree before the Terrain in the array), we skip it.
		if asset.snaps_to_terrain and ctx.terrain_curve.is_empty():
			continue
			
		# If all checks pass, generate the asset
		asset.generate(ctx)
	
	return ctx

func _is_gameplay_layer(layer: LayerProfile) -> bool:
	return is_equal_approx(layer.parallax_speed.x, 1.0) and (is_equal_approx(layer.parallax_speed.y, 1.0) or is_equal_approx(layer.parallax_speed.y, 0.0))

func _get_gameplay_layer_profile_for_biome(biome: BiomeProfile) -> LayerProfile:
	if not biome: return null
	for layer in biome.layers:
		if _is_gameplay_layer(layer):
			return layer
	return null

# =======================================================================
# ============================  UTILITIES  ==============================
# =======================================================================

func _cull_chunks(player_x: float):
	var indices = _gameplay_chunks.keys()
	for idx in indices:
		var data: Dictionary = _gameplay_chunks[idx] as Dictionary
		var start_x: float = float(data.get("start_x", 0.0))
		var end_x: float = float(data.get("end_x", 0.0))
		var node: Node2D = data.get("node", null)

		# Cull behind
		if end_x < player_x - delete_distance_px:
			if node and is_instance_valid(node):
				node.queue_free()
			_gameplay_chunks.erase(idx)
			continue

		# Cull ahead (if player teleported back)
		if start_x > player_x + delete_distance_px:
			if node and is_instance_valid(node):
				node.queue_free()
			_gameplay_chunks.erase(idx)
			continue

func _get_biome_for_index(idx: int) -> BiomeProfile:
	var keys = _biome_map_cache.keys()
	keys.sort()
	var selected: BiomeProfile = _default_biome
	
	for k in keys:
		# This function should return the TRUE biome map.
		if int(k) <= idx: 
			selected = _biome_map_cache[k]
		else:
			break
	return selected

func _get_chunk_index_at_x(x: float) -> int:
	# First check active chunks (fastest)
	for idx in _gameplay_chunks.keys():
		var d: Dictionary = _gameplay_chunks[idx] as Dictionary
		var sx: float = float(d.get("start_x", -_INF))
		var ex: float = float(d.get("end_x", _INF))
		if x >= sx and x < ex:
			return int(idx)

	# Then check metadata (accurate for special chunk widths)
	for idx in _chunk_meta.keys():
		var m: Dictionary = _chunk_meta[idx] as Dictionary
		var s: Vector2 = m.get("start", Vector2.ZERO)
		var e: Vector2 = m.get("end", s + Vector2(chunk_size, 0))
		if x >= s.x and x < e.x:
			return int(idx)

	# Fallback estimate
	return int(floor(x / float(chunk_size)))

func _min_loaded_from_loaded() -> int:
	if _gameplay_chunks.is_empty(): return 0
	var min_i := 1 << 30
	for k in _gameplay_chunks.keys():
		min_i = min(min_i, int(k))
	return min_i

func _max_loaded_from_loaded() -> int:
	if _gameplay_chunks.is_empty(): return 0
	var max_i := -(1 << 30)
	for k in _gameplay_chunks.keys():
		max_i = max(max_i, int(k))
	return max_i

func _transition_to_biome(new_biome: BiomeProfile):
	current_biome = new_biome
	_apply_biome_visuals(new_biome, 3.0)

func _apply_biome_visuals(biome: BiomeProfile, duration: float):
	# 1. Sky Gradient
	if _active_sky_tween: _active_sky_tween.kill()
	_active_sky_tween = create_tween().set_parallel(true)
	if _sky_gradient and _sky_gradient.gradient:
		_active_sky_tween.tween_method(func(c): _sky_gradient.gradient.set_color(0, c), _sky_gradient.gradient.get_color(0), biome.sky_top_color, duration)
		_active_sky_tween.tween_method(func(c): _sky_gradient.gradient.set_color(1, c), _sky_gradient.gradient.get_color(1), biome.sky_bottom_color, duration)

	# 2. Celestial Bodies (Stars/Moon)
	if _celestial_node:
		var target_modulate = Color(1, 1, 1, 1) if biome.show_celestial_bodies else Color(1, 1, 1, 0)
		_active_sky_tween.tween_property(_celestial_node, "modulate", target_modulate, duration)

	# 3. Environment (Glow)
	if _world_env and _world_env.environment:
		var env = _world_env.environment
		env.glow_enabled = biome.glow_enabled
		# Tween intensity for smooth transition
		_active_sky_tween.tween_property(env, "glow_intensity", biome.glow_intensity, duration)
		_active_sky_tween.tween_property(env, "glow_bloom", biome.glow_bloom, duration)
		env.glow_blend_mode = biome.glow_blend_mode # Set directly, enum can't tween well
		
	# 4. Atmosphere (Fog, Vinette, and Clouds)
	if _atmosphere_controller:
		_atmosphere_controller.update_biome(biome)

func _setup_sky():
	_sky_canvas = CanvasLayer.new()
	_sky_canvas.layer = -100
	add_child(_sky_canvas)

	_sky_rect = TextureRect.new()
	_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_canvas.add_child(_sky_rect)

	_sky_gradient = GradientTexture2D.new()
	_sky_gradient.gradient = Gradient.new()
	_sky_gradient.fill_from = Vector2(0, 0)
	_sky_gradient.fill_to = Vector2(0, 1)

	_sky_rect.texture = _sky_gradient

	_celestial_node = Node2D.new()
	_sky_canvas.add_child(_celestial_node)
	_spawn_celestial_bodies()
	
	var atm_script = load("res://src/core/atmosphere_controller.gd")
	if atm_script:
		_atmosphere_controller = atm_script.new()
		_sky_canvas.add_child(_atmosphere_controller)

func _update_sky():
	if _celestial_node.get_child_count() == 0:
		_spawn_celestial_bodies()

func _spawn_celestial_bodies():
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var vp = get_viewport_rect().size

	for i in range(100):
		var s = Polygon2D.new()
		var sz = rng.randf_range(1, 2.5)
		s.polygon = PackedVector2Array([Vector2(0, -sz), Vector2(sz, 0), Vector2(0, sz), Vector2(-sz, 0)])
		s.color = Color(1, 1, 1, rng.randf_range(0.3, 0.8))
		s.position = Vector2(rng.randf_range(0, vp.x), rng.randf_range(0, vp.y * 0.7))
		_celestial_node.add_child(s)

	var moon = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(32):
		pts.append(Vector2(cos((float(i) / 32.0) * TAU), sin((float(i) / 32.0) * TAU)) * 60.0)

	moon.polygon = pts
	moon.color = Color(0.9, 0.9, 0.8)
	moon.position = Vector2(vp.x * 0.8, vp.y * 0.2)
	_celestial_node.add_child(moon)
