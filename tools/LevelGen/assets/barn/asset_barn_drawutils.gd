@tool
class_name BarnDrawUtils
extends RefCounted

const OUTLINE_PX = 3.0
const OUTLINE_COLOR = Color(0.07, 0.04, 0.03, 1.0)

# Colors
const WOOD_WALL_BASE = Color(0.42, 0.25, 0.14)
const WOOD_MAIN = Color(0.35, 0.20, 0.10)
const WOOD_DARK = Color(0.20, 0.10, 0.05)
const WOOD_TRIM = Color(0.25, 0.15, 0.08)
const METAL_COLOR = Color(0.15, 0.15, 0.18)
const HAY_COLOR = Color(0.95, 0.75, 0.20)
const DIRT_COLOR = Color(0.15, 0.10, 0.05)

const WIN_FRAME = Color(0.20, 0.10, 0.05)
const WIN_GLASS = Color(0.80, 0.92, 1.0, 0.12)
const WIN_SILL = Color(0.25, 0.15, 0.08)
const WIN_REFL = Color(1.0, 1.0, 1.0, 0.15)

# --- SHADER CACHE ---
static var _wood_shader: Shader
static var _wallwood_shader: Shader
static var _radial_tex: Texture2D

# ====================================================================
# =========================  CORE DRAWING  ===========================
# ====================================================================

static func spawn_solid_rect(parent: Node, rect: Rect2, col: Color, outlined: bool = true) -> ColorRect:
	if outlined:
		spawn_outline_rect(parent, rect, OUTLINE_PX)
	var r = ColorRect.new()
	r.color = col
	r.position = rect.position
	r.size = rect.size
	parent.add_child(r)
	return r

static func spawn_outline_rect(parent: Node, rect: Rect2, px: float) -> ColorRect:
	var o = ColorRect.new()
	o.color = OUTLINE_COLOR
	o.position = rect.position - Vector2(px, px)
	o.size = rect.size + Vector2(px * 2.0, px * 2.0)
	parent.add_child(o)
	return o

static func spawn_outline_edges(parent: Node, rect: Rect2, px: float, left: bool, right: bool, top: bool, bottom: bool):
	if top:
		var t = ColorRect.new(); t.color = OUTLINE_COLOR
		t.position = rect.position + Vector2(-px, -px); t.size = Vector2(rect.size.x + px * 2.0, px)
		parent.add_child(t)
	if bottom:
		var b = ColorRect.new(); b.color = OUTLINE_COLOR
		b.position = rect.position + Vector2(-px, rect.size.y); b.size = Vector2(rect.size.x + px * 2.0, px)
		parent.add_child(b)
	if left:
		var l = ColorRect.new(); l.color = OUTLINE_COLOR
		l.position = rect.position + Vector2(-px, 0.0); l.size = Vector2(px, rect.size.y)
		parent.add_child(l)
	if right:
		var r = ColorRect.new(); r.color = OUTLINE_COLOR
		r.position = rect.position + Vector2(rect.size.x, 0.0); r.size = Vector2(px, rect.size.y)
		parent.add_child(r)

static func spawn_bevel_over_rect(parent: Node, rect: Rect2, tileable: bool = false):
	var hi_top = ColorRect.new(); hi_top.color = Color(1,1,1,0.08)
	hi_top.position = rect.position; hi_top.size = Vector2(rect.size.x, 8.0)
	parent.add_child(hi_top)

	var sh_bot = ColorRect.new(); sh_bot.color = Color(0,0,0,0.10)
	sh_bot.position = rect.position + Vector2(0, rect.size.y - 8.0); sh_bot.size = Vector2(rect.size.x, 8.0)
	parent.add_child(sh_bot)

	if not tileable:
		var hi_left = ColorRect.new(); hi_left.color = Color(1,1,1,0.06)
		hi_left.position = rect.position; hi_left.size = Vector2(6.0, rect.size.y)
		parent.add_child(hi_left)
		var sh_right = ColorRect.new(); sh_right.color = Color(0,0,0,0.08)
		sh_right.position = rect.position + Vector2(rect.size.x - 6.0, 0.0); sh_right.size = Vector2(6.0, rect.size.y)
		parent.add_child(sh_right)

static func spawn_beam(parent: Node, pos: Vector2, size: Vector2, add_hardware: bool = false, tileable_h: bool = false):
	var draw_pos = pos
	var draw_size = size
	if tileable_h:
		draw_pos.x -= 1.0; draw_size.x += 2.0

	var rect = Rect2(draw_pos, draw_size)
	if tileable_h:
		spawn_outline_edges(parent, rect, OUTLINE_PX, false, false, true, true)
	else:
		spawn_outline_rect(parent, rect, OUTLINE_PX)

	var r = ColorRect.new()
	r.position = draw_pos
	r.size = draw_size

	var mat = get_wood_material().duplicate()
	mat.set_shader_parameter("rect_size", draw_size)
	# Approximation for local pos, assumes parent is at chunk origin
	# For correct world pos, we'd need to pass it in, but this is usually fine for noise
	mat.set_shader_parameter("world_pos", draw_pos) 
	var dir = Vector2(0, 1) if (draw_size.y > draw_size.x) else Vector2(1, 0)
	mat.set_shader_parameter("grain_dir", dir)
	mat.set_shader_parameter("tileable_x", tileable_h)

	r.material = mat
	parent.add_child(r)
	
	if add_hardware:
		_spawn_tiny_screws_on_beam(parent, pos, size)

static func spawn_bracket(parent: Node, pos: Vector2, dir: int):
	var o = Polygon2D.new(); o.color = OUTLINE_COLOR; o.position = pos
	o.polygon = PackedVector2Array([Vector2(-OUTLINE_PX, -OUTLINE_PX), Vector2((60.0*dir)-OUTLINE_PX, 60.0+OUTLINE_PX), Vector2(-OUTLINE_PX, 60.0+OUTLINE_PX)])
	parent.add_child(o)
	var p = Polygon2D.new(); p.color = WOOD_DARK; p.position = pos
	p.polygon = PackedVector2Array([Vector2(0,0), Vector2(60.0*dir, 60.0), Vector2(0, 60.0)])
	parent.add_child(p)

# ====================================================================
# =========================  WALL & SHADERS  =========================
# ====================================================================

static func spawn_wood_wall(parent: Node, chunk_idx: int, rect: Rect2, holes: Array[Rect2] = []):
	var wall = ColorRect.new()
	wall.position = rect.position
	wall.size = rect.size
	wall.material = make_wallwood_material(chunk_idx, rect, holes)
	wall.material.set_shader_parameter("tileable", true)
	parent.add_child(wall)
	spawn_bevel_over_rect(parent, rect, true)

static func make_wallwood_material(chunk_idx: int, rect: Rect2, holes: Array[Rect2]) -> ShaderMaterial:
	if _wallwood_shader == null:
		_wallwood_shader = Shader.new()
		_wallwood_shader.code = _wallwood_shader_code()

	var m = ShaderMaterial.new()
	m.shader = _wallwood_shader
	m.set_shader_parameter("seed", float(chunk_idx) * 777.0)
	m.set_shader_parameter("base_col", WOOD_WALL_BASE)
	m.set_shader_parameter("dark_col", WOOD_DARK)
	m.set_shader_parameter("plank_w", 74.0)
	m.set_shader_parameter("seam_w", 2.2)
	m.set_shader_parameter("plank_var", 0.18)
	m.set_shader_parameter("top_light", 0.10)
	m.set_shader_parameter("rect_size", rect.size)
	# World X approximation
	m.set_shader_parameter("world_x0", float(chunk_idx * 1024) + rect.position.x) 

	var hole_count = min(holes.size(), 4)
	m.set_shader_parameter("hole_count", hole_count)
	
	var h_vecs = [Vector4(), Vector4(), Vector4(), Vector4()]
	for i in range(hole_count):
		var hr = holes[i]
		var local_pos = hr.position - rect.position
		h_vecs[i] = Vector4(local_pos.x, local_pos.y, hr.size.x, hr.size.y)
	
	m.set_shader_parameter("hole0", h_vecs[0])
	m.set_shader_parameter("hole1", h_vecs[1])
	m.set_shader_parameter("hole2", h_vecs[2])
	m.set_shader_parameter("hole3", h_vecs[3])
	return m

static func get_wood_material() -> ShaderMaterial:
	if _wood_shader == null:
		_wood_shader = Shader.new()
		_wood_shader.code = _wood_shader_code()
	var m = ShaderMaterial.new()
	m.shader = _wood_shader
	m.set_shader_parameter("base_col", WOOD_MAIN)
	m.set_shader_parameter("dark_col", WOOD_DARK)
	m.set_shader_parameter("bevel_px", 10.0)
	m.set_shader_parameter("grain_strength", 0.045)
	m.set_shader_parameter("grain_freq", 0.020)
	m.set_shader_parameter("grain_cross", 0.004)
	m.set_shader_parameter("grain_dir", Vector2(1, 0))
	return m

# --- SHADER CODE ---
static func _wallwood_shader_code() -> String:
	return """
shader_type canvas_item;
uniform float seed = 1.0;
uniform vec4 base_col : source_color;
uniform vec4 dark_col : source_color;
uniform float plank_w = 74.0;
uniform float seam_w = 2.2;
uniform float plank_var = 0.18;
uniform float top_light = 0.10;
uniform bool tileable = true;
uniform vec2 rect_size;
uniform float world_x0;
uniform int hole_count = 0;
uniform vec4 hole0; uniform vec4 hole1; uniform vec4 hole2; uniform vec4 hole3;
float hash12(vec2 p){ p=fract(p*vec2(123.34,345.45)); p+=dot(p,p+34.345); return fract(p.x*p.y); }
void fragment(){
	vec2 p = UV * rect_size;
	for(int i=0; i<4; i++){
		vec4 h = (i==0)?hole0:(i==1)?hole1:(i==2)?hole2:hole3;
		if(i<hole_count && p.x>=h.x-0.1 && p.x<=h.x+h.z+0.1 && p.y>=h.y-0.1 && p.y<=h.y+h.w+0.1) discard;
	}
	float xg = p.x + world_x0;
	float plank = floor(xg/plank_w);
	float f = fract(xg/plank_w);
	float seam = smoothstep(0.0, seam_w/plank_w, min(f, 1.0-f));
	float h = hash12(vec2(plank, seed));
	vec4 c = mix(base_col, dark_col, h*plank_var);
	float g = hash12(vec2(floor(p.y/22.0), plank+seed));
	c.rgb *= (0.94 + g*0.08);
	c.rgb *= mix(0.78, 1.0, seam);
	c.rgb += (1.0 - UV.y) * top_light;
	float d_vert = min(UV.y, 1.0 - UV.y);
	float d_horz = min(UV.x, 1.0 - UV.x);
	float dist = tileable ? d_vert : min(d_vert, d_horz);
	float ao = smoothstep(0.0, 0.08, dist);
	c.rgb *= mix(1.0, 1.0, ao);
	float n = fract(sin(dot((p+vec2(seed,seed*2.0)), vec2(12.9898,78.233)))*43758.5453);
	c.rgb += (n-0.5)*(1.0/255.0);
	COLOR = c;
}
"""

static func _wood_shader_code() -> String:
	return """
shader_type canvas_item;
uniform vec4 base_col : source_color;
uniform vec4 dark_col : source_color;
uniform vec2 rect_size;
uniform vec2 world_pos;
uniform float bevel_px = 10.0;
uniform bool tileable_x = false;
uniform vec2 grain_dir = vec2(1.0, 0.0);
uniform float grain_strength = 0.045;
uniform float grain_freq = 0.020;
uniform float grain_cross = 0.004;
float hash11(float p){ return fract(sin(p*127.1)*43758.5453123); }
float smooth_noise_1d(float x){ float i=floor(x); float f=fract(x); float a=hash11(i); float b=hash11(i+1.0); float u=f*f*(3.0-2.0*f); return mix(a,b,u); }
void fragment(){
	vec2 global_px = (UV*rect_size) + world_pos;
	float d_x = min(UV.x, 1.0-UV.x);
	float d_y = min(UV.y, 1.0-UV.y);
	float d = tileable_x ? d_y : min(d_x, d_y);
	float bevel = bevel_px / max(rect_size.x, rect_size.y);
	float edge = smoothstep(0.0, bevel, d);
	vec4 c = mix(dark_col, base_col, edge);
	vec2 dir = normalize(grain_dir);
	vec2 perp = vec2(-dir.y, dir.x);
	float along = dot(global_px, perp);
	float cross = dot(global_px, dir);
	float s1 = sin(along*(grain_freq*6.28));
	float s2 = sin(along*(grain_freq*3.1)+1.7);
	float n = (smooth_noise_1d(along*(grain_freq*0.60))-0.5)*2.0;
	float cm = 1.0 + (sin(cross*(grain_cross*6.28))*0.12);
	float g = (s1*0.55+s2*0.30+n*0.15)*cm;
	c.rgb *= (1.0+g*grain_strength);
	COLOR = c;
}
"""

# ====================================================================
# =========================  PROPS (WINDOWS)  ========================
# ====================================================================

static func spawn_window(parent: Node, pos: Vector2):
	var root = Node2D.new(); root.position = pos; parent.add_child(root)
	var window_rect = Rect2(Vector2(-8,-8), Vector2(136,136))
	spawn_outline_edges(root, window_rect, 4.0, true, true, true, true)
	
	var fw = 12.0; var f_size = 136.0
	spawn_solid_rect(root, Rect2(-8, -8, f_size, fw), WIN_FRAME, false)
	spawn_solid_rect(root, Rect2(-8, f_size-8-fw, f_size, fw), WIN_FRAME, false)
	spawn_solid_rect(root, Rect2(-8, -8, fw, f_size), WIN_FRAME, false)
	spawn_solid_rect(root, Rect2(f_size-8-fw, -8, fw, f_size), WIN_FRAME, false)
	
	var glass = ColorRect.new(); glass.color = WIN_GLASS; glass.position = Vector2(4,4); glass.size = Vector2(112,112)
	root.add_child(glass)
	
	var refl = Line2D.new(); refl.width = 2.0; refl.default_color = WIN_REFL
	refl.points = PackedVector2Array([Vector2(10,20), Vector2(40,5), Vector2(60,10)])
	glass.add_child(refl)
	
	var bar_h = ColorRect.new(); bar_h.color = WIN_FRAME; bar_h.position = Vector2(4, 56); bar_h.size = Vector2(112, 8); root.add_child(bar_h)
	var bar_v = ColorRect.new(); bar_v.color = WIN_FRAME; bar_v.position = Vector2(56, 4); bar_v.size = Vector2(8, 112); root.add_child(bar_v)
	
	var sill = ColorRect.new(); sill.color = WIN_SILL; sill.position = Vector2(-10, 120); sill.size = Vector2(140, 14); root.add_child(sill)

static func spawn_lantern(parent: Node, pos: Vector2):
	var root = Node2D.new(); root.position = pos; parent.add_child(root)
	
	# Glow
	var glow = Sprite2D.new(); glow.texture = get_radial_tex(); glow.scale = Vector2(1.2, 1.2)
	glow.position = Vector2(0, 14); glow.modulate = Color(1, 0.85, 0.4, 0.22)
	var mat = CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat; root.add_child(glow)
	
	var chain = Line2D.new(); chain.width = 3.0; chain.default_color = METAL_COLOR; chain.points = PackedVector2Array([Vector2(0,-18), Vector2(0,0)]); root.add_child(chain)
	
	var body_o = Polygon2D.new(); body_o.color = OUTLINE_COLOR
	body_o.polygon = PackedVector2Array([Vector2(-14,-2), Vector2(14,-2), Vector2(11,30), Vector2(-11,30)])
	root.add_child(body_o)
	
	var body = Polygon2D.new(); body.color = Color(1, 0.82, 0.35); body.polygon = PackedVector2Array([Vector2(-12,0), Vector2(12,0), Vector2(9,28), Vector2(-9,28)])
	root.add_child(body)
	
	var cap = ColorRect.new(); cap.color = METAL_COLOR; cap.position = Vector2(-16,-6); cap.size = Vector2(32,10); root.add_child(cap)
	
	var bulb = Polygon2D.new(); bulb.color = Color(1, 0.95, 0.65); bulb.position = Vector2(0,14); bulb.polygon = _circle_poly(3.2, 10); root.add_child(bulb)

static func get_radial_tex(size: int = 64) -> Texture2D:
	if _radial_tex: return _radial_tex
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c = Vector2(size/2.0, size/2.0); var r = size/2.0
	for y in range(size):
		for x in range(size):
			var d = c.distance_to(Vector2(x, y)) / r
			var a = clampf(1.0 - pow(d, 2.2), 0.0, 1.0)
			img.set_pixel(x, y, Color(1,1,1,a))
	_radial_tex = ImageTexture.create_from_image(img)
	return _radial_tex

static func _circle_poly(r: float, s: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(s): pts.append(Vector2(cos(TAU*i/s)*r, sin(TAU*i/s)*r))
	return pts

# ====================================================================
# ===========================  PROPS & TOOLS  ========================
# ====================================================================

static func spawn_tool_rack(parent: Node, pos: Vector2) -> void:
	var root = Node2D.new(); root.position = pos; parent.add_child(root)
	spawn_beam(root, Vector2(0, 0), Vector2(220, 16), false)
	var x0 = 20.0; var y0 = 16.0
	for i in range(5):
		var hook = ColorRect.new(); hook.color = METAL_COLOR
		hook.position = Vector2(x0 + float(i)*40.0, y0); hook.size = Vector2(6, 10)
		root.add_child(hook)
		spawn_simple_tool(root, Vector2(x0 + float(i)*40.0 + 3.0, y0 + 10.0), i)

static func spawn_simple_tool(parent: Node, pos: Vector2, kind: int) -> void:
	var handle = ColorRect.new(); handle.color = WOOD_TRIM
	handle.position = pos; handle.size = Vector2(6, 70)
	parent.add_child(handle)
	var head = Polygon2D.new(); head.color = METAL_COLOR
	head.position = pos + Vector2(3, 70)
	match kind % 5:
		0: head.polygon = PackedVector2Array([Vector2(-10,0),Vector2(10,0),Vector2(8,18),Vector2(-8,18)])
		1: head.polygon = PackedVector2Array([Vector2(-14,0),Vector2(14,0),Vector2(10,22),Vector2(-10,22)])
		2: head.polygon = PackedVector2Array([Vector2(-12,0),Vector2(12,0),Vector2(8,20),Vector2(-8,20)])
		3: head.polygon = PackedVector2Array([Vector2(-18,0),Vector2(18,0),Vector2(16,8),Vector2(-16,8)])
		4: head.polygon = PackedVector2Array([Vector2(-18,0),Vector2(18,0),Vector2(18,10),Vector2(-18,10)])
	parent.add_child(head)

static func spawn_hay_bale(parent: Node, ground_pos: Vector2, size: Vector2) -> void:
	var rect = Rect2(ground_pos - Vector2(size.x*0.5, size.y), size)
	spawn_outline_rect(parent, rect, OUTLINE_PX)
	var bale = ColorRect.new(); bale.position = rect.position; bale.size = rect.size
	bale.color = HAY_COLOR.darkened(0.08); parent.add_child(bale)
	
	var hi = ColorRect.new(); hi.color = Color(1,1,1,0.1); hi.size = Vector2(size.x, 10)
	bale.add_child(hi)
	var sh = ColorRect.new(); sh.color = Color(0,0,0,0.18); sh.position = Vector2(0, size.y-12); sh.size = Vector2(size.x, 12)
	bale.add_child(sh)
	
	for i in range(3):
		var ln = ColorRect.new(); ln.color = HAY_COLOR.darkened(0.22)
		ln.position = Vector2(0, (float(i)+0.7)*(size.y/3.0)); ln.size = Vector2(size.x, 2)
		bale.add_child(ln)

static func spawn_hay_pile(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var pile = BarnHayPile.new() 
	pile.position = pos
	pile.outline_color = OUTLINE_COLOR
	pile.hay_color = HAY_COLOR
	pile.generate(rng.randi())
	parent.add_child(pile)

static func spawn_sack(parent: Node, pos: Vector2, size: Vector2) -> void:
	var o = Polygon2D.new(); o.color = OUTLINE_COLOR; o.position = pos
	o.polygon = PackedVector2Array([Vector2(-size.x*0.55,0), Vector2(-size.x*0.62,-size.y*0.35), Vector2(-size.x*0.45,-size.y*0.82), Vector2(-size.x*0.18,-size.y*1.02), Vector2(0,-size.y*1.08), Vector2(size.x*0.18,-size.y*1.02), Vector2(size.x*0.45,-size.y*0.82), Vector2(size.x*0.62,-size.y*0.35), Vector2(size.x*0.55,0)])
	parent.add_child(o)
	var b = Polygon2D.new(); b.color = Color(0.62, 0.45, 0.25); b.position = pos
	b.polygon = PackedVector2Array([Vector2(-size.x*0.5,0), Vector2(-size.x*0.56,-size.y*0.35), Vector2(-size.x*0.4,-size.y*0.8), Vector2(-size.x*0.16,-size.y*0.98), Vector2(0,-size.y*1.04), Vector2(size.x*0.16,-size.y*0.98), Vector2(size.x*0.4,-size.y*0.8), Vector2(size.x*0.56,-size.y*0.35), Vector2(size.x*0.5,0)])
	parent.add_child(b)

static func spawn_barrel(parent: Node, pos: Vector2) -> void:
	var root = Node2D.new(); root.position = pos; parent.add_child(root)
	var h=120.0; var wt=40.0; var wm=52.0; var wb=42.0
	var o = Polygon2D.new(); o.color = OUTLINE_COLOR; o.polygon = _barrel_poly(wt+4, wm+4, wb+4, h, 18); root.add_child(o)
	var body = Polygon2D.new(); body.color = Color(0.3, 0.18, 0.1); body.polygon = _barrel_poly(wt, wm, wb, h, 18); root.add_child(body)
	var sh = Polygon2D.new(); sh.color = Color(0,0,0,0.18); sh.polygon = _barrel_half_shadow(wt, wm, wb, h, 18); root.add_child(sh)
	for y in [-86.0, -56.0, -26.0]: _spawn_barrel_hoop(root, y, wt, wm, wb, h)

static func _spawn_barrel_hoop(root: Node, y: float, wt: float, wm: float, wb: float, h: float):
	var bh = 8.0
	var w0 = _barrel_width_at(clampf((-y-bh*0.5)/h,0,1), wt, wm, wb)
	var w1 = _barrel_width_at(clampf((-y+bh*0.5)/h,0,1), wt, wm, wb)
	var b = Polygon2D.new(); b.color = METAL_COLOR
	b.polygon = PackedVector2Array([Vector2(-w0,y-bh*0.5), Vector2(w0,y-bh*0.5), Vector2(w1,y+bh*0.5), Vector2(-w1,y+bh*0.5)])
	root.add_child(b)

static func _barrel_width_at(t: float, wt: float, wm: float, wb: float) -> float:
	return lerpf(wt, wb, t) + (wm - (wt+wb)*0.5) * sin(t*PI)

static func _barrel_poly(wt: float, wm: float, wb: float, h: float, segs: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segs+1):
		var t = float(i)/segs; pts.append(Vector2(_barrel_width_at(t, wt, wm, wb), -h*(1.0-t)))
	for i in range(segs, -1, -1):
		var t = float(i)/segs; pts.append(Vector2(-_barrel_width_at(t, wt, wm, wb), -h*(1.0-t)))
	return pts

static func _barrel_half_shadow(wt: float, wm: float, wb: float, h: float, segs: int) -> PackedVector2Array:
	var pts = PackedVector2Array(); pts.append(Vector2(0, -h))
	for i in range(segs+1):
		var t = float(i)/segs; pts.append(Vector2(_barrel_width_at(t, wt, wm, wb), -h*(1.0-t)))
	pts.append(Vector2(0,0)); return pts

static func spawn_stall(parent: Node, pos: Vector2):
	var rect = Rect2(pos, Vector2(320, 180))
	spawn_outline_rect(parent, rect, OUTLINE_PX)
	var gate = ColorRect.new(); gate.position = rect.position; gate.size = rect.size; gate.color = Color.WHITE
	var mat = get_wood_material().duplicate()
	mat.set_shader_parameter("rect_size", rect.size); mat.set_shader_parameter("world_pos", pos)
	mat.set_shader_parameter("seam_strength", 0.0); mat.set_shader_parameter("grain_dir", Vector2(1,0))
	gate.material = mat; parent.add_child(gate)
	
	var inset = ColorRect.new(); inset.color = Color(0,0,0,0.2); inset.position = Vector2(10,10); inset.size = rect.size - Vector2(20,20); gate.add_child(inset)
	for i in range(7):
		var slat = ColorRect.new(); slat.color = WOOD_DARK; slat.size = Vector2(6, rect.size.y); slat.position = Vector2(float(i)*45 + 25, 0); gate.add_child(slat)
	
	for y in [30.0, 130.0]:
		var h = ColorRect.new(); h.color = METAL_COLOR; h.size = Vector2(44, 22); h.position = Vector2(-12, y); gate.add_child(h)
		_add_screw(h, Vector2(10, 6)); _add_screw(h, Vector2(34, 16))
	
	# Handle
	var bar_o = ColorRect.new(); bar_o.color = OUTLINE_COLOR; bar_o.size = Vector2(26, 8); bar_o.position = Vector2(rect.size.x - 44, rect.size.y * 0.55 - 4); gate.add_child(bar_o)
	var bar = ColorRect.new(); bar.color = METAL_COLOR; bar.size = Vector2(24, 6); bar.position = bar_o.position + Vector2(1,1); gate.add_child(bar)
	var knob_o = Polygon2D.new(); knob_o.color = OUTLINE_COLOR; knob_o.position = Vector2(rect.size.x - 20, rect.size.y * 0.55); knob_o.polygon = _circle_poly(6, 12); gate.add_child(knob_o)
	var knob = Polygon2D.new(); knob.color = Color(0.08, 0.08, 0.09); knob.position = knob_o.position; knob.polygon = _circle_poly(4.6, 12); gate.add_child(knob)

static func _spawn_tiny_screws_on_beam(parent: Node, pos: Vector2, size: Vector2):
	var is_vertical = size.y > size.x
	if is_vertical:
		_add_screw(parent, pos + Vector2(size.x - 10, size.y * 0.35))
		_add_screw(parent, pos + Vector2(size.x - 10, size.y * 0.65))
	else:
		_add_screw(parent, pos + Vector2(size.x * 0.35, size.y - 10))
		_add_screw(parent, pos + Vector2(size.x * 0.65, size.y - 10))

static func _add_screw(parent: Node, at: Vector2):
	var o = Polygon2D.new(); o.color = OUTLINE_COLOR; o.position = at; o.polygon = _circle_poly(4.2, 10); parent.add_child(o)
	var head = Polygon2D.new(); head.color = Color(0.06, 0.06, 0.07); head.position = at; head.polygon = _circle_poly(3.0, 10); parent.add_child(head)
	var hi = Polygon2D.new(); hi.color = Color(1,1,1,0.22); hi.position = at + Vector2(-1,-1); hi.polygon = _circle_poly(1.2, 8); parent.add_child(hi)

static func spawn_scallops(parent: Node, y_pos: float, width: float) -> void:
	var color = DIRT_COLOR.darkened(0.10)
	var spacing = 40.0
	var radius = 22.0
	var count = int(ceil(width / spacing))

	for i in range(count):
		var x = (float(i) + 0.5) * spacing
		if x < 0.0 or x > width: continue

		var circ = Polygon2D.new()
		circ.color = color
		circ.z_index = -10
		circ.position = Vector2(x, y_pos)
		
		var pts = PackedVector2Array()
		for s in range(13):
			var a = (float(s) / 12.0) * PI
			pts.append(Vector2(cos(a) * radius, sin(a) * radius))
		pts.append(Vector2(-radius, radius + 2))
		pts.append(Vector2(radius, radius + 2))
		
		circ.polygon = pts
		parent.add_child(circ)
