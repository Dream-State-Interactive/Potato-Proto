# src/tools/LevelGen/core/proc_asset_instance.gd
@tool
class_name ProcAssetInstance
extends Node2D

## The procedural asset definition to generate.
@export var asset: ProcAsset:
	set(v):
		asset = v
		_request_generate()

## Random seed for this specific instance.
@export var rng_seed: int = 0:
	set(v):
		rng_seed = v
		_request_generate()

## Simulates the "Chunk Size" for the asset. 
## Controls the width of the flat line used for generation.
@export var generation_width: float = 500.0:
	set(v):
		generation_width = v
		_request_generate()

## Button to randomize seed in editor
@export var randomize_seed: bool = false:
	set(v):
		if v:
			rng_seed = randi() # Triggers setter -> generation
		randomize_seed = false

func _ready():
	_request_generate()

func _request_generate():
	if is_inside_tree():
		_generate()

func _generate():
	# 1. Cleanup existing children IMMEDIATELY
	# queue_free() is too slow for tool scripts updating in real-time
	for child in get_children():
		child.free()
	
	if not asset:
		return

	# 2. Create Local Context
	var ctx = ProcContext.new()
	ctx.parent_node = self
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = rng_seed
	ctx.chunk_size = int(generation_width)
	ctx.global_x = 0.0 
	
	# 3. Create Dummy Flat Terrain
	# This ensures assets (like fences) have a "floor" to snap to at Y=0
	var curve = PackedVector2Array()
	var step = 20
	var steps = int(generation_width / step)
	
	for i in range(steps + 1):
		curve.append(Vector2(i * step, 0))
	
	ctx.terrain_curve = curve
	ctx.terrain_y_end = 0.0
	
	# 4. Generate
	asset.generate(ctx)
