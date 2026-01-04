@tool
class_name AssetBarnStruct
extends ProcAsset

@export var floor_y: float = 650.0

# Relative offsets
const TOP_BEAM_HEIGHT = 600.0
const MID_BEAM_HEIGHT = 320.0

func generate(ctx: ProcContext):
	# Calculate actual Y positions based on the current floor_y
	var top_beam_y = floor_y - TOP_BEAM_HEIGHT
	var mid_beam_y = floor_y - MID_BEAM_HEIGHT

	# 1. Horizontal Beams
	BarnDrawUtils.spawn_beam(ctx.parent_node, Vector2(0, top_beam_y), Vector2(ctx.chunk_size, 44), false, true)
	BarnDrawUtils.spawn_beam(ctx.parent_node, Vector2(0, mid_beam_y), Vector2(ctx.chunk_size, 48), false, true)
	
	# 2. Vertical Pillars
	# Draw them from the Top Beam down to the Floor
	var xs = [50, 550]
	var pillar_height = TOP_BEAM_HEIGHT # The pillar is exactly as tall as the top beam is high
	
	for x in xs:
		BarnDrawUtils.spawn_beam(ctx.parent_node, Vector2(x, top_beam_y), Vector2(74, pillar_height), false)
		
		# Brackets connecting pillar to mid-beam
		BarnDrawUtils.spawn_bracket(ctx.parent_node, Vector2(x+74, mid_beam_y), 1)
		BarnDrawUtils.spawn_bracket(ctx.parent_node, Vector2(x, mid_beam_y), -1)
		
	# 3. Stall Gates
	BarnDrawUtils.spawn_stall(ctx.parent_node, Vector2(128, floor_y - 180))
	BarnDrawUtils.spawn_stall(ctx.parent_node, Vector2(628, floor_y - 180))
