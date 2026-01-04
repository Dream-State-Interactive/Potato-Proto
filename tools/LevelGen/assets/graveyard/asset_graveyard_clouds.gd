@tool
class_name AssetGraveyardClouds
extends ProcAsset

func generate(ctx: ProcContext):
	var count = ctx.rng.randi_range(2, 4)
	for i in range(count):
		var puff = Polygon2D.new()
		var c = Color(0.04, 0.06, 0.10).lerp(Color(0.06, 0.09, 0.13), ctx.rng.randf())
		c.a = ctx.rng.randf_range(0.12, 0.20)
		puff.color = c
		
		var x = ctx.rng.randf_range(0, ctx.chunk_size)
		var y = ctx.rng.randf_range(80, 340)
		puff.position = Vector2(x, y)
		
		var w = ctx.rng.randf_range(220, 420); var h = ctx.rng.randf_range(70, 140)
		var pts = PackedVector2Array()
		for s in range(15):
			var t = float(s)/14.0; var ang = PI + t*PI
			var wob = ctx.rng.randf_range(0.85, 1.18)
			pts.append(Vector2(cos(ang)*w*0.5, sin(ang)*h*wob))
		pts.append(Vector2(w*0.55, h*0.25)); pts.append(Vector2(-w*0.55, h*0.25))
		puff.polygon = pts
		ctx.parent_node.add_child(puff)
