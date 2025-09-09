@tool
class_name HazardConfig
extends Resource

## The scene file for the hazard to be spawned.
@export var hazard_scene: PackedScene

@export_group("Spawn Conditions")
## The first hill number this hazard can appear on (inclusive).
@export var min_hills_completed: int = 0
## The last hill this hazard can appear on. Use a high number for 'forever'.
@export var max_hills_completed: int = 1000

@export_group("Spawn Behavior & Scaling")
## The base probability (0.0 to 1.0) of spawning when it first appears.
@export_range(0.0, 1.0) var base_density: float = 0.05

## How much to add to the density for each hill completed *after* min_hills_completed.
## Set to 0 for a fixed density.
@export var density_increase_per_hill: float = 0.001

## The absolute maximum density this hazard can reach.
@export_range(0.0, 1.0) var max_density: float = 0.25

## At what percentage of the hill's length (0.0 to 1.0) should we start boosting the spawn rate.
@export_range(0.0, 1.0) var end_boost_start_percent: float = 0.8

## How much to multiply the density by in the final section of the hill.
@export var end_boost_multiplier: float = 1.0

## The minimum scale for the spawned hazard. (1, 1) is default size.
@export var min_scale: Vector2 = Vector2.ONE

## The maximum scale for the spawned hazard. (1, 1) is default size.
@export var max_scale: Vector2 = Vector2.ONE
