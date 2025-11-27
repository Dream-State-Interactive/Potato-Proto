# src/modes/gauntlet/world_theme.gd
@tool
class_name WorldTheme
extends Resource

@export_category("Core Settings")
## The visual theme (sky, lighting, etc.) to apply.
@export var theme_data: ThemeData

@export_group("Triggers")
## If LevelGenerator is in SEGMENT mode, trigger after this many hills.
@export_range(0, 100) var trigger_at_segment_count: int = 0
## If LevelGenerator is in SCORE mode, trigger when player score exceeds this value.
@export_range(0, 1000000, 500) var trigger_at_score: int = 0


@export_category("Hill Generation")
## A weighted list of different hill shapes that can be generated in this biome.
## The generator will pick one randomly based on its weight.
@export var hill_profiles: Array[HillProfile]

@export_category("Hazard Spawning")
## The set of hazards that can spawn while this theme is active.
## This will overwrite the HazardGenerator's default list.
@export var hazard_configs: Array[HazardConfig]

@export_category("Store Generation")
## Rules defining how and when stores appear in this biome.
@export var store_rules: StoreRules

@export_category("Handcrafted Content")
## A list of special, non-procedural segments that can be injected into the level.
## Each rule has its own probability of appearing.
@export var handcrafted_segments: Array[HandcraftedSegmentRule]
