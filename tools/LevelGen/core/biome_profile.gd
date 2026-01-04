# src/tools/LevelGen/core/biome_profile.gd
class_name BiomeProfile
extends Resource

@export_group("Global Visuals")
@export var sky_top_color: Color = Color(0.1, 0.1, 0.2)
@export var sky_bottom_color: Color = Color(0.05, 0.05, 0.1)
@export var show_celestial_bodies: bool = true
@export var scale: float = 1.0

@export_group("Music & Sound")
@export var music: AudioStream

@export_group("Glow Settings")
@export var glow_enabled: bool = false
@export var glow_intensity: float = 0.8
@export var glow_bloom: float = 0.0
@export var glow_blend_mode: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

@export_group("Atmosphere Extras")
@export var use_fog_overlay: bool = false
@export var fog_color_top: Color = Color(0.02, 0.03, 0.06, 0.0)
@export var fog_color_bot: Color = Color(0.03, 0.06, 0.09, 0.78)
@export var use_cloud_mass: bool = false # Enable for polygon cloud bands

@export_group("Layers")
## Order does not strictly matter for rendering (z_index does), but keeping it ordered will be easier to manage.
@export var layers: Array[LayerProfile] = []
