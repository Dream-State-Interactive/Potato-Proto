# src/modes/gauntlet/store_rules.gd
@tool
class_name StoreRules
extends Resource

## The scene for the regular store. Must contain a Marker2D named "EndMarker".
@export var regular_store_scene: PackedScene
## The scene for the special, less frequent store. Must contain a Marker2D named "EndMarker".
@export var special_store_scene: PackedScene

## The minimum number of HILL segments that must pass before another store can be considered for spawning.
@export_range(1, 50) var min_hills_between_stores: int = 4

## The probability (0.0 to 1.0) of a regular store spawning after a hill, once the minimum distance is met.
@export_range(0.0, 1.0) var regular_store_probability: float = 0.2

## The probability (0.0 to 1.0) of a special store spawning INSTEAD of a regular one.
## This is checked only if the regular store roll succeeds.
@export_range(0.0, 1.0) var special_store_chance: float = 0.1
