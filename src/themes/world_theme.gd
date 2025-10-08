# src/modes/gauntlet/world_theme.gd
@tool
class_name WorldTheme
extends Resource

@export_category("Core Settings")
## The visual theme (sky, lighting, etc.) to apply.
@export var theme_data: ThemeData
## The number of hills the player must complete before this theme becomes active.
## A value of 0 means it's the starting theme.
@export_range(0, 100) var number_of_hills_to_trigger: int = 0

@export_category("Hazard Spawning")
## The set of hazards that can spawn while this theme is active.
## This will overwrite the HazardGenerator's default list.
@export var hazard_configs: Array[HazardConfig]

@export_category("Hill Generation Overrides")
## If true, the parameters below will be used instead of the ones from ProgressionManager.
@export var override_hill_parameters: bool = false
## The specific hill shape parameters to use.
@export var hill_parameters: HillGenerationParams
