# src/modes/gauntlet/hill_profile.gd
@tool
class_name HillProfile
extends Resource

## The specific hill shape parameters to use for this profile.
@export var hill_parameters: HillGenerationParams

## The chance for this profile to be chosen relative to others in the same biome.
## A profile with weight 2 is twice as likely to be picked as one with weight 1.
@export_range(0.1, 100.0) var weight: float = 1.0
