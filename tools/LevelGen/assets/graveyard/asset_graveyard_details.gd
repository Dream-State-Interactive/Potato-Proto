@tool
class_name AssetGraveyardDetails
extends ProcAsset

enum Type { CROSSES_TREES, FENCE, MAUSOLEUM, GRAVESTONES, CANDLES }
@export var type: Type = Type.CROSSES_TREES
@export var depth01: float = 0.5
@export var fade_color: Color = Color(0.12, 0.24, 0.28)
@export var fade_strength: float = 0.38

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 10: return
	
	match type:
		Type.CROSSES_TREES:
			for i in range(density):
				var idx = ctx.rng.randi_range(2, ctx.terrain_curve.size()-3)
				var p = ctx.terrain_curve[idx]
				if ctx.rng.randf() < 0.65:
					GraveyardDrawUtils.spawn_cross(ctx.parent_node, p + Vector2(0, 2), ctx.rng, 0.75, -8, depth01, fade_color, fade_strength)
				else:
					GraveyardDrawUtils.spawn_bare_tree(ctx.parent_node, p + Vector2(0, 4), ctx.rng, 0.55, -8, depth01, fade_color, fade_strength)
					
		Type.FENCE:
			for i in range(density):
				var idx = ctx.rng.randi_range(5, ctx.terrain_curve.size()-20)
				var p = ctx.terrain_curve[idx]
				GraveyardDrawUtils.spawn_iron_fence(ctx.parent_node, p + Vector2(0, 10), ctx.rng, -2, depth01, fade_color, fade_strength)
				
		Type.MAUSOLEUM:
			for i in range(density):
				var idx = ctx.rng.randi_range(10, ctx.terrain_curve.size()-10)
				var p = ctx.terrain_curve[idx]
				if not ctx.is_range_free(p.x - 140, 280, 50): continue
				ctx.reserve_range(p.x - 140, 280)
				GraveyardDrawUtils.spawn_mausoleum(ctx.parent_node, p + Vector2(0, 6), ctx.rng, -3, false, depth01, fade_color, fade_strength)
		
		Type.GRAVESTONES:
			for i in range(density):
				var idx = ctx.rng.randi_range(4, ctx.terrain_curve.size() - 5)
				var p = ctx.terrain_curve[idx] + Vector2(ctx.rng.randf_range(-30, 30), ctx.rng.randf_range(6, 16))
				
				# Occasional Mausoleum in FG (from original script logic)
				if ctx.rng.randf() < 0.18:
					if ctx.is_range_free(p.x - 140, 280, 20):
						ctx.reserve_range(p.x - 140, 280)
						GraveyardDrawUtils.spawn_mausoleum(ctx.parent_node, p + Vector2(0, 6), ctx.rng, 3, true, 0.10, fade_color, fade_strength)
				else:
					GraveyardDrawUtils.spawn_gravestone(ctx.parent_node, p, ctx.rng)
					
		Type.CANDLES:
			for i in range(density):
				var idx = ctx.rng.randi_range(6, ctx.terrain_curve.size() - 7)
				var p = ctx.terrain_curve[idx] + Vector2(ctx.rng.randf_range(-36, 36), ctx.rng.randf_range(8, 18))
				GraveyardDrawUtils.spawn_candle(ctx.parent_node, p, ctx.rng)
