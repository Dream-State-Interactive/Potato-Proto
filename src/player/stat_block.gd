# src/player/stat_block.gd
@tool
class_name StatBlock extends Resource

@export var max_health: float = 100.0

@export_group("Physics")
@export var mass: float = 1.0
@export var grip: float = 1.0
@export var bounce: float = 0.35
@export var roll_speed: float = 5000.0
@export var jump_force: float = 50.0
@export var horizontal_nudge: float = 1000.0
@export var armor: float = 0.0
@export var base_air_control: float = 100.0
@export var max_air_control: float = 800.0
## How much bonus air control is added per pixel/sec of velocity.
## A small value like 0.2 means at 100px/s you get 20 extra force (at 500px/s it's 100 extra force)
@export var air_control_velocity_scalar: float = 0.2
