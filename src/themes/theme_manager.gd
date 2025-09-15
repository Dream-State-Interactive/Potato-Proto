# src/themes/theme_manager.gd
extends Node

signal theme_applied(theme: ThemeData)
signal time_of_day_changed(t: float) # 0.0..1.0

# ─────────────────────────────────────────────────────────────────────────────
# Constants (NodePaths & Z order)
# ─────────────────────────────────────────────────────────────────────────────
const NP_CL           : NodePath = ^"CanvasLayer"
const NP_CTRL         : NodePath = ^"CanvasLayer/Control"
const NP_SKY          : NodePath = ^"CanvasLayer/Control/Sky"
const NP_POST         : NodePath = ^"CanvasLayer/Control/PostGrade"
const NP_FOG          : NodePath = ^"CanvasLayer/Control/FogOverlay"
const NP_STARS_A      : NodePath = ^"CanvasLayer/Control/Starfield"
const NP_STARS_B      : NodePath = ^"CanvasLayer/Control/starfield" # allow lowercase
const NP_PB           : NodePath = ^"CanvasLayer/Control/ParallaxBackground"
const NP_CANVAS_MOD   : NodePath = ^"CanvasLayer/Control/CanvasModulate"
const NP_CORE         : NodePath = ^"CanvasLayer/Control/Celestials"
const NP_GLOW         : NodePath = ^"CanvasLayer/Control/CelestialsGlow"

const Z_SKY    := 0
const Z_STARS  := 10
const Z_CORE   := 12
const Z_GLOW   := 13
const Z_FOG    := 20
const Z_POST   := 30

# ─────────────────────────────────────────────────────────────────────────────
# Public state
# ─────────────────────────────────────────────────────────────────────────────
var current_theme: ThemeData
var time_of_day := 0.25 # 0=dawn, 0.5=noon, 0.75=dusk, 1=midnight

# ─────────────────────────────────────────────────────────────────────────────
# Scene refs / stack
# ─────────────────────────────────────────────────────────────────────────────
@export var visual_stack_scene: PackedScene = preload("res://src/themes/visual_stack.tscn")
var _stack: Node = null # instance of visual_stack.tscn

var _sun2d: DirectionalLight2D = null
var _moon2d: DirectionalLight2D = null

# ─────────────────────────────────────────────────────────────────────────────
# Transitions / Fades
# ─────────────────────────────────────────────────────────────────────────────
var _sky_overlay: ColorRect = null       # temp sky when fading only the sky
var _stack_old_sky: CanvasItem = null    # old sky kept alive during stack xfade
var _stack_fading := false               # true while full-stack crossfade is running
var _theme_just_applied := false         # only tween light colors once

# Celestial size tween
var _sun_size_px: float  = 90.0
var _moon_size_px: float = 70.0
var _sizes_animating := false
var _size_tw: Tween = null
@export_range(0.0, 3.0, 0.05) var size_tween_seconds := 1.2

# ─────────────────────────────────────────────────────────────────────────────
# Tuning
# ─────────────────────────────────────────────────────────────────────────────
# Lights
@export var use_light_overrides := false
@export var sun_light_tint: Color  = Color(1.0, 0.95, 0.85)
@export var moon_light_tint: Color = Color(0.75, 0.85, 1.0)
@export_range(0.0, 2.0, 0.01) var sun_energy_mul  := 1.0
@export_range(0.0, 2.0, 0.01) var moon_energy_mul := 1.0
@export var tween_lights_on_theme_change := true
@export_range(0.0, 2.0, 0.01) var light_tween_seconds := 0.4

# Stars
@export_range(0.2, 2.0, 0.05) var star_intensity := 1.0
@export_range(0.0, 1.0, 0.01) var stars_fade_in_at := 0.66
@export_range(0.0, 1.0, 0.01) var stars_full_at    := 0.98

# Sky parallax (sky only; celestials are screen-pinned)
@export_range(0.0, 0.2, 0.005) var sky_parallax := 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_ensure_stack()

	# Cache optional scene lights
	var root := get_tree().current_scene
	if root:
		_sun2d  = root.get_node_or_null("Sun2D")  as DirectionalLight2D
		_moon2d = root.get_node_or_null("Moon2D") as DirectionalLight2D

	# Prevent startup flash: configure, then reveal Control
	var ctrl := _n(NP_CTRL) as CanvasItem
	if ctrl: ctrl.visible = false
	_apply_frame()
	if ctrl: ctrl.visible = true

func _process(_dt: float) -> void:
	if _sizes_animating or _stack_fading or (_sky_overlay and is_instance_valid(_sky_overlay)):
		_apply_frame()

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func apply_theme(theme: ThemeData) -> void:
	if theme == null: return
	current_theme = theme
	_theme_just_applied = true
	_tween_celestial_sizes(theme.sun_size, theme.moon_size, size_tween_seconds)
	_apply_frame()
	emit_signal("theme_applied", theme)

func set_time_of_day(t: float) -> void:
	time_of_day = clampf(t, 0.0, 1.0)
	_apply_frame()
	emit_signal("time_of_day_changed", time_of_day)

func transition_to_theme(new_theme: ThemeData, seconds: float = 0.6) -> void:
	if new_theme == null: return
	_ensure_stack()

	# Stack not ready? just apply instantly
	if not _stack.is_inside_tree():
		current_theme = new_theme
		_theme_just_applied = true
		_apply_frame()
		emit_signal("theme_applied", new_theme)
		return

	# Keep old sky alive during crossfade
	var old := _stack
	var parent := old.get_parent()
	if parent == null:
		current_theme = new_theme
		_theme_just_applied = true
		_apply_frame()
		emit_signal("theme_applied", new_theme)
		return

	_stack_old_sky = _nf(old, NP_SKY) as CanvasItem
	_stack_fading = true

	# Build fresh stack
	var new_stack := visual_stack_scene.instantiate()
	parent.add_child(new_stack)
	_configure_canvas_layer(new_stack)

	# Switch and configure
	_stack = new_stack
	current_theme = new_theme
	_theme_just_applied = true

	# Tween celestial sizes between themes
	_tween_celestial_sizes(new_theme.sun_size, new_theme.moon_size, seconds)

	# Hide old celestials so only the new animated ones are visible
	var old_core := _nf(old, NP_CORE) as CanvasItem
	var old_glow := _nf(old, NP_GLOW) as CanvasItem
	if old_core: old_core.visible = false
	if old_glow: old_glow.visible = false

	_apply_frame()

	# Crossfade the control subtree
	var old_ctrl := _nf(old, NP_CTRL) as CanvasItem
	var new_ctrl := _n(NP_CTRL) as CanvasItem
	if new_ctrl: new_ctrl.modulate.a = 0.0

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if new_ctrl: tw.tween_property(new_ctrl, "modulate:a", 1.0, seconds)
	if old_ctrl: tw.parallel().tween_property(old_ctrl, "modulate:a", 0.0, seconds)
	tw.finished.connect(func():
		if is_instance_valid(old): old.queue_free()
		_stack_old_sky = null
		_stack_fading = false
		emit_signal("theme_applied", new_theme))

func fade_sky_to_theme(new_theme: ThemeData, seconds: float = 0.6) -> void:
	if new_theme == null: return
	_ensure_stack()
	var ctrl := _n(NP_CTRL) as Control
	var old_sky := _n(NP_SKY) as CanvasItem
	if ctrl == null or old_sky == null:
		apply_theme(new_theme); return

	# Temporary overlay using same shader as current sky
	var overlay := ColorRect.new()
	overlay.name = "SkyFadeOverlay"
	overlay.color = Color.BLACK
	overlay.material = (old_sky.material as ShaderMaterial).duplicate()
	ctrl.add_child(overlay)
	_fullscreen_overlay(overlay)
	overlay.modulate.a = 0.0
	overlay.z_index = old_sky.z_index + 1

	# Configure overlay for the NEW theme
	_configure_sky_material(overlay.material as ShaderMaterial, new_theme)

	# Tween ambient & fog alongside
	var canvas_mod := _n(NP_CANVAS_MOD) as CanvasModulate
	var fog := _n(NP_FOG) as ColorRect
	var night := _night_mix(time_of_day)
	var amb_end := _lerp_color(new_theme.ambient_day, new_theme.ambient_night, pow(night, 1.25))

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "modulate:a", 1.0, seconds)
	if canvas_mod:
		tw.parallel().tween_property(canvas_mod, "color", Color(amb_end.r, amb_end.g, amb_end.b, 1.0), seconds)
	if fog and fog.material is ShaderMaterial:
		tw.parallel().tween_property(fog.material, "shader_parameter/fog_color", new_theme.fog_color, seconds)
		tw.parallel().tween_property(fog.material, "shader_parameter/band_height", new_theme.fog_band_height, seconds)

	tw.finished.connect(func():
		apply_theme(new_theme)
		if is_instance_valid(overlay): overlay.queue_free())
	_sky_overlay = overlay
	overlay.tree_exited.connect(func(): _sky_overlay = null)

# ─────────────────────────────────────────────────────────────────────────────
# Frame update (single orchestration point)
# ─────────────────────────────────────────────────────────────────────────────
func _apply_frame() -> void:
	if current_theme == null or _stack == null: return
	_ensure_stack()

	var ctx := _viewport_ctx()

	# 1) Sky
	var sky := _n(NP_SKY) as CanvasItem
	if sky and sky.material is ShaderMaterial:
		_configure_sky_material(sky.material as ShaderMaterial, current_theme, ctx)

	# Keep overlay/old-sky uniforms current during fades
	_tick_fading_sky(ctx)

	# 2) Celestials (core + glow)
	_configure_celestials_for(NP_CORE, false, ctx)
	_configure_celestials_for(NP_GLOW, true,  ctx)

	# 3) Lights / Parallax / Overlays / Stars
	_update_lights()
	_update_parallax()
	_update_overlays()
	_update_stars()

	_theme_just_applied = false

# ─────────────────────────────────────────────────────────────────────────────
# Subsystems
# ─────────────────────────────────────────────────────────────────────────────
func _configure_sky_material(m: ShaderMaterial, theme: ThemeData, ctx: Dictionary = {}) -> void:
	if ctx.is_empty():
		ctx = _viewport_ctx()
	var vp:   Vector2 = ctx.get("vp",   Vector2(get_viewport().size.x, get_viewport().size.y))
	var zoom: Vector2 = ctx.get("zoom", Vector2.ONE)

	m.set_shader_parameter("viewport_size", vp)
	m.set_shader_parameter("cam_zoom", zoom)
	m.set_shader_parameter("sky_parallax", sky_parallax)

	m.set_shader_parameter("sky_top",    theme.sky_top)
	m.set_shader_parameter("sky_bottom", theme.sky_bottom)
	m.set_shader_parameter("horizon_curve", theme.horizon_curve)

	# harmless if shader ignores it
	m.set_shader_parameter("time_of_day", time_of_day)

func _configure_celestials_for(path: NodePath, is_glow: bool, ctx: Dictionary = {}) -> void:
	var n := _n(path) as CanvasItem
	if n == null or not (n.material is ShaderMaterial): return
	_configure_celestials(n.material as ShaderMaterial, current_theme, is_glow, ctx)

func _configure_celestials(m: ShaderMaterial, theme: ThemeData, is_glow: bool, ctx: Dictionary = {}) -> void:
	if ctx.is_empty():
		ctx = _viewport_ctx()
	var vp:   Vector2 = ctx.get("vp",   Vector2(get_viewport().size.x, get_viewport().size.y))
	var zoom: Vector2 = ctx.get("zoom", Vector2.ONE)

	# Screen-space orbit near top-middle
	m.set_shader_parameter("viewport_size", vp)
	m.set_shader_parameter("cam_zoom", zoom)
	m.set_shader_parameter("time_of_day", time_of_day)
	m.set_shader_parameter("orbit_center", Vector2(0.50, 1.10))
	m.set_shader_parameter("orbit_radius", 0.80)

	# Palettes + (animated) sizes
	m.set_shader_parameter("sun_color",  theme.sun_color)
	m.set_shader_parameter("moon_color", theme.moon_color)
	m.set_shader_parameter("sun_size",   _sun_size_px)
	m.set_shader_parameter("moon_size",  _moon_size_px)

	# Shape knobs (safe defaults if theme lacks them)
	var scs  = theme.get("sun_core_softness");    if scs  == null: scs  = 0.10
	var sgrm = theme.get("sun_glow_radius_mul");  if sgrm == null: sgrm = 1.40
	var shrm = theme.get("sun_halo_radius_mul");  if shrm == null: shrm = 2.20
	var sgs  = theme.get("sun_glow_strength");    if sgs  == null: sgs  = 0.35
	var shs  = theme.get("sun_halo_strength");    if shs  == null: shs  = 0.18
	var mcs  = theme.get("moon_core_softness");   if mcs  == null: mcs  = 0.06
	var mgrm = theme.get("moon_glow_radius_mul"); if mgrm == null: mgrm = 1.60
	var mgs  = theme.get("moon_glow_strength");   if mgs  == null: mgs  = 0.30

	m.set_shader_parameter("sun_core_softness", scs)
	m.set_shader_parameter("moon_core_softness", mcs)

	if is_glow:
		m.set_shader_parameter("sun_glow_radius_mul",  sgrm)
		m.set_shader_parameter("sun_halo_radius_mul",  shrm)
		m.set_shader_parameter("sun_glow_strength",    sgs)
		m.set_shader_parameter("sun_halo_strength",    shs)
		m.set_shader_parameter("moon_glow_radius_mul", mgrm)
		m.set_shader_parameter("moon_glow_strength",   mgs)

	# Ambient compensation
	var amb := _current_ambient_rgb()
	m.set_shader_parameter("ambient_tint", Vector3(amb.r, amb.g, amb.b))

func _update_lights() -> void:
	var A := time_of_day * TAU - PI * 0.5
	var sun_dir := Vector2(cos(A), -sin(A))
	var day_factor := 1.0 - _night_mix(time_of_day)

	var sun_col: Color  = sun_light_tint  if use_light_overrides else current_theme.sun_color
	var moon_col: Color = moon_light_tint if use_light_overrides else current_theme.moon_color

	var sun_energy: float  = lerpf(0.08, 0.32, pow(day_factor, 0.8))       * sun_energy_mul
	var moon_energy: float = lerpf(0.00, 0.20, pow(1.0 - day_factor, 1.2)) * moon_energy_mul

	if is_instance_valid(_sun2d):
		_sun2d.blend_mode = Light2D.BLEND_MODE_MIX
		_sun2d.shadow_enabled = true
		_sun2d.rotation = sun_dir.angle()
		_sun2d.energy = sun_energy
		if _theme_just_applied and tween_lights_on_theme_change:
			create_tween().tween_property(_sun2d, "color", sun_col, light_tween_seconds)
		else:
			_sun2d.color = sun_col
		_sun2d.shadow_filter = DirectionalLight2D.SHADOW_FILTER_PCF13
		_sun2d.shadow_color = Color(0,0,0,0.35)

	if is_instance_valid(_moon2d):
		_moon2d.blend_mode = Light2D.BLEND_MODE_MIX
		_moon2d.shadow_enabled = true
		_moon2d.rotation = (-sun_dir).angle()
		_moon2d.energy = moon_energy
		if _theme_just_applied and tween_lights_on_theme_change:
			create_tween().tween_property(_moon2d, "color", moon_col, light_tween_seconds)
		else:
			_moon2d.color = moon_col

func _update_parallax() -> void:
	var pb := _n(NP_PB) as ParallaxBackground
	if pb == null: return

	while pb.get_child_count() < current_theme.parallax_textures.size():
		var layer := ParallaxLayer.new()
		var s := Sprite2D.new()
		s.centered = false
		layer.add_child(s)
		pb.add_child(layer)

	var cam: Camera2D = get_viewport().get_camera_2d()
	var vp_i: Vector2i = get_viewport().get_visible_rect().size
	var vp: Vector2 = Vector2(vp_i.x, vp_i.y)
	var base: Vector2 = (cam.global_position - vp * 0.5) if cam else Vector2.ZERO

	for i in pb.get_child_count():
		var layer := pb.get_child(i) as ParallaxLayer
		if i < current_theme.parallax_textures.size():
			layer.visible = true
			var s := layer.get_child(0) as Sprite2D
			s.texture = current_theme.parallax_textures[i]
			s.modulate = Color.WHITE
			s.centered = false

			var start_offset := Vector2(-1024.0, 0.0)
			var mirror := Vector2(1024.0, 0.0)

			s.position = base + start_offset
			layer.motion_scale = current_theme.get_parallax_motion(i)
			layer.motion_mirroring = mirror
			layer.z_index = -100

			if s.texture:
				s.region_enabled = true
				s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var vpw: float = maxf(vp.x * 2.0, mirror.x)
				var vph: float = maxf(vp.y,       mirror.y)
				s.region_rect = Rect2(Vector2.ZERO, Vector2(vpw, vph))
		else:
			layer.visible = false

func _update_overlays() -> void:
	var canvas_mod := _n(NP_CANVAS_MOD) as CanvasModulate
	var post := _n(NP_POST) as ColorRect
	var fog := _n(NP_FOG) as ColorRect

	if canvas_mod:
		var amb := _current_ambient_rgb()
		canvas_mod.color = Color(amb.r, amb.g, amb.b, 1.0)

	if post and post.material is ShaderMaterial:
		var pm := post.material as ShaderMaterial
		var amt := current_theme.grade_strength if current_theme.grade_palette != null else 0.0
		pm.set_shader_parameter("amount", amt)
		pm.set_shader_parameter("palette_tex", current_theme.grade_palette)
		pm.set_shader_parameter("time_of_day", time_of_day)

	if fog and fog.material is ShaderMaterial:
		var fm := fog.material as ShaderMaterial
		fm.set_shader_parameter("fog_color", current_theme.fog_color)
		fm.set_shader_parameter("band_height", current_theme.fog_band_height)
		fm.set_shader_parameter("time_of_day", time_of_day)

func _update_stars() -> void:
	var starfield := _n(NP_STARS_A)
	if starfield == null: starfield = _n(NP_STARS_B)
	if starfield == null: return

	_ensure_starfield(starfield)

	var nm := _night_mix(time_of_day)
	var alpha := smoothstep(stars_fade_in_at, stars_full_at, nm)
	alpha = clamp(pow(alpha, 0.90) * star_intensity * clamp(current_theme.night_star_intensity, 0.0, 2.0), 0.0, 1.0)

	if starfield is GPUParticles2D:
		var p := starfield as GPUParticles2D
		p.emitting = true
		var mod := p.modulate
		mod.a = alpha
		p.modulate = mod

	if starfield is CanvasItem:
		(starfield as CanvasItem).visible = alpha > 0.001

# ─────────────────────────────────────────────────────────────────────────────
# Helpers / Utilities
# ─────────────────────────────────────────────────────────────────────────────
func _ensure_stack() -> void:
	if _stack or not visual_stack_scene: return
	_stack = visual_stack_scene.instantiate()
	var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(_stack)
	_configure_canvas_layer(_stack)

func _configure_canvas_layer(stack_node: Node) -> void:
	var cl := _nf(stack_node, NP_CL) as CanvasLayer
	if cl:
		cl.layer = -100 # draw behind gameplay

	_fullscreen_overlay(_nf(stack_node, NP_CTRL) as Control)
	_fullscreen_overlay(_nf(stack_node, NP_SKY) as CanvasItem)
	_fullscreen_overlay(_nf(stack_node, NP_POST) as ColorRect)
	_fullscreen_overlay(_nf(stack_node, NP_FOG) as ColorRect)
	_fullscreen_overlay(_nf(stack_node, NP_CORE) as CanvasItem)
	_fullscreen_overlay(_nf(stack_node, NP_GLOW) as CanvasItem)

	# Z order
	var sky := _nf(stack_node, NP_SKY) as CanvasItem
	var star := _nf(stack_node, NP_STARS_A)
	if star == null: star = _nf(stack_node, NP_STARS_B)
	var core := _nf(stack_node, NP_CORE) as CanvasItem
	var glow := _nf(stack_node, NP_GLOW) as CanvasItem
	var fog := _nf(stack_node, NP_FOG) as ColorRect
	var post := _nf(stack_node, NP_POST) as ColorRect
	if sky: sky.z_index = Z_SKY
	if star and star is CanvasItem: (star as CanvasItem).z_index = Z_STARS
	if core: core.z_index = Z_CORE
	if glow: glow.z_index = Z_GLOW
	if fog: fog.z_index = Z_FOG
	if post: post.z_index = Z_POST

func _fullscreen_overlay(n: Node) -> void:
	if n is Control:
		var c := n as Control
		c.set_as_top_level(true)
		c.anchor_left = 0.0; c.anchor_top = 0.0
		c.anchor_right = 1.0; c.anchor_bottom = 1.0
		c.offset_left = 0.0; c.offset_top = 0.0
		c.offset_right = 0.0; c.offset_bottom = 0.0
		var vs: Vector2i = get_viewport().get_visible_rect().size
		c.size = Vector2(vs.x, vs.y)

func _ensure_starfield(sf: Node) -> void:
	if not (sf is GPUParticles2D): return
	var p := sf as GPUParticles2D
	var mat := p.process_material as ParticleProcessMaterial
	if mat == null:
		mat = ParticleProcessMaterial.new()
		p.process_material = mat
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.0
	var vp: Vector2i = get_viewport().get_visible_rect().size
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(float(vp.x) * 0.55, float(vp.y) * 0.55, 0.0)
	p.local_coords = true
	p.position = Vector2(vp.x, vp.y) * 0.5
	p.amount = max(p.amount, 350)
	p.lifetime = max(p.lifetime, 12.0)
	p.preprocess = p.lifetime
	p.one_shot = false
	if p.texture == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		p.texture = ImageTexture.create_from_image(img)
	var cim := p.material as CanvasItemMaterial
	if cim == null:
		cim = CanvasItemMaterial.new()
		p.material = cim
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cim.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.z_index = Z_STARS

func _night_mix(t: float) -> float:
	var tp := wrapf(t + 0.5, 0.0, 1.0)
	var d := absf(tp - 0.5) * 2.0
	return 1.0 - pow(d, 2.0)

func _current_ambient_rgb() -> Color:
	var night := _night_mix(time_of_day)
	var shaped := pow(night, 1.30)
	return _lerp_color(current_theme.ambient_day, current_theme.ambient_night, shaped)

func _lerp_color(a: Color, b: Color, t: float) -> Color:
	return Color(lerpf(a.r, b.r, t), lerpf(a.g, b.g, t), lerpf(a.b, b.b, t), lerpf(a.a, b.a, t))

func _tween_celestial_sizes(target_sun: float, target_moon: float, seconds: float) -> void:
	# Initialize from current theme on first run
	if current_theme and _sun_size_px == 90.0 and _moon_size_px == 70.0:
		_sun_size_px  = current_theme.sun_size
		_moon_size_px = current_theme.moon_size

	if _size_tw and _size_tw.is_running():
		_size_tw.kill()

	_sizes_animating = true
	_size_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_size_tw.tween_property(self, "_sun_size_px",  target_sun,  seconds)
	_size_tw.parallel().tween_property(self, "_moon_size_px", target_moon, seconds)
	_size_tw.finished.connect(func(): _sizes_animating = false)

func _tick_fading_sky(ctx: Dictionary = {}) -> void:
	if ctx.is_empty():
		ctx = _viewport_ctx()
	var vp:   Vector2 = ctx.get("vp",   Vector2(get_viewport().size.x, get_viewport().size.y))
	var zoom: Vector2 = ctx.get("zoom", Vector2.ONE)

	if _sky_overlay and _sky_overlay.material is ShaderMaterial:
		_configure_sky_material(_sky_overlay.material as ShaderMaterial, current_theme, ctx)

	if _stack_fading and _stack_old_sky and _stack_old_sky.material is ShaderMaterial:
		var m := _stack_old_sky.material as ShaderMaterial
		m.set_shader_parameter("viewport_size", vp)
		m.set_shader_parameter("cam_zoom", zoom)
		m.set_shader_parameter("time_of_day", time_of_day)
		m.set_shader_parameter("orbit_center", Vector2(0.5, 1.20))
		m.set_shader_parameter("orbit_radius", 0.85)
		m.set_shader_parameter("sky_parallax", sky_parallax)

# View context (gather once)
func _viewport_ctx() -> Dictionary:
	var vp_i: Vector2i = get_viewport().get_visible_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	return {
		"vp":   Vector2(vp_i.x, vp_i.y),
		"zoom": (cam.zoom if cam else Vector2.ONE),
	}

# Node helpers
func _n(path: NodePath) -> Node:
	return _stack.get_node_or_null(path) if _stack else null

func _nf(root: Node, path: NodePath) -> Node:
	return root.get_node_or_null(path) if root else null

func _on_viewport_resized() -> void:
	_configure_canvas_layer(_stack)
	_apply_frame()
