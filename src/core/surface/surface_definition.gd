# src/core/surface/surface_definition.gd
@tool
class_name SurfaceDefinition
extends Resource

@export_group("Physics")
## The literal physics properties (friction, bounce).
@export var physics_material: PhysicsMaterial

@export_group("Audio")
@export var impact_sounds: Array[AudioStream] = []
@export var slide_sounds: Array[AudioStream] = [] 
@export var footstep_sounds: Array[AudioStream] = []

@export_group("Visuals")
@export var impact_particles: PackedScene

@export_group("Settings")
@export_range(0.0, 2.0) var volume_db_offset: float = 0.0
@export_range(0.5, 2.0) var pitch_scale: float = 1.0
@export_range(0.0, 0.5) var pitch_randomness: float = 0.1
