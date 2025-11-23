# src/modes/gauntlet/special_segment_rule.gd
@tool
class_name SpecialSegmentRule
extends Resource

## The handcrafted scene to spawn (must contain an "EndMarker" node).
@export var scene: PackedScene

@export_group("Spawn Rules")
## The probability (0.0 to 1.0) of this segment being chosen to spawn after a hill is completed.
## The generator will roll for each rule in the list; the first successful roll is chosen.
@export_range(0.0, 1.0) var probability_per_hill: float = 0.05

## The minimum number of standard hill segments that must pass before this can spawn again.
@export_range(0, 50) var min_hills_between_spawns: int = 5
