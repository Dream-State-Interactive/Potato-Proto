# src/modes/gauntlet/handcrafted_segment_rule.gd
@tool
class_name HandcraftedSegmentRule
extends Resource

## The handcrafted scene to spawn. Must contain a Marker2D named "EndMarker".
@export var scene: PackedScene

## The probability (0.0 to 1.0) of this segment spawning in place of a procedural hill.
## This is checked against a random roll for each new segment.
@export_range(0.0, 1.0) var probability: float = 0.05

## The minimum number of HILL segments that must pass before this can be considered for spawning again.
## Prevents handcrafted segments from clumping together.
@export_range(0, 50) var min_hills_between_spawns: int = 3
