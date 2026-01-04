@tool
class_name AssetCaveDust
extends ProcAsset

@export var color: Color = Color(0.2, 0.7, 0.9, 0.25)
@export var size_mod: float = 1.0

func generate(ctx: ProcContext):
	# Create a controller node to handle _process for this chunk
	var controller = load("res://tools/LevelGen/assets/_controllers/dust_mote_controller.gd").new()
	ctx.parent_node.add_child(controller)
	
	for i in range(density):
		var p = Polygon2D.new()
		var s = ctx.rng.randf_range(2, 6) * size_mod
		# Octagon shape
		p.polygon = PackedVector2Array([Vector2(0,-s), Vector2(s*0.4, -s*0.4), Vector2(s,0), Vector2(s*0.4, s*0.4), Vector2(0,s), Vector2(-s*0.4, s*0.4), Vector2(-s,0), Vector2(-s*0.4, -s*0.4)])
		p.color = color * 2.2 # Glow multiplier
		
		p.position = Vector2(ctx.rng.randf_range(0, ctx.chunk_size), ctx.rng.randf_range(0, 1000))
		p.set_meta("start_y", p.position.y)
		p.set_meta("phase", ctx.rng.randf() * TAU)
		p.set_meta("speed_mod", ctx.rng.randf_range(0.8, 1.2))
		
		controller.add_child(p)
		controller.motes.append(p)
