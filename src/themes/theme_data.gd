# src/themes/theme_data.gd
extends Resource
class_name ThemeData

@export_category("Identity")
@export var theme_id: StringName = &"unnamed"
@export var display_name: String = "Unnamed Theme"

@export_category("Palettes")
@export var sky_top: Color = Color(0.25, 0.45, 0.95)
@export var sky_bottom: Color = Color(0.85, 0.92, 1.0)
@export var day_tint: Color = Color(1, 1, 1)
@export var night_tint: Color = Color(0.7, 0.8, 1.0)
@export var terrain_fill: Color = Color(0.25, 0.8, 0.35)
@export var terrain_trim: Color = Color(0.13, 0.5, 0.2)
@export var accent_1: Color = Color(1.0, 0.85, 0.4)
@export var accent_2: Color = Color(0.2, 0.6, 1.0)

@export_category("Parallax")
@export var parallax_textures: Array[Texture2D] = []
@export var parallax_motions: Array[Vector2] = []

@export_category("Lighting")
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var moon_color: Color = Color(0.75, 0.85, 1.0)
@export var ambient_day: Color = Color(1, 1, 1, 0.0)
@export var ambient_night: Color = Color(0.25, 0.32, 0.45, 0.0)
@export_range(0.0, 1.0, 0.01) var night_star_intensity: float = 0.8

@export_category("World Environment")
@export_range(0.0, 4.0, 0.01) var exposure_day: float = 1.0
@export_range(0.0, 4.0, 0.01) var exposure_night: float = 0.25
@export var glow_enabled: bool = true
@export_range(0.0, 4.0, 0.01) var glow_strength_day: float = 0.69
@export_range(0.0, 4.0, 0.01) var glow_strength_night: float = 1.69

@export_category("FX / Post")
@export var grade_strength: float = 0.4
@export var grade_palette: Texture2D
@export var fog_color: Color = Color(1, 1, 1, 0.0)
@export var fog_band_height: float = 160.0

@export_category("Sky Shader (Sun)")
@export var sun_size: float = 90.0
@export_range(0.0, 0.5, 0.01) var sun_core_softness := 0.10
@export_range(0.8, 4.0, 0.05) var sun_glow_radius_mul := 1.40
@export_range(1.2, 6.0, 0.05) var sun_halo_radius_mul := 2.20
@export_range(0.0, 1.0, 0.01) var sun_glow_strength := 0.35
@export_range(0.0, 1.0, 0.01) var sun_halo_strength := 0.18

@export_category("Sky Shader (Moon)")
@export var moon_size: float = 70.0
@export_range(0.0, 0.5, 0.01) var moon_core_softness := 0.06
@export_range(0.8, 4.0, 0.05) var moon_glow_radius_mul := 1.60
@export_range(0.0, 1.0, 0.01) var moon_glow_strength := 0.30

@export_category("Sky Shader (General)")
@export_range(0.0, 1.0, 0.01) var horizon_curve: float = 0.35


func get_parallax_motion(i:int) -> Vector2:
	if i >= 0 and i < parallax_motions.size():
		return parallax_motions[i]
	return Vector2(0.1 * float(i + 1), 0)
