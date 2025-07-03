# src/upgrades/upgrade_data.gd
@tool
class_name UpgradeData extends Resource

# The name of the stat in player.stats to change (e.g., "roll_speed")
@export var stat_identifier: String = ""

# How much to increase the stat by each time.
@export var upgrade_value: float = 0.0

# The base cost for the first upgrade.
@export var base_cost: int = 100

# Optional: How much the cost increases each time you buy it (for scaling costs).
# Set to 0 for a flat cost.
@export var cost_increase_per_level: int = 50 
