extends Area2D

@export var pickup_sound: AudioStream  
@export var pitch_scale: float = 1.5  
@export var volume_db: float = -6.0  
@export var pulse_speed: float = 2.0  # Speed of pulsing
@export var scale_amount: float = 0.1  # Amount of scaling for the pulse effect

var elapsed_time: float = 0.0
var pulse_offset: float = 0.0

func _ready():
	randomize()
	# Use TAU (2*PI) for a full cycle; this is a neat Godot constant
	pulse_offset = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	elapsed_time += delta
	# Calculate scale using a sine wave with a unique offset for each instance.
	var scale_factor = 1.0 + sin(elapsed_time * pulse_speed + pulse_offset) * scale_amount
	scale = Vector2(scale_factor, scale_factor)

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.points_available += 1
		body.update_hud()
		
		if pickup_sound:
			var audio_player = AudioStreamPlayer2D.new()
			audio_player.stream = pickup_sound
			audio_player.pitch_scale = pitch_scale
			audio_player.volume_db = volume_db
			audio_player.position = position
			get_tree().root.add_child(audio_player)
			audio_player.play()
			audio_player.connect("playback_finished", Callable(audio_player, "queue_free"))
		
		queue_free()
