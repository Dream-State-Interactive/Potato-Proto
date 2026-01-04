# src/tools/LevelGen/assets/_controllers/dust_mote_controller.gd"
extends Node2D

var motes: Array[Polygon2D] = []
var float_speed: float = 0.15
var float_range: float = 25.0

func _process(delta):
	var t = Time.get_ticks_msec() * 0.001 * float_speed
	for p in motes:
		var phase = p.get_meta("phase")
		var start_y = p.get_meta("start_y")
		var speed_mod = p.get_meta("speed_mod")
		p.position.y = start_y + sin((t * speed_mod) + phase) * float_range
		p.position.x += cos((t * 0.5 * speed_mod) + phase) * 0.2
