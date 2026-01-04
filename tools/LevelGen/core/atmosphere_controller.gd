# src/tools/LevelGen/core/atmosphere_controller.gd
extends Node2D

var _cloud_nodes: Array[Node2D] = []
var _drift_speed: float = 4.5
var _noise_cloud: FastNoiseLite

func _ready():
	_noise_cloud = FastNoiseLite.new()
	_noise_cloud.seed = 777
	_noise_cloud.frequency = 0.0009

func _process(delta):
	# Drift Clouds
	if _cloud_nodes.is_empty(): return
	
	var screen = get_viewport_rect().size
	var drift = _drift_speed * delta
	var buffer = 260.0
	var wrap_w = screen.x + buffer * 2.0
	
	for p in _cloud_nodes:
		p.position.x += drift
		if p.position.x > (screen.x + buffer):
			p.position.x -= wrap_w

func update_biome(biome: BiomeProfile):
	# Clear existing
	for c in get_children(): c.queue_free()
	_cloud_nodes.clear()
	
	if not biome: return
	
	var screen = get_viewport_rect().size
	
	# 1. Vignette
	# (We assume vignette is desired for all "dark" biomes, or you can add a flag to BiomeProfile)
	if biome.use_fog_overlay: # Reusing this flag for "Spooky Atmosphere"
		_spawn_vignette()
		_spawn_fog_overlay(biome)
	
	# 2. Cloud Mass
	if biome.use_cloud_mass:
		_spawn_cloud_mass(screen)

func _spawn_vignette():
	var v = ColorRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sm = ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = """
	shader_type canvas_item;
	render_mode unshaded;
	void fragment() {
		vec2 uv = SCREEN_UV;
		vec2 p = uv - vec2(0.5);
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		p.x *= aspect;
		float d = length(p);
		float v = smoothstep(0.2, 0.92, d);
		COLOR = vec4(0.0, 0.0, 0.0, v * 0.62);
	}
	"""
	v.material = sm
	add_child(v)

func _spawn_fog_overlay(biome: BiomeProfile):
	var fog = TextureRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var g = Gradient.new()
	g.set_color(0, biome.fog_color_top)
	g.set_color(1, biome.fog_color_bot)
	
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	
	fog.texture = gt
	add_child(fog)

func _spawn_cloud_mass(screen: Vector2):
	var rng = RandomNumberGenerator.new(); rng.seed = 1337
	var color_a = Color(0.06, 0.09, 0.13)
	var color_b = Color(0.04, 0.06, 0.10)
	
	for i in range(6): # 6 bands
		var band = Polygon2D.new()
		var c = color_a.lerp(color_b, rng.randf())
		c.a = rng.randf_range(0.50, 0.72)
		band.color = c
		
		var top_y = screen.y * rng.randf_range(0.02, 0.45)
		var height = screen.y * rng.randf_range(0.18, 0.36)
		var wob = 0.55 * rng.randf_range(0.7, 1.3)
		
		var pts = PackedVector2Array()
		var step = 60
		for x_i in range(-step, int(screen.x) + step, step):
			var x = float(x_i)
			var gx = x + float(i) * 173.0
			var n = _noise_cloud.get_noise_1d(gx * 2.0)
			var y = top_y + (n * height * 0.18 * wob)
			pts.append(Vector2(x, y))
			
		pts.append(Vector2(screen.x + step, top_y + height))
		pts.append(Vector2(-step, top_y + height))
		
		band.polygon = pts
		add_child(band)
		_cloud_nodes.append(band)
