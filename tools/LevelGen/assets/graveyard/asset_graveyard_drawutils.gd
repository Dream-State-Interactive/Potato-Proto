@tool
class_name GraveyardDrawUtils
extends RefCounted

const STONE_DARK = Color(0.10, 0.12, 0.14)
const STONE_MID = Color(0.15, 0.17, 0.19)
const IRON_COLOR = Color(0.04, 0.05, 0.06)
const TREE_SILHOUETTE = Color(0.04, 0.05, 0.06)
const CANDLE_FLAME = Color(1.00, 0.78, 0.35)
const CANDLE_GLOW = Color(1.00, 0.72, 0.28)

static var _white_tex: Texture2D
static var _glow_shader: Shader

# --- HELPERS ---
static func add_poly(parent: Node, pts: PackedVector2Array, col: Color, z: int) -> Polygon2D:
	var p = Polygon2D.new(); p.polygon = pts; p.color = col; p.z_index = z; parent.add_child(p); return p

static func add_line(parent: Node, pts: PackedVector2Array, col: Color, width: float, z: int) -> Line2D:
	var l = Line2D.new(); l.points = pts; l.default_color = col; l.width = width; l.z_index = z; parent.add_child(l); return l

static func rect_poly(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y0)])

static func with_alpha(c: Color, a: float) -> Color:
	var cc = c; cc.a = a; return cc

static func distance_fade(c: Color, depth01: float, fade_col: Color, strength: float) -> Color:
	var t = clamp(depth01 * strength, 0.0, 1.0)
	var fog = fade_col; fog.a = c.a
	var out = c.lerp(fog, t); out.a = c.a; return out

# --- MAUSOLEUM ---
static func spawn_mausoleum(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator, z: int, foreground: bool, depth01: float, fade_col: Color, fade_str: float):
	var node = Node2D.new(); node.position = pos; node.z_index = z; parent.add_child(node)
	
	var scale_mul = 1.25 if foreground else 1.0
	var w = rng.randf_range(190.0, 280.0) * scale_mul
	var h = rng.randf_range(135.0, 200.0) * scale_mul
	
	var sd = STONE_DARK; var sm = STONE_MID; var iron = IRON_COLOR
	if not foreground:
		sd = distance_fade(sd, depth01, fade_col, fade_str)
		sm = distance_fade(sm, depth01, fade_col, fade_str)
		iron = distance_fade(iron, depth01, fade_col, fade_str)
		
	var hi = sm.lightened(0.07); var sh = sd.darkened(0.10)
	
	# Platform
	var pl_h = h * 0.14; var pl_w = w * 1.08
	add_poly(node, rect_poly(-pl_w*0.5, 0, pl_w*0.5, -pl_h), sd.darkened(0.04), 0)
	add_line(node, PackedVector2Array([Vector2(-pl_w*0.5, -pl_h), Vector2(pl_w*0.5, -pl_h)]), with_alpha(hi, 0.55), 2.0, 1)
	
	# Body
	var body_h = h * 0.70; var body_top_in = w * 0.06; var body_y0 = -pl_h; var body_y1 = -pl_h - body_h
	var body_pts = PackedVector2Array([Vector2(-w*0.5, body_y0), Vector2(-w*0.5+body_top_in, body_y1), Vector2(w*0.5-body_top_in, body_y1), Vector2(w*0.5, body_y0)])
	add_poly(node, body_pts, sd, 2)
	
	# Pillars
	var pil_w = w * 0.10; var pil_in = w * 0.04; var pil_y1 = body_y1 + h * 0.10
	for sgn in [-1.0, 1.0]:
		var px = sgn * (w*0.5 - pil_w*0.55)
		add_poly(node, rect_poly(px - pil_w*0.5, body_y0, px + pil_w*0.5, pil_y1), sh, 3)
		add_line(node, PackedVector2Array([Vector2(px+sgn*pil_in, body_y0), Vector2(px+sgn*pil_in, pil_y1)]), with_alpha(hi, 0.35), 1.5, 4)
		
	# Roof
	var corn_h = h * 0.08; var corn_w = w * 1.02; var corn_y1 = body_y1 - corn_h
	add_poly(node, rect_poly(-corn_w*0.5, body_y1, corn_w*0.5, corn_y1), sd.darkened(0.06), 5)
	
	var ped_h = h * rng.randf_range(0.18, 0.26); var ped_w = w * 0.90
	add_poly(node, PackedVector2Array([Vector2(-ped_w*0.5, corn_y1), Vector2(0, corn_y1-ped_h), Vector2(ped_w*0.5, corn_y1)]), sd.darkened(0.10), 7)
	
	# Door
	var door_w = w * rng.randf_range(0.24, 0.32); var door_h = h * rng.randf_range(0.46, 0.58)
	var frame = Polygon2D.new(); frame.color = sm.darkened(0.04); frame.z_index = 9; frame.position = Vector2(0, body_y0)
	frame.polygon = make_arch_polygon(door_w*1.14, door_h*1.10, 14); node.add_child(frame)
	
	var recess = Polygon2D.new(); recess.color = sd.darkened(0.22); recess.z_index = 10; recess.position = Vector2(0, body_y0 - h*0.01)
	recess.polygon = make_arch_polygon(door_w*0.92, door_h*0.98, 14); node.add_child(recess)

static func make_arch_polygon(w: float, h: float, segments: int) -> PackedVector2Array:
	var pts = PackedVector2Array(); var base_h = h * 0.62
	pts.append(Vector2(-w*0.5, 0)); pts.append(Vector2(-w*0.5, -base_h))
	for i in range(segments+1):
		var tt = float(i)/segments; var ang = PI - tt*PI
		pts.append(Vector2(cos(ang)*w*0.5, -base_h + sin(ang)*h*0.38))
	pts.append(Vector2(w*0.5, -base_h)); pts.append(Vector2(w*0.5, 0))
	return pts

# --- IRON FENCE ---
static func spawn_iron_fence(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator, z: int, depth01: float, fade_col: Color, fade_str: float):
	var node = Node2D.new(); node.position = pos; node.z_index = z; parent.add_child(node)
	var iron = distance_fade(IRON_COLOR, depth01, fade_col, fade_str).darkened(rng.randf_range(0, 0.1))
	var seg_len = rng.randf_range(260, 420); var start_x = -seg_len * 0.5
	var post_spacing = rng.randf_range(42, 58); var post_count = int(floor(seg_len/post_spacing)) + 1
	var top_y = -rng.randf_range(56, 70); var mid_y = top_y + rng.randf_range(18, 26)
	
	var rail_top = PackedVector2Array(); var rail_mid = PackedVector2Array()
	for i in range(post_count):
		var x = start_x + float(i)*post_spacing
		var wob = sin(float(i)/post_count * PI) * rng.randf_range(-2, 2)
		rail_top.append(Vector2(x, top_y + wob)); rail_mid.append(Vector2(x, mid_y + wob*0.7))
		
	add_line(node, rail_mid, with_alpha(iron, 0.7), 3.0, 1)
	add_line(node, rail_top, with_alpha(iron, 0.78), 3.0, 2)
	
	for i in range(post_count):
		var x = start_x + float(i)*post_spacing
		var ph = rng.randf_range(64, 92)
		add_poly(node, rect_poly(x-4, 0, x+4, -ph), iron, 4)
		if ph > 40 and rng.randf() < 0.92:
			add_poly(node, PackedVector2Array([Vector2(x-5, -ph), Vector2(x, -ph-12), Vector2(x+5, -ph)]), iron.darkened(0.04), 6)

# --- CROSSES / TREES ---
static func spawn_cross(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator, scale: float, z: int, depth01: float, fade_col: Color, fade_str: float):
	var n = Node2D.new(); n.position = pos; n.z_index = z; parent.add_child(n)
	var col = distance_fade(IRON_COLOR, depth01, fade_col, fade_str)
	var h = rng.randf_range(70, 110) * scale; var w = rng.randf_range(14, 22) * scale
	var arm_w = rng.randf_range(48, 72) * scale; var arm_h = w * rng.randf_range(0.7, 1.1)
	var arm_y = -h * rng.randf_range(0.45, 0.60)
	
	add_poly(n, rect_poly(-w*0.5, 0, w*0.5, -h), col, 0) # Stem
	add_poly(n, rect_poly(-arm_w*0.5, arm_y-arm_h*0.5, arm_w*0.5, arm_y+arm_h*0.5), col.darkened(0.05), 1) # Arm

static func spawn_bare_tree(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator, scale: float, z: int, depth01: float, fade_col: Color, fade_str: float):
	var n = Node2D.new(); n.position = pos; n.z_index = z; parent.add_child(n)
	var col = distance_fade(TREE_SILHOUETTE, depth01, fade_col, fade_str)
	var h = rng.randf_range(84, 140) * scale; var w = rng.randf_range(12, 22) * scale
	
	add_poly(n, PackedVector2Array([Vector2(-w*0.5, 0), Vector2(-w*0.3, -h), Vector2(w*0.3, -h), Vector2(w*0.5, 0)]), col, 1)
	
	var branches = rng.randi_range(4, 7)
	for i in range(branches):
		var t = float(i)/branches; var by = lerpf(-h*0.3, -h*0.98, t)
		var ang = -PI*0.5 + (1.0 if rng.randf()<0.5 else -1.0) * rng.randf_range(0.35, 1.05)
		var len = rng.randf_range(44, 96) * scale * lerpf(1.1, 0.7, t)
		var end = Vector2(0, by) + Vector2(cos(ang), sin(ang)) * len
		add_line(n, PackedVector2Array([Vector2(0, by), end]), with_alpha(col, 0.95), max(1.5, 2.5*scale), 3)


# =======================================================================
# ============================ GRAVESTONES ==============================
# =======================================================================

static func spawn_gravestone(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator):
	var n = Node2D.new(); n.position = pos; n.z_index = 3; parent.add_child(n)

	var w = rng.randf_range(34.0, 66.0)
	var h = rng.randf_range(48.0, 90.0)

	var shape = _make_tombstone_polygon(w, h, rng)

	# Shadow
	var shadow = Polygon2D.new(); shadow.z_index = 2
	shadow.color = Color(0, 0, 0, 0.16)
	shadow.polygon = _shadow_from_polygon(shape, Vector2(14.0, 6.0), 1.05, 0.18)
	n.add_child(shadow)

	# Face
	var face = Polygon2D.new(); face.z_index = 3
	face.color = STONE_DARK.lerp(STONE_MID, rng.randf_range(0.15, 0.35))
	face.polygon = shape
	n.add_child(face)

	# Crack
	if rng.randf() < 0.45:
		var crack = Line2D.new()
		crack.default_color = STONE_DARK.darkened(0.2); crack.width = 2.0
		var p1 = Vector2(rng.randf_range(-w * 0.25, w * 0.25), -h * rng.randf_range(0.15, 0.35))
		var p2 = p1 + Vector2(rng.randf_range(-12, 12), rng.randf_range(-18, -42))
		crack.points = PackedVector2Array([p1, (p1 + p2) * 0.5 + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), p2])
		n.add_child(crack)

static func _make_tombstone_polygon(w: float, h: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var top_round = h * rng.randf_range(0.20, 0.32)
	var inset = w * rng.randf_range(0.02, 0.08)
	var pts = PackedVector2Array()
	pts.append(Vector2(-w * 0.5, 0))
	pts.append(Vector2(-w * 0.5 + inset, -h + top_round))
	var seg = 10
	for i in range(seg + 1):
		var tt = float(i) / float(seg)
		var ang = PI - (tt * PI)
		var rx = (w * 0.5) - inset
		var ry = top_round
		pts.append(Vector2(cos(ang) * rx, -h + top_round + sin(ang) * ry))
	pts.append(Vector2(w * 0.5 - inset, -h + top_round))
	pts.append(Vector2(w * 0.5, 0))
	return pts

static func _shadow_from_polygon(src: PackedVector2Array, offset: Vector2, x_scale: float, y_scale: float) -> PackedVector2Array:
	var out = PackedVector2Array()
	for p in src: out.append(Vector2(p.x * x_scale, p.y * y_scale) + offset)
	return out

# =======================================================================
# ============================== CANDLES ================================
# =======================================================================

static func spawn_candle(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator):
	var node = Node2D.new(); node.position = pos; node.z_index = 4; parent.add_child(node)

	var h = rng.randf_range(14.0, 24.0)
	var w = rng.randf_range(8.0, 12.0)

	var body = Polygon2D.new(); body.color = STONE_MID.lightened(0.06)
	body.polygon = rect_poly(-w*0.5, 0, w*0.5, -h)
	node.add_child(body)

	var flame = Polygon2D.new()
	var fc = CANDLE_FLAME; fc.a = rng.randf_range(0.70, 0.92)
	flame.color = fc; flame.position = Vector2(0, -h)
	flame.polygon = PackedVector2Array([Vector2(0, -8), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
	node.add_child(flame)

	# Glows (High Z-Index to glow over everything)
	var glow_pos = Vector2(0, -h - 8)
	add_radial_glow(node, glow_pos, rng.randf_range(44.0, 72.0), with_alpha(CANDLE_GLOW, 0.07), 60, 1.10)
	add_radial_glow(node, glow_pos, rng.randf_range(18.0, 34.0), with_alpha(CANDLE_GLOW, 0.12), 60, 1.70)

# =======================================================================
# ============================  GLOW HELPERS  ===========================
# =======================================================================

static func add_radial_glow(
	parent: Node,
	pos: Vector2,
	radius: float,
	c: Color,
	z_idx: int = -1000,
	power: float = 1.35,
	inner: float = 0.0,
	scale_xy: Vector2 = Vector2.ONE
) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = _get_white_tex()
	s.centered = true
	s.position = pos
	s.z_index = z_idx

	var d = radius * 2.0
	s.scale = Vector2(d * scale_xy.x, d * scale_xy.y)

	var sm = ShaderMaterial.new()
	sm.shader = _get_glow_shader()
	sm.set_shader_parameter("glow_color", c)
	sm.set_shader_parameter("power", power)
	sm.set_shader_parameter("inner", inner)
	s.material = sm

	parent.add_child(s)
	return s

static func _get_white_tex() -> Texture2D:
	if _white_tex != null:
		return _white_tex
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

static func _get_glow_shader() -> Shader:
	if _glow_shader != null:
		return _glow_shader

	_glow_shader = Shader.new()
	_glow_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 0.1);
uniform float power = 1.35;
uniform float inner = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float a = smoothstep(1.0, inner, d);
	a = pow(a, power);
	COLOR = vec4(glow_color.rgb, glow_color.a * a);
}
"""
	return _glow_shader
