# src/modes/gauntlet/special_segment_config.gd
class_name SpecialSegmentConfig
extends Resource

## Special scene to instantiate.
@export var scene: PackedScene

## How many hill segments before this scene is triggered.
@export var number_of_hills_required: int = 10

## Number of times this scene will generate in a row before moving to the next segment.
@export var number_of_times_to_repeat: int = 1
