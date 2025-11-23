# src/collectibles/starch_point.gd
@tool
class_name StarchPoint
extends Collectible

@export var starch_value: int = 10
@export var pickup_sound: AudioStream = preload("res://assets/sfx/StarchyCrunch.ogg")
@export var pitch_scale: float = 0.2
@export var volume_db: float = -8.0

@export var pulse_speed: float = 2.0  # Speed of pulsing
@export var scale_amount: float = 0.1  # Amount of scaling for the pulse effect

var elapsed_time: float = 0.0
var pulse_offset: float = 0.0

func _ready():
	# Connect the Area2D's signal to this script's function
	body_entered.connect(_on_triggered)
	randomize()
	# Use TAU (2*PI) for a full cycle; this is a neat Godot constant
	pulse_offset = randf_range(0.0, TAU)
	
func _process(delta: float) -> void:
	elapsed_time += delta
	# Calculate scale using a sine wave with a unique offset for each instance.
	var scale_factor = 1.0 + sin(elapsed_time * pulse_speed + pulse_offset) * scale_amount
	scale = Vector2(scale_factor, scale_factor)

func _on_collect(player: Player):
	print("Player collected starch point with ID: %s" % unique_id)
	player.add_starch(starch_value)
	AudioService.play_sfx(pickup_sound, pitch_scale, volume_db, global_position, false, 'StarchyCrunch')
		
	queue_free()
