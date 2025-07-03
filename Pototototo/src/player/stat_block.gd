# src/player/stat_block.gd
@tool
class_name StatBlock extends Resource

@export var max_health: float = 100.0

@export_group("Physics")
@export var mass: float = 1.0
@export var grip: float = 1.0
@export var bounce: float = 0.5
@export var roll_speed: float = 5000.0
@export var jump_force: float = 500.0
@export var horizontal_nudge: float = 1000.0
