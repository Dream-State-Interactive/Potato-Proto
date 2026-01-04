@tool
class_name AssetDesertRocks
extends ProcAsset

@export var color: Color = Color(0.3, 0.2, 0.15)

func generate(ctx: ProcContext):
	if ctx.terrain_curve.size() < 5: return
	
	for i in range(density):
		var idx = ctx.rng.randi_range(2, ctx.terrain_curve.size()-3)
		var params = _get_spawn_params(ctx, idx)
		
		var rock = Polygon2D.new()
		rock.color = color
		rock.z_index = 5
		rock.position = params.position
		rock.rotation = params.rotation
		rock.scale = params.scale
		
		var w = ctx.rng.randf_range(10, 25)
		var h = ctx.rng.randf_range(8, 15)
		
		rock.polygon = PackedVector2Array([
			Vector2(-w/2, 0), Vector2(-w/4, -h * 0.6),
			Vector2(0, -h), Vector2(w/3, -h * 0.8), Vector2(w/2, 0)
		])
		ctx.parent_node.add_child(rock)
