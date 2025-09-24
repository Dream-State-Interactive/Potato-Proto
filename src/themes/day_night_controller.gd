# res://themes/day_night_controller.gd
extends Node
class_name DayNightController
@export_range(0.0, 120.0, 0.05) var hours_per_minute: float = 1.0
@export var paused: bool = false

func _process(delta: float) -> void:
	if paused: return
	var day_speed := hours_per_minute / 24.0        # “days” per real minute
	var t := wrapf(ThemeManager.time_of_day + day_speed * (delta / 60.0), 0.0, 1.0)
	ThemeManager.set_time_of_day(t)
