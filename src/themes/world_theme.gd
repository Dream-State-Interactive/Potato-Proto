# src/modes/gauntlet/world_theme.gd
@tool
class_name WorldTheme
extends Resource

@export_category("Core Settings")
## The visual theme (sky, lighting, etc.) to apply.
@export var theme_data: ThemeData
## The number of segments the player must complete before this theme becomes active.
## Behavior is controlled by 'Progress Theme On Hills Only' in the LevelGenerator.
@export_range(0, 100) var trigger_at_segment_count: int = 0

@export_category("Hazard Spawning")
## The set of hazards that can spawn while this theme is active.
## This will overwrite the HazardGenerator's default list.
@export var hazard_configs: Array[HazardConfig]

@export_category("Hill Generation Overrides")
## If true, the parameters below will be used instead of the ones from ProgressionManager.
@export var override_hill_parameters: bool = false
## The specific hill shape parameters to use.
@export var hill_parameters: HillGenerationParams
