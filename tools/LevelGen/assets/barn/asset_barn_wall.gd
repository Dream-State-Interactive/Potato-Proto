@tool
class_name AssetBarnWall
extends ProcAsset

@export var floor_y: float = 650.0

## How high the wall goes starting from the floor
@export var wall_height_offset: float = 550.0 # (Previously 650 - 100)
## How high the roof peak is starting from the floor
@export var roof_peak_offset: float = 850.0 # (Previously 650 - -200)

@export var wall_height: float = 520.0 # The visual height of the wood texture

func generate(ctx: ProcContext):
	# Calculate absolute coordinates based on floor anchor
	var wall_top_y = floor_y - wall_height_offset
	var roof_top_y = floor_y - roof_peak_offset
	var window_y = floor_y - 470.0 # (Previously 180. 650 - 180 = 470)

	# 1. Roof Slab
	var roof_h = wall_top_y - roof_top_y
	BarnDrawUtils.spawn_solid_rect(ctx.parent_node, Rect2(0, roof_top_y, ctx.chunk_size, roof_h), Color(0.10, 0.05, 0.02), false)
	
	# 2. Bottom Fill (Prevents gaps below the wall)
	var wall_bot = wall_top_y + wall_height
	if wall_bot < floor_y:
		BarnDrawUtils.spawn_solid_rect(ctx.parent_node, Rect2(0, wall_bot, ctx.chunk_size, floor_y - wall_bot), BarnDrawUtils.WOOD_WALL_BASE.darkened(0.1), false)
	
	# 3. Main Wood Wall
	var wall_rect = Rect2(0, wall_top_y, ctx.chunk_size, wall_height)
	
	# Define Window Holes
	var win_positions = [Vector2(200, window_y), Vector2(700, window_y)]
	var holes: Array[Rect2] = []
	for wp in win_positions:
		holes.append(Rect2(wp, Vector2(120, 120)))
		
	BarnDrawUtils.spawn_wood_wall(ctx.parent_node, ctx.chunk_index, wall_rect, holes)
	
	# 4. Windows & Lanterns
	for wp in win_positions:
		BarnDrawUtils.spawn_window(ctx.parent_node, wp)
		BarnDrawUtils.spawn_lantern(ctx.parent_node, wp + Vector2(-110, 50))
