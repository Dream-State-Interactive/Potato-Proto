# src/core/surface/surface_manager.gd
class_name SurfaceManager
extends RefCounted

const META_KEY = "surface_def"
const COOLDOWN_MS = 200 # Don't play same surface twice in 0.2 seconds

# Dictionary to track last play time: { collider_instance_id: time_msec }
static var _last_impact_times: Dictionary = {}

static func handle_impact(collider: Object, hit_pos: Vector2, normal_impulse: float) -> void:
	if not collider: return

	# --- 1. COOLDOWN ---
	var now = Time.get_ticks_msec()
	var id = collider.get_instance_id()
	
	if id in _last_impact_times:
		if now - _last_impact_times[id] < COOLDOWN_MS:
			return
			
	_last_impact_times[id] = now
	
	var def: SurfaceDefinition = _get_surface_from_object(collider)
	if not def: return

	# --- VOLUME ---
	# Calculates how loud the sound should be (0.0 to 1.0)
	var intensity = clampf(normal_impulse / 1000.0, 0.0, 1.0)
	
	# Minimum threshold to avoid playing silent sounds
	if intensity < 0.05: return 

	# --- PLAY SOUND ---
	if not def.impact_sounds.is_empty():
		_play_impact_sound(def, hit_pos, intensity)
	
	# --- SPAWN PARTICLES ---
	if def.impact_particles:
		_spawn_particles(def, hit_pos)

## Efficiently retrieves definition from Metadata
static func _get_surface_from_object(obj: Object) -> SurfaceDefinition:
	if not obj: return null
	
	if obj.has_meta(META_KEY):
		return obj.get_meta(META_KEY) as SurfaceDefinition
	
	return null

static func _play_impact_sound(def: SurfaceDefinition, pos: Vector2, intensity: float) -> void:
	var stream = def.impact_sounds.pick_random()
	if not stream: return

	# Convert 0.0-1.0 intensity to Decibels
	var final_vol = linear_to_db(intensity) + def.volume_db_offset
	
	# Play Spatial Sound (is_global = false)
	AudioService.play_sfx(stream, def.pitch_randomness, final_vol, pos, false, "", false)

static func _spawn_particles(def: SurfaceDefinition, pos: Vector2) -> void:
	pass
