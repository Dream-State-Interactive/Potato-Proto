# src/modes/gauntlet/hill_generation_params.gd
@tool
class_name HillGenerationParams
extends Resource

enum GeneratorType { NOISE_HILL, FLAT_LINE }
@export var generator_type: GeneratorType = GeneratorType.NOISE_HILL

@export_group("Shape")
@export_range(500.0, 20000.0, 100.0) var length: float = 1200.0
@export_range(0.0, 500.0, 5.0) var amplitude: float = 60.0
@export_range(0.0, 1.0, 0.01) var slope: float = 0.2
@export_range(0.0, 0.001, 0.00001) var steepness_increase: float = 0.00005

@export_group("Noise")
@export_range(0.0000, 0.01, 0.0001) var frequency: float = 0.0015

@export_group("Detail & Performance")
@export_range(20.0, 200.0, 5.0) var control_step: float = 140.0
@export_range(2.0, 50.0, 1.0) var visual_bake_interval: float = 8.0
@export_range(5.0, 100.0, 1.0) var collision_bake_interval: float = 18.0
@export_range(0.0, 10.0, 0.1) var simplify_epsilon_px: float = 4.0
@export_range(64, 1024, 8) var max_collision_vertices: int = 512
