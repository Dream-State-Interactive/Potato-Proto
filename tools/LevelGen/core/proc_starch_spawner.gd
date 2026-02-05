@tool
class_name ProcStarchSpawner
extends ProcAsset

enum PatternType {
	FLAT,       # Follows terrain at fixed height
	WAVE,       # Sine wave pattern relative to terrain
	NOISE_SCATTER # Random height variations
}

@export_group("Starch Configuration")
@export var starch_scene: PackedScene = preload("res://src/collectibles/starch_point.tscn")
@export var pattern_type: PatternType = PatternType.FLAT

## How many terrain points to skip between starch points.
## Lower = More dense. Higher = More spread out.
## (Assuming terrain points are 20px apart, a step of 5 is a 100px gap).
@export_range(1, 50) var step_interval: int = 5

## Base height offset from the ground (Negative is UP).
@export var height_offset: float = -100.0

@export_subgroup("Wave Settings")
@export var wave_frequency: float = 0.01
@export var wave_amplitude: float = 50.0

@export_subgroup("Noise Settings")
@export var noise_jitter: float = 30.0

func generate(ctx: ProcContext) -> void:
	if not starch_scene:
		push_warning("ProcStarchSpawner: No starch_scene assigned.")
		return
	
	if ctx.terrain_curve.is_empty():
		return

	var points = ctx.terrain_curve
	var point_count = points.size()
	
	# Collect positions in array instead of spawning immediately
	var spawn_locations: Array[Vector2] = []

	# Determine where to start in this chunk to ensure continuity across chunks.
	# Use global_x to align the step interval so points don't cluster at chunk seams.
	var start_index = 0

	# Modulo to offset the start index based on global position
	var global_offset = int(ctx.global_x / 20.0) # Assuming 20px per point
	var remainder = global_offset % step_interval
	if remainder != 0:
		start_index = step_interval - remainder

	# Iterate through terrain points
	for i in range(start_index, point_count, step_interval):
		var ground_pos = points[i]
		
		# 1. Calculate Base Position
		var spawn_pos = ground_pos + Vector2(0, height_offset)
		
		# 2. Apply Pattern Modifiers
		match pattern_type:
			PatternType.WAVE:
				# Use global X for the sine wave so it flows seamlessly between chunks
				var wave_y = sin((ctx.global_x + ground_pos.x) * wave_frequency) * wave_amplitude
				spawn_pos.y += wave_y
				
			PatternType.NOISE_SCATTER:
				var jitter = ctx.rng.randf_range(-noise_jitter, noise_jitter)
				spawn_pos.y += jitter

		# 3. Queue for Spawning (Don't spawn yet!)
		spawn_locations.append(spawn_pos)

	# 4. Final Execution
	if Engine.is_editor_hint():
		for pos in spawn_locations:
			var instance = starch_scene.instantiate()
			instance.position = pos
			ctx.parent_node.add_child(instance)
	else:
		# Use BatchSpawner to spread load over multiple frames.
		var batcher = BatchSpawner.new()
		batcher.scene_to_spawn = starch_scene
		batcher.locations = spawn_locations
		batcher.items_per_frame = 4 # Spawns 4 items per frame until empty
		ctx.parent_node.add_child(batcher)
