# src/tools/LevelGen/core/hazard_config.gd
class_name HazardConfig
extends Resource

## The scene file for the hazard to be spawned.
@export var hazard_scene: PackedScene

@export_group("Spawn Conditions")
## The first chunk index this hazard can appear on (inclusive).
@export var min_chunk_index: int = 0
## The last chunk index this hazard can appear on. Use a high number for 'forever'.
@export var max_chunk_index: int = 10000

@export_group("Spawn Behavior & Scaling")
## The base probability (0.0 to 1.0) of spawning when it first appears.
@export_range(0.0, 1.0) var base_density: float = 0.05

## How much to add to the density for each chunk completed *after* min_chunk_index.
## Set to 0 for a fixed density.
@export var density_increase_per_chunk: float = 0.001

## The absolute maximum density this hazard can reach.
@export_range(0.0, 1.0) var max_density: float = 0.25

## At what percentage of the chunk's length (0.0 to 1.0) should we start boosting the spawn rate.
@export_range(0.0, 1.0) var end_boost_start_percent: float = 0.8

## How much to multiply the density by in the final section of the chunk.
@export var end_boost_multiplier: float = 1.0

## The minimum scale for the spawned hazard. (1, 1) is default size.
@export var min_scale: Vector2 = Vector2.ONE

## The maximum scale for the spawned hazard. (1, 1) is default size.
@export var max_scale: Vector2 = Vector2.ONE

## How many placement "slots" (terrain vertices) this hazard occupies (within current system vertices are spaced around 20px).
@export_range(1, 10000) var slot_cost: int = 3
