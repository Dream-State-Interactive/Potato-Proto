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
const PL_0            : NodePath = ^"CanvasLayer/ParallaxLayer0"
const PL_1            : NodePath = ^"CanvasLayer/ParallaxLayer1"
const PL_2            : NodePath = ^"CanvasLayer/ParallaxLayer2"
const PL_3            : NodePath = ^"CanvasLayer/ParallaxLayer3"
const PL_4            : NodePath = ^"CanvasLayer/ParallaxLayer4"
const NP_CANVAS_MOD   : NodePath = ^"CanvasLayer/Control/CanvasModulate"
const NP_CORE         : NodePath = ^"CanvasLayer/Control/Celestials"
const NP_GLOW         : NodePath = ^"CanvasLayer/Control/CelestialsGlow"

const MAX_PARALLAX_LAYERS := 5

const Z_SKY           := 0
const Z_STARS         := 10
const Z_CORE          := 12
const Z_GLOW          := 13
const Z_PARALLAX_BASE := 14 # Base z-index for the furthest parallax layer (Layer 4)
const Z_FOG           := 20
const Z_POST          := 30

# ─────────────────────────────────────────────────────────────────────────────
# Public state
# ─────────────────────────────────────────────────────────────────────────────
var current_theme: ThemeData
var time_of_day := 0.25 # 0=dawn, 0.5=noon, 0.75=dusk, 1=midnight

var _parallax_layers: Array[Parallax2D] = []
var _parallax_sprites_a: Array[Sprite2D] = []
var _parallax_sprites_b: Array[Sprite2D] = []

# ─────────────────────────────────────────────────────────────────────────────
# Scene refs / stack
# ─────────────────────────────────────────────────────────────────────────────
@export var visual_stack_scene: PackedScene = preload("res://src/themes/visual_stack.tscn")
var _stack: Node = null # instance of visual_stack.tscn

var _sun2d: DirectionalLight2D = null
var _moon2d: DirectionalLight2D = null
var _env: Environment

# ─────────────────────────────────────────────────────────────────────────────
# Transitions / Fades
# ─────────────────────────────────────────────────────────────────────────────
# Celestial size tween
var _sun_size_px: float  = 90.0
var _moon_size_px: float = 70.0	
var _sizes_animating := false
var _size_tw: Tween = null
@export_range(0.0, 3.0, 0.05) var size_tween_seconds := 1.2

# State for which parallax sprite (A or B) is currently the active one.
var _parallax_sprite_is_a := true
# Add a state flag to prevent _update_parallax from running during a fade.
var _is_transitioning := false


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
	if GameManager:
		GameManager.scene_changed.connect(_on_scene_changed)

	get_viewport().size_changed.connect(_on_viewport_resized)
	_ensure_stack()

	# Initial scan for nodes. This will be re-run on every scene change
	_scan_for_scene_nodes()
	call_deferred("_ensure_env")

	# Prevent startup flash: configure, then reveal Control
	var ctrl := _n(NP_CTRL) as CanvasItem
	if ctrl: ctrl.visible = false
	_apply_frame()
	if ctrl: ctrl.visible = true

func _process(_dt: float) -> void:
	if _sizes_animating:
		_apply_frame()

# ─────────────────────────────────────────────────────────────────────────────
# Scene Change Handling
# ─────────────────────────────────────────────────────────────────────────────
func _on_scene_changed() -> void:
	# A new scene is about to be loaded. Clear old, invalid references.
	_sun2d = null
	_moon2d = null
	_env = null
	
	# Wait one frame for the new scene to be fully loaded into the tree, then scan it for the nodes we need.
	await get_tree().process_frame
	_scan_for_scene_nodes()
	_ensure_env()

func _scan_for_scene_nodes() -> void:
	var root := get_tree().current_scene
	if root:
		_sun2d  = root.get_node_or_null("Sun2D")  as DirectionalLight2D
		_moon2d = root.get_node_or_null("Moon2D") as DirectionalLight2D
	else:
		_sun2d = null
		_moon2d = null

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func apply_theme(theme: ThemeData) -> void:
	if theme == null or theme == current_theme: return
	
	var sky := _n(NP_SKY) as CanvasItem
	if sky and sky.material is ShaderMaterial:
		var mat := sky.material as ShaderMaterial
		# Instantly apply the new theme
		mat.set_shader_parameter("sky_top", theme.sky_top)
		mat.set_shader_parameter("sky_bottom", theme.sky_bottom)
		mat.set_shader_parameter("horizon_curve", theme.horizon_curve)
		# Set "old" values to the same to ensure blend starts correctly
		mat.set_shader_parameter("sky_top_old", theme.sky_top)
		mat.set_shader_parameter("sky_bottom_old", theme.sky_bottom)
		mat.set_shader_parameter("horizon_curve_old", theme.horizon_curve)
		mat.set_shader_parameter("transition_blend", 1.0) # 1.0 means fully showing the "new" theme

	current_theme = theme
	_tween_celestial_sizes(theme.sun_size, theme.moon_size, 0.0) # Instant
	_apply_frame()
	_update_cloud_lighting()
	emit_signal("theme_applied", theme)

func _find_world_environment(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n as WorldEnvironment
	for c in n.get_children():
		var hit := _find_world_environment(c)
		if hit:
			return hit
	return null

func set_time_of_day(t: float) -> void:
	time_of_day = clampf(t, 0.0, 1.0)
	_apply_frame()
	_update_cloud_lighting()
	emit_signal("time_of_day_changed", time_of_day)

func transition_to_theme(new_theme: ThemeData, seconds: float = 1.2) -> void:
	# Prevent starting a new transition if one is already running.
	if new_theme == null or new_theme == current_theme or _is_transitioning:
		return
	
	_is_transitioning = true # 1. Set the flag immediately to block updates.
	var old_theme := current_theme
	current_theme = new_theme

	var sky := _n(NP_SKY) as CanvasItem
	if not (sky and sky.material is ShaderMaterial):
		apply_theme(new_theme) # Fallback to instant apply
		_is_transitioning = false # Clear flag on fallback
		return

	var mat := sky.material as ShaderMaterial
	
	# 1. Set "old" parameters
	if old_theme:
		mat.set_shader_parameter("sky_top_old", old_theme.sky_top)
		mat.set_shader_parameter("sky_bottom_old", old_theme.sky_bottom)
		mat.set_shader_parameter("horizon_curve_old", old_theme.horizon_curve)
	else:
		mat.set_shader_parameter("sky_top_old", new_theme.sky_top)
		mat.set_shader_parameter("sky_bottom_old", new_theme.sky_bottom)
		mat.set_shader_parameter("horizon_curve_old", new_theme.horizon_curve)

	# 2. Set "new" parameters
	mat.set_shader_parameter("sky_top", new_theme.sky_top)
	mat.set_shader_parameter("sky_bottom", new_theme.sky_bottom)
	mat.set_shader_parameter("horizon_curve", new_theme.horizon_curve)
	
	# 3. Create the main tween
	mat.set_shader_parameter("transition_blend", 0.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mat, "shader_parameter/transition_blend", 1.0, seconds)
	
	# 4. Animate other properties in parallel
	_tween_celestial_sizes(new_theme.sun_size, new_theme.moon_size, seconds)
	_transition_parallax_fade(tw, old_theme, new_theme, seconds)
	
	if tween_lights_on_theme_change:
		var sun_col: Color  = sun_light_tint  if use_light_overrides else new_theme.sun_color
		var moon_col: Color = moon_light_tint if use_light_overrides else new_theme.moon_color
		if is_instance_valid(_sun2d):
			tw.parallel().tween_property(_sun2d, "color", sun_col, seconds)
		if is_instance_valid(_moon2d):
			tw.parallel().tween_property(_moon2d, "color", moon_col, seconds)

	# 5. On completion, flip the state, clear the flag, and do a final cleanup apply.
	tw.finished.connect(func():
		_parallax_sprite_is_a = not _parallax_sprite_is_a
		_is_transitioning = false # 2. Clear the flag.
		emit_signal("theme_applied", new_theme)
		_apply_frame() # 3. Call apply_frame ONCE at the very end for a clean state.
		_update_cloud_lighting()
	)


# ─────────────────────────────────────────────────────────────────────────────
# Frame update (single orchestration point)
# ─────────────────────────────────────────────────────────────────────────────
func _apply_frame() -> void:
	if current_theme == null: return
	_ensure_stack() # This is safe to call every frame
	if not is_instance_valid(_stack): return

	var ctx := _viewport_ctx()

	# 1) Sky
	var sky := _n(NP_SKY) as CanvasItem
	if sky and sky.material is ShaderMaterial:
		_configure_sky_material(sky.material as ShaderMaterial, current_theme, ctx)

	# 2) Celestials (core + glow)
	_configure_celestials_for(NP_CORE, false, ctx)
	_configure_celestials_for(NP_GLOW, true,  ctx)

	# 3) Lights / Parallax / Overlays / Stars
	_update_lights()
	# Only update parallax if we are not in the middle of a transition.
	if not _is_transitioning:
		_update_parallax()
	_update_overlays()
	_update_stars()
	_update_world_environment()

func _update_world_environment() -> void:
	_ensure_env()
	if _env == null:
		return

	if _env.tonemap_mode != Environment.TONE_MAPPER_LINEAR:
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	# 0 = day, 1 = night (your curve)
	var night := _night_mix(time_of_day)
	var t := pow(night, 1.30)

	# Exposure (Tonemap → Exposure)
	var exp_day: float = 1.0
	var exp_night: float = 0.25
	if current_theme != null:
		exp_day = current_theme.exposure_day
		exp_night = current_theme.exposure_night
	var exposure := lerpf(exp_day, exp_night, t)
	_env.tonemap_exposure = exposure

	# Glow (Glow → Strength)
	var g_enabled := true
	var g_day: float = 0.69
	var g_night: float = 1.69
	if current_theme != null:
		g_enabled = current_theme.glow_enabled
		g_day = current_theme.glow_strength_day
		g_night = current_theme.glow_strength_night

	var g_strength := lerpf(g_day, g_night, t)
	_env.glow_enabled = g_enabled
	_env.glow_strength = g_strength



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
	
	# Use the theme parameter directly
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
		_sun2d.rotation = (-sun_dir).angle()
		_sun2d.energy = sun_energy
		# The conditional logic is gone. Just set the color directly.
		_sun2d.color = sun_col
		_sun2d.shadow_filter = DirectionalLight2D.SHADOW_FILTER_PCF13
		_sun2d.shadow_color = Color(0,0,0,0.35)

	if is_instance_valid(_moon2d):
		_moon2d.blend_mode = Light2D.BLEND_MODE_MIX
		_moon2d.shadow_enabled = true
		_moon2d.rotation = sun_dir.angle()
		_moon2d.energy = moon_energy
		# The conditional logic is gone. Just set the color directly.
		_moon2d.color = moon_col


#This function now handles the A/B sprite system for instant updates.
func _update_parallax() -> void:
	var cl := _n(NP_CL) as CanvasLayer
	if not is_instance_valid(cl) or current_theme == null:
		return

	var textures_to_apply: Array[Texture2D] = current_theme.parallax_textures
	var sprite_name_active   = "SpriteA" if _parallax_sprite_is_a else "SpriteB"
	var sprite_name_inactive = "SpriteB" if _parallax_sprite_is_a else "SpriteA"

	for i in range(MAX_PARALLAX_LAYERS):
		var p_layer := cl.get_node_or_null("ParallaxLayer%d" % i) as Parallax2D
		
		if not is_instance_valid(p_layer):
			printerr("ThemeManager: ParallaxLayer%d not found in the visual stack scene!" % i)
			continue

		var s_active := p_layer.get_node_or_null(sprite_name_active) as Sprite2D
		var s_inactive := p_layer.get_node_or_null(sprite_name_inactive) as Sprite2D

		if not is_instance_valid(s_active) or not is_instance_valid(s_inactive):
			printerr("ThemeManager: SpriteA/SpriteB not found in ParallaxLayer%d!" % i)
			continue
		
		# Always hide the inactive sprite
		s_inactive.visible = false

		if i < textures_to_apply.size() and textures_to_apply[i] != null:
			p_layer.visible = true
			s_active.visible = true
			s_active.modulate.a = 1.0 # Ensure it's fully visible
			
			_configure_parallax_sprite(
				p_layer,
				s_active,
				textures_to_apply[i],
				current_theme.get_parallax_motion(i),
				i
			)
		else:
			# No texture for this layer, hide the layer and the active sprite.
			p_layer.visible = false
			s_active.visible = false

func _transition_parallax_fade(tw: Tween, old_theme: ThemeData, new_theme: ThemeData, seconds: float) -> void:
	var cl := _n(NP_CL) as CanvasLayer
	if not is_instance_valid(cl): return

	var old_textures = old_theme.parallax_textures if old_theme else []
	var new_textures = new_theme.parallax_textures

	var sprite_name_out = "SpriteA" if _parallax_sprite_is_a else "SpriteB"
	var sprite_name_in  = "SpriteB" if _parallax_sprite_is_a else "SpriteA"

	for i in range(MAX_PARALLAX_LAYERS):
		var p_layer := cl.get_node_or_null("ParallaxLayer%d" % i) as Parallax2D
		if not is_instance_valid(p_layer): continue

		var s_out := p_layer.get_node_or_null(sprite_name_out) as Sprite2D
		var s_in  := p_layer.get_node_or_null(sprite_name_in) as Sprite2D

		if not is_instance_valid(s_out) or not is_instance_valid(s_in):
			printerr("ThemeManager: ParallaxLayer%d requires two Sprite2D children named 'SpriteA' and 'SpriteB' for fading." % i)
			continue

		# --- FADE IN ---
		if i < new_textures.size() and new_textures[i] != null:
			p_layer.visible = true
			_configure_parallax_sprite(p_layer, s_in, new_textures[i], new_theme.get_parallax_motion(i), i)
			s_in.modulate.a = 0.0
			s_in.visible = true
			tw.parallel().tween_property(s_in, "modulate:a", 1.0, seconds)
		else:
			s_in.visible = false

		# --- FADE OUT ---
		if i < old_textures.size() and old_textures[i] != null:
			s_out.visible = true
			tw.parallel().tween_property(s_out, "modulate:a", 0.0, seconds)
		else:
			s_out.visible = false

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

func _update_cloud_lighting() -> void:
	if not is_instance_valid(_stack): return

	# Calculate celestial positions and visibility once
	var A = (time_of_day * TAU) - (PI / 2.0)
	var orbit_center = Vector2(0.50, 1.10)
	var orbit_radius = 0.80
	var sun_pos_uv = orbit_center + Vector2(cos(A), -sin(A)) * orbit_radius
	var moon_pos_uv = orbit_center + Vector2(cos(A + PI), -sin(A + PI)) * orbit_radius
	
	var altitude = sin(A)
	var sun_vis = smoothstep(-0.04, 0.10, altitude)
	var moon_vis = smoothstep(-0.04, 0.10, -altitude) * (1.0 - sun_vis * 0.95)

	# Loop through all parallax layers and their sprites
	for i in range(MAX_PARALLAX_LAYERS):
		var p_layer := _n(NodePath("CanvasLayer/ParallaxLayer%d" % i)) as Parallax2D
		if not is_instance_valid(p_layer): continue

		for sprite_name in ["SpriteA", "SpriteB"]:
			var sprite := p_layer.get_node_or_null(sprite_name) as Sprite2D
			if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
				var mat := sprite.material as ShaderMaterial
				mat.set_shader_parameter("sun_pos_uv", sun_pos_uv)
				mat.set_shader_parameter("moon_pos_uv", moon_pos_uv)
				mat.set_shader_parameter("sun_color", current_theme.sun_color)
				mat.set_shader_parameter("moon_color", current_theme.moon_color)
				mat.set_shader_parameter("sun_vis", sun_vis)
				mat.set_shader_parameter("moon_vis", moon_vis)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers / Utilities
# ─────────────────────────────────────────────────────────────────────────────
func _configure_parallax_sprite(p_layer: Parallax2D, sprite: Sprite2D, texture: Texture2D, motion_scale: Vector2, layer_index: int) -> void:
	var tex_w := float(texture.get_width())
	var tex_h := float(texture.get_height())

	sprite.texture = texture
	sprite.centered = false
	
	# Layer 0 should be on top (highest z-index), Layer 4 should be at the back (lowest z-index).
	sprite.z_index = Z_PARALLAX_BASE + (MAX_PARALLAX_LAYERS - 1 - layer_index)
		
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	p_layer.scroll_scale = motion_scale
	p_layer.repeat_size = Vector2(tex_w, tex_h)

func _ensure_stack() -> void:
	if is_instance_valid(_stack): return
	if not visual_stack_scene:
		printerr("ThemeManager: visual_stack_scene is not set!")
		return
	
	_stack = visual_stack_scene.instantiate()
	add_child(_stack)
	
	_configure_canvas_layer(_stack)
	_cache_stack_nodes()

func _cache_stack_nodes() -> void:
	_parallax_layers.clear()
	_parallax_sprites_a.clear()
	_parallax_sprites_b.clear()

	if not is_instance_valid(_stack): return

	var cl := _n(NP_CL) as CanvasLayer
	if not is_instance_valid(cl): return

	for i in range(MAX_PARALLAX_LAYERS):
		var p_layer := cl.get_node_or_null("ParallaxLayer%d" % i) as Parallax2D
		_parallax_layers.append(p_layer) # can be null, check validity later

		if is_instance_valid(p_layer):
			_parallax_sprites_a.append(p_layer.get_node_or_null("SpriteA"))
			_parallax_sprites_b.append(p_layer.get_node_or_null("SpriteB"))
		else:
			_parallax_sprites_a.append(null)
			_parallax_sprites_b.append(null)

func _configure_canvas_layer(stack_node: Node) -> void:
	if not is_instance_valid(stack_node): return
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


# View context (gather once)
func _viewport_ctx() -> Dictionary:
	var vp_i: Vector2i = get_viewport().get_visible_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d()
	return {
		"vp":   Vector2(vp_i.x, vp_i.y),
		"zoom": (cam.zoom if cam else Vector2.ONE),
	}

# ─────────────────────────────────────────────────────────────────────────────
# Node helpers
# ─────────────────────────────────────────────────────────────────────────────
func _n(path: NodePath) -> Node:
	return _stack.get_node_or_null(path) if is_instance_valid(_stack) else null

func _nf(root: Node, path: NodePath) -> Node:
	return root.get_node_or_null(path) if is_instance_valid(root) else null

func _on_viewport_resized() -> void:
	_configure_canvas_layer(_stack)
	_apply_frame()

func _ensure_env() -> void:
	if is_instance_valid(_env):
		return
	var root := get_tree().current_scene
	if root == null:
		return
	var we := root.find_child(&"WorldEnvironment", true, false) as WorldEnvironment
	if we == null:
		return
	_env = we.environment
	if _env != null:
		# Connect to the node's exit signal, not the environment resource itself
		we.tree_exited.connect(func(): _env = null)  # reset on level unload```
